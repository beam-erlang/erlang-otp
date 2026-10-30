#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check a host against the selected installed public SDK."""

import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import shutil
from native_inspection import symbols, dynamic
from public_sdk_headers import header_closure


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--source", type=Path, action="append", required=True)
    parser.add_argument("--compile-commands", type=Path, required=True)
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--nm", required=True)
    parser.add_argument("--execution", choices=["call", "process"], default="call")
    parser.add_argument("--selection-source", type=Path)
    parser.add_argument("--expected-version")
    parser.add_argument("--expected-build-id")
    parser.add_argument("--expected-flavor")
    parser.add_argument("--cmake", default="cmake")
    args = parser.parse_args()
    if args.selection_source:
        with tempfile.TemporaryDirectory(prefix="otp-sdk-selection-") as temp:
            root = Path(temp)
            shutil.copy2(args.selection_source / "UPSTREAM_COMMIT", root / "UPSTREAM_COMMIT")
            (root / "CMakeLists.txt").write_text(
                'cmake_minimum_required(VERSION 3.25)\nproject(selection C)\n'
                'set(OTP_VERSION 29.0)\ninclude([[' + str(args.selection_source / "cmake/SDKDependency.cmake") + ']])\n')
            cases = [("valid", args.expected_version, args.expected_build_id, args.expected_flavor, True),
                     ("preview", args.expected_version + ".wrong", args.expected_build_id, args.expected_flavor, False),
                     ("build", args.expected_version, "0" * 64, args.expected_flavor, False),
                     ("flavor", args.expected_version, args.expected_build_id, "jit" if args.expected_flavor == "emu" else "emu", False),
                     ("missing", "", "", args.expected_flavor, False)]
            for name, version, identity, flavor, accepted in cases:
                result = subprocess.run([args.cmake, "-S", str(root), "-B", str(root / name),
                    "-DBEAM_SDK_ROOT=" + str(args.sdk), "-DOTP_BEAM_SDK_VERSION=" + version,
                    "-DOTP_BEAM_SDK_BUILD_ID=" + identity, "-DOTP_BEAM_FLAVOR=" + flavor],
                    text=True, capture_output=True)
                if (result.returncode == 0) != accepted:
                    raise RuntimeError("SDK selection case failed: " + name + "\n" + result.stdout + result.stderr)

            # A static OTP host needs neither the modern controller nor libraries.
            minimal = root / "runtime-only-sdk"
            shutil.copytree(args.sdk, minimal, symlinks=True)
            records = json.loads((minimal / "lib/beam/runtime-artifacts.json").read_text())["artifacts"]
            for identity, record in records.items():
                if (identity in {"runtime", "host.static", "api.boot", "api.host",
                                 "api.library", "sdk.library", "sdk.library.author"}
                        or identity.startswith(("library.", "link.library.", "link.host", "command."))):
                    relative = Path(record["path"])
                    if relative.is_absolute() or ".." in relative.parts:
                        raise RuntimeError("Invalid optional artifact path: " + identity)
                    (minimal / relative).unlink(missing_ok=True)
            with (root / "CMakeLists.txt").open("a") as project:
                project.write(
                    'if(TARGET BEAM::Host OR TARGET BEAM::Runtime OR TARGET BEAM::CLI)\n'
                    'message(FATAL_ERROR "Optional product target survived runtime-only selection")\nendif()\n'
                    'configure_file([[' + str(args.selection_source / "cmake/sdk_selection.h.in") +
                    ']] sdk_selection.h @ONLY)\n'
                    'add_executable(probe [[' + str(args.selection_source / "tools/sdk_probe.c") + ']])\n'
                    'target_include_directories(probe PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")\n'
                    'target_link_libraries(probe PRIVATE BEAM::RuntimeStatic)\n'
                    'enable_testing()\nadd_test(NAME probe COMMAND probe "$<TARGET_FILE:probe>")\n')
            build = root / "runtime-only-build"
            commands = [
                [args.cmake, "-S", str(root), "-B", str(build),
                 "-DBEAM_SDK_ROOT=" + str(minimal),
                 "-DOTP_BEAM_SDK_VERSION=" + args.expected_version,
                 "-DOTP_BEAM_SDK_BUILD_ID=" + args.expected_build_id,
                 "-DOTP_BEAM_FLAVOR=" + args.expected_flavor],
                [args.cmake, "--build", str(build), "--config", "Release"],
                [str(Path(args.cmake).with_name("ctest")), "--test-dir", str(build),
                 "-C", "Release", "--output-on-failure"],
            ]
            for command in commands:
                result = subprocess.run(command, text=True, capture_output=True, timeout=180)
                if result.returncode:
                    raise RuntimeError("Runtime-only SDK probe failed: " + repr(command) +
                                       "\n" + result.stdout + result.stderr)

    sdk = args.sdk.resolve()
    public_header = sdk / "include/beam/beam.h"
    allowed_headers = header_closure(sdk, ["api.beam"])
    runtime_imports = set()
    exports = symbols(args.nm, args.executable, True)
    if not {"beam_build_id", "enif_make_atom", "driver_alloc", "driver_term_nil"} <= exports:
        raise RuntimeError("Static host does not expose the public native boundary")
    if any(name.startswith("pcre2_") for name in exports) or exports & {"inflate", "deflate", "crc32"}:
        raise RuntimeError("Private vendor symbols escape the static host")
    if exports & {"beam_return_prepare", "beam_return_run", "beam_return_discard",
                  "beam_library_open", "beam_library_from_static", "beam_host_prepare"}:
        raise RuntimeError("OTP host contains optional modern Host/library operations")
    linked = dynamic(args.executable)
    if "libbeam.so" in linked or "libbeam.dylib" in linked:
        raise RuntimeError("OTP host depends on a shared runtime")

    entries = json.loads(args.compile_commands.read_text())
    for source in args.source:
        source = source.resolve()
        matches = [entry for entry in entries if Path(entry["file"]).resolve() == source]
        if len(matches) != 1:
            raise RuntimeError("Expected one compile command for the SDK probe")
        entry = matches[0]
        command = entry.get("arguments") or shlex.split(entry["command"])
        output = Path(command[command.index("-o") + 1])
        if not output.is_absolute():
            output = Path(entry["directory"]) / output
        imported = symbols(args.nm, output, False)
        selected = {name for name in imported if name.startswith("beam_")}
        private = {name for name in imported if name.startswith(("erts_", "erl_", "enif_"))}
        preprocess = []
        skip = False
        for argument in command:
            if skip:
                skip = False
            elif argument in {"-o", "-MF", "-MT", "-MQ"}:
                skip = True
            elif argument not in {"-c", "-MD", "-MMD", "-MP"}:
                preprocess.append(argument)
        dependency_text = subprocess.check_output(
            preprocess + ["-M"], cwd=entry["directory"], text=True
        )
        dependency_paths = shlex.split(dependency_text.replace("\\\n", " ").split(":", 1)[1])
        dependencies = {(Path(entry["directory"]) / item).resolve() for item in dependency_paths}
        if public_header.resolve() not in dependencies:
            raise RuntimeError("Probe did not include the selected installed beam/beam.h")
        private_headers = [str(path) for path in dependencies
                           if path.name.startswith(("erl_", "erts_"))]
        sdk_headers = {path for path in dependencies if sdk in path.parents}
        if private_headers or not sdk_headers <= allowed_headers:
            raise RuntimeError(f"Unexpected SDK/private header dependencies: {private_headers or sdk_headers}")
        declarations = set()
        for header in sdk_headers:
            declarations.update(re.findall(r"\b(beam_[a-zA-Z0-9_]+)\s*\(", header.read_text()))
        if private or selected - declarations:
            raise RuntimeError(f"Imports outside consumed public headers: {sorted(private | (selected - declarations))}")
        runtime_imports |= selected
    execution = "beam_vm_enter" if args.execution == "process" else "beam_vm_call"
    if not {"beam_init", "beam_vm_init", execution, "beam_vm_terminate", "beam_build_id"} <= runtime_imports:
        raise RuntimeError("Host objects do not exercise the expected public VM lifecycle and identity")
    print(f"Public SDK boundary passed: {len(runtime_imports)} declared imports, verified installed embedding header closure")


if __name__ == "__main__":
    main()
