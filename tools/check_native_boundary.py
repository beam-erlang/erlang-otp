#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check OTP-owned native components against actual public SDK headers and imports."""
import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess


from native_inspection import symbols as native_symbols, dynamic, compiler_system_roots
from public_sdk_headers import header_closure

def symbols(nm, library, kind):
    return native_symbols(nm, library, kind == "--defined-only")


def dependencies(entry):
    command = entry.get("arguments") or shlex.split(entry["command"])
    preprocess = []
    skip = False
    for argument in command:
        if skip:
            skip = False
        elif argument in {"-o", "-MF", "-MT", "-MQ"}:
            skip = True
        elif argument not in {"-c", "-MD", "-MMD", "-MP"}:
            preprocess.append(argument)
    output = subprocess.check_output(preprocess + ["-M"],
                                     cwd=entry["directory"], text=True)
    paths = shlex.split(output.replace("\\\n", " ").split(":", 1)[1])
    return {(Path(entry["directory"]) / path).resolve() for path in paths}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ("inventory", "compile-commands", "sdk", "runtime", "source-root"):
        parser.add_argument("--" + option, type=Path, required=True)
    parser.add_argument("--nm", required=True)
    parser.add_argument("--readelf", required=True)
    parser.add_argument("--protocols", nargs="*", choices=("tcp", "udp", "sctp"), default=[])
    parser.add_argument("--hostname-helper", action="store_true")
    parser.add_argument("--socket-backend", action="store_true")
    args = parser.parse_args()
    sdk = args.sdk.resolve()
    header_dir = sdk / "include/beam/nif"
    public_nif = set()
    for path in (header_dir / "erl_nif.h", header_dir / "erl_nif_api_funcs.h"):
        content = path.read_text()
        public_nif.update(re.findall(r"ERL_NIF_API_FUNC_DECL\([^,]+,\s*(\w+)\s*,", content))
        public_nif.update(re.findall(r"\b(enif_\w+)\s*\(", content))
    public_driver = set(re.findall(r"(?:^|\n)EXTERN\s+[^;{]+?\b(\w+)\s*\(",
                                   (header_dir / "erl_driver.h").read_text()))
    public_native = set(re.findall(
        r"^(?:void|int|beam_native_trace_backend)\s+(beam_(?:native|packet)_\w+)\s*\(",
        (sdk / "include/beam/native.h").read_text(), re.MULTILINE))
    runtime = symbols(args.nm, args.runtime, "--defined-only")
    entries = json.loads(args.compile_commands.read_text())
    inventory = json.loads(args.inventory.read_text())
    expected = {("builtin-nif", name) for name in ("prim_buffer", "prim_file", "zlib", "erl_tracer", "prim_tty", "zstd")}
    expected.add(("nif", "dyntrace"))
    expected |= {("driver", name) for name in ("trace_file_drv", "trace_ip_drv")}
    expected.add(("builtin-driver", "ram_file_drv"))
    expected |= {("builtin-driver", name + "_inet") for name in args.protocols}
    if args.hostname_helper:
        expected.add(("helper", "inet_gethost"))
    if args.socket_backend:
        expected.add(("builtin-backend", "socket_backend"))
    if {(record["kind"], record["module"]) for record in inventory} != expected:
        raise RuntimeError("Unexpected OTP-owned native inventory")
    for record in inventory:
        builtin = record["kind"].startswith("builtin-")
        kind = record["kind"].removeprefix("builtin-")
        is_nif = kind == "nif"
        is_helper = record["kind"] == "helper"
        is_backend = kind == "backend"
        public = set() if is_helper else set(public_nif if is_nif else public_driver)
        header = header_dir / ("erl_nif.h" if is_nif else "erl_driver.h")
        sources = [Path(value).resolve() for value in record["sources"]]
        headers = set()
        system_roots = set()
        for source in sources:
            matches = [entry for entry in entries if Path(entry["file"]).resolve() == source]
            if "target" in record:
                matches = [entry for entry in matches
                           if f"CMakeFiles/{record['target']}.dir/" in entry.get("command", entry.get("output", ""))]
            if len(matches) != 1:
                raise RuntimeError(f"Expected one source compile command: {source}")
            headers.update(dependencies(matches[0]))
            command = matches[0].get("arguments") or shlex.split(matches[0]["command"])
            system_roots.update(compiler_system_roots(command[0]))
        common = args.source_root.resolve() / "erts/emulator/nifs/common"
        allowed_local = {*sources, common / "otp_nif_support.h"}
        if is_helper:
            allowed_local = {*sources, args.compile_commands.resolve().parent / "generated/otp_hostname_config.h"}
        if record["module"] == "dyntrace":
            allowed_local.add(sources[0].parent / "dyntrace_lttng.h")
        if record["module"] == "prim_file":
            allowed_local.update(common / name for name in
                                 ("otp_file_support.h", "prim_file_nif.h", "prim_file_nif_dyncall.h"))
            allowed_local.add(args.compile_commands.resolve().parent / "generated/otp_file_config.h")
        if record["module"] == "prim_tty":
            allowed_local.add(args.compile_commands.resolve().parent / "generated/otp_tty_config.h")
        if record["module"] == "zstd":
            vendor = args.source_root.resolve() / "erts/emulator/zstd"
            allowed_local.update(vendor.rglob("*.h"))
        if record["module"] in {name + "_inet" for name in args.protocols}:
            allowed_local.add(sources[0].parent / "otp_inet_support.h")
            allowed_local.add(args.compile_commands.resolve().parent / "generated/otp_inet_config.h")
        if is_backend:
            allowed_local.update(common / name for name in (
                "otp_socket_support.h", "socket_dbg.h", "socket_int.h", "socket_tarray.h",
                "socket_util.h", "prim_socket_int.h", "socket_io.h", "socket_syncio.h", "socket_asyncio.h",
                "prim_file_nif_dyncall.h"))
            allowed_local.add(args.compile_commands.resolve().parent / "generated/otp_socket_config.h")
        roots = []
        if not is_helper:
            roots.append("header.erl_nif" if is_nif else "header.erl_driver")
            for identity, path in (("header.erl_nif", header_dir / "erl_nif.h"),
                                   ("header.erl_driver", header_dir / "erl_driver.h"),
                                   ("header.beam_native", sdk / "include/beam/native.h")):
                if path in headers:
                    roots.append(identity)
        allowed_sdk = header_closure(sdk, roots)
        unexpected = {str(path) for path in headers
                      if path not in allowed_local and path not in allowed_sdk
                      and not any(path.is_relative_to(root) for root in system_roots)}
        if (not is_helper and header not in headers) or unexpected:
            raise RuntimeError(f"Non-public header dependency in {record['module']}: {unexpected}")
        if is_helper and any(sdk in path.parents for path in headers):
            raise RuntimeError("The standalone resolver must not depend on VM headers")
        if header_dir / "erl_driver.h" in headers:
            public |= public_driver
        if header_dir / "erl_nif.h" in headers:
            public |= public_nif
        if sdk / "include/beam/native.h" in headers:
            public |= public_native
        libraries = [Path(path) for path in record["library"].split(";")]
        imports, exported = set(), set()
        for library in libraries:
            imports |= symbols(args.nm, library, "--undefined-only")
            exported |= symbols(args.nm, library, "--defined-only")
        imports -= exported
        private = (imports & runtime) - public
        private |= {name for name in imports if name.startswith(("erts_", "beam_")) and name not in public}
        if private:
            raise RuntimeError(f"Private VM imports in {record['module']}: {sorted(private)}")
        if builtin:
            if record["installed"]:
                raise RuntimeError("Built-in native code must not have a separate installed library")
            if is_backend:
                required_exports = {"otp_prim_socket_nif_init", "otp_prim_net_nif_init"}
            elif is_nif:
                required_exports = {"otp_" + record["module"] + "_nif_init"}
            else:
                required_exports = {record["module"] + "_driver_init"}
        else:
            required_exports = set() if is_helper else ({"nif_init", "beam_nif_sdk_v1"} if is_nif else {"driver_init"})
        if not required_exports <= exported:
            raise RuntimeError(f"Missing native entry: {record['module']}")
        if not builtin:
            linked = dynamic(libraries[0], args.readelf)
            if "libbeam.so" in linked or "libbeam.dylib" in linked:
                raise RuntimeError(f"Extension links directly to the VM: {libraries[0]}")
        if is_helper:
            print(f"{record['module']}: product-local configuration and system interfaces only")
        else:
            print(f"{record['module']}: installed public {record['kind']} headers and {len(imports & public)} declared imports")


if __name__ == "__main__":
    main()
