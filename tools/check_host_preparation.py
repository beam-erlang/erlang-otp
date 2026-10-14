#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise product acquisition failures and copied startup inputs through the public SDK."""
import argparse
import hashlib
import json
import os
from pathlib import Path
from scratch import scratch
import shutil
import time
import sys
from host_testing import work_root, seatbelt

from check_compatibility import execute


def check_prefix(args, root, prefix, label, isolated=False):
    phase = root / label
    phase.mkdir()
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith(("ERL_", "ERLC_", "ESCRIPT_", "BEAM_", "LD_"))
                   and key not in {"ROOTDIR", "BINDIR", "EMU", "PROGNAME"}}
    environment.update(HOME=str(phase), PATH=str(prefix / "bin") + ":/usr/bin:/bin",
                       LANG="C.UTF-8", LC_ALL="C.UTF-8")
    mounts = () if sys.platform == "darwin" else ((str(prefix), "/OTP prefix 日本"), (str(phase), "/fixture 日本"))

    def translate(value):
        text = str(value)
        for source, destination in mounts:
            text = text.replace(source, destination)
        return text

    def run(command, name):
        if isolated and sys.platform == 'darwin':
            command = [*seatbelt(args, phase, (args.source, args.build, args.sdk)), *command]
        elif isolated:
            isolation = [str(args.bwrap), "--unshare-user", "--unshare-pid", "--die-with-parent"]
            for path in ("/usr", "/bin", "/lib", "/lib64", "/etc"):
                if Path(path).exists():
                    isolation += ["--ro-bind", path, path]
            for path in ("/usr/lib/erlang", "/usr/local/lib/erlang"):
                if Path(path).exists():
                    isolation += ["--tmpfs", path]
            # The fixture mutates a disposable installation to verify copied
            # inputs and recovery. It cannot reach the source, build or SDK.
            isolation += ["--dev", "/dev", "--proc", "/proc", "--tmpfs", "/tmp",
                          "--bind", str(prefix), mounts[0][1],
                          "--bind", str(phase), mounts[1][1],
                          "--chdir", mounts[1][1]]
            for key in ("HOME", "PATH"):
                isolation += ["--setenv", key, translate(environment[key])]
            command = isolation + ["--"] + [translate(arg) for arg in command]
        return execute(command, phase, environment, phase / (name + ".log"), timeout=30)

    if isolated:
        for number, absent in enumerate((args.source, args.build, args.sdk)):
            run(["/bin/test" if sys.platform == 'darwin' else "/usr/bin/test", "!", "-e", absent], f"absent-{number}")
    preload_directory = next((prefix / "lib").glob("erts-*/ebin"))
    original_hashes = {path: hashlib.sha256(path.read_bytes()).hexdigest()
                       for path in preload_directory.glob("*.beam")}
    probe = next(prefix.glob("erts-*/bin/otp_host_preparation_probe"))
    custom = phase / "custom startup 日本.boot"
    shutil.copyfile(prefix / "bin/start.boot", custom)
    for name, boot in (("normal", prefix / "bin/start"), ("custom", custom.with_suffix(""))):
        try:
            command = [probe, prefix, boot]
            if sys.platform == 'darwin':
                fault, = prefix.glob('erts-*/bin/' + args.allocation_fault.name)
                command = ['/usr/bin/env', 'DYLD_INSERT_LIBRARIES=' + str(fault), *command]
            stdout, stderr = run(command, name)
            if stdout != "OTP_PREPARATION_OK\n" or stderr:
                raise RuntimeError(f"{label}/{name}: unexpected output {stdout!r} {stderr!r}")
        finally:
            for asset, expected_hash in original_hashes.items():
                held = asset.with_suffix(".beam.held")
                if held.exists():
                    held.replace(asset)
                if hashlib.sha256(asset.read_bytes()).hexdigest() != expected_hash:
                    raise RuntimeError("Preparation fixture failed to restore its input")
    print(f"{label}: preparation failures, recovery and normal/custom boot passed", flush=True)
    return {"phase": label, "isolated": isolated, "boot_scripts": ["normal", "custom"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("build", "source", "sdk", "bwrap", "probe"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--cmake", required=True)
    parser.add_argument("--allocation-fault", type=Path)
    args = parser.parse_args()
    for name in ("build", "source", "sdk", "bwrap", "probe"):
        setattr(args, name, getattr(args, name).resolve())
    root = work_root(args.build, "host-preparation") / str(time.time_ns())
    root.mkdir(parents=True)
    with scratch(root):
        prefix = root / "fresh OTP 日本"
        execute([args.cmake, "--install", args.build, "--prefix", prefix], root,
                os.environ.copy(), root / "install.log", timeout=60)
        bindir = next(prefix.glob("erts-*/bin"))
        shutil.copy2(args.probe, bindir / args.probe.name)
        if sys.platform == 'darwin':
            if args.allocation_fault is None:
                raise RuntimeError('Darwin preparation acceptance requires its test-only allocation fault provider')
            args.allocation_fault = args.allocation_fault.resolve(strict=True)
            shutil.copy2(args.allocation_fault, bindir / args.allocation_fault.name)
        sources = ("tools/otp_host_inputs.c", "tools/otp_host_inputs.h",
                   "tools/fixtures/host_preparation.c", "tools/check_host_preparation.py")
        if sys.platform == 'darwin':
            sources += ("tools/test_support/allocation_fault.c", "tools/test_support/host_observe.c",
                        "tools/test_support/host_observe.h", "tools/host_testing.py", "cmake/OTPTesting.cmake")
        result = {"inputs": {name: hashlib.sha256((args.source / name).read_bytes()).hexdigest()
                             for name in sources},
                  "runtime_sha256": hashlib.sha256((bindir / "beam.smp").read_bytes()).hexdigest(),
                  "probe_sha256": hashlib.sha256(args.probe.read_bytes()).hexdigest(), "phases": []}
        if sys.platform == 'darwin':
            result["allocation_fault_sha256"] = hashlib.sha256(args.allocation_fault.read_bytes()).hexdigest()
            result["memory_pressure"] = "real allocation failure interposition; Mach address-space cleanup budgets"
        result_path = root / "results.json"
        for label in ("fresh", "relocated", "isolated"):
            if label == "relocated":
                relocated = root / "relocated OTP 日本"
                prefix.rename(relocated)
                prefix = relocated
            result["phases"].append(check_prefix(args, root, prefix, label, label == "isolated"))
            result_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
        print(f"Transferred OTP preparation acceptance passed; evidence: {root}")


if __name__ == "__main__":
    main()
