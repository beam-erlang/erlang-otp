#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise source-attested OTP bootstrap failures and literal host arguments."""
import argparse
import json
import os
from pathlib import Path
from scratch import scratch
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "generated", "root", "host", "tools", "work"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--compiler-version", required=True)
    args = parser.parse_args()
    source = args.source.resolve()
    verifier = source / "tools/otp_bootstrap.py"
    manifest = json.loads((source / "bootstrap/manifest.json").read_text())
    work = args.work.resolve()
    shutil.rmtree(work, ignore_errors=True)
    with scratch(work):
        fixture = work / "source 输入"
        generated = work / "generated 输入"
        fixture.mkdir(parents=True)
        for relative in manifest["sources"]:
            destination = fixture / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / relative, destination)
        shutil.copytree(source / "bootstrap/seeds", fixture / "bootstrap/seeds")
        manifest_path = fixture / "bootstrap/manifest.json"
        shutil.copy2(source / "bootstrap/manifest.json", manifest_path)
        for relative in manifest["generated"]:
            destination = generated / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(args.generated / relative, destination)

        results = []
        environment = os.environ.copy()
        for name in list(environment):
            if name.startswith(("ERL_", "BEAM_", "LD_")) or name in {"ROOTDIR", "BINDIR", "PROGNAME"}:
                environment.pop(name)

        def run(name, command, failure=None):
            done = subprocess.run([str(a) for a in command], cwd=work, env=environment,
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  text=True, timeout=180)
            (work / (name + ".log")).write_text(done.stdout)
            results.append({"name": name, "returncode": done.returncode})
            (work / "results.json").write_text(json.dumps(results, indent=2) + "\n")
            if failure is None:
                if done.returncode:
                    raise RuntimeError(f"{name} failed: {done.stdout}")
            elif done.returncode == 0 or failure not in done.stdout:
                raise RuntimeError(f"{name} did not reject its input: {done.stdout}")

        verify = [sys.executable, verifier, "verify", "--source", fixture,
                  "--generated", generated]
        run("attestation", verify)
        run("reproduction", [sys.executable, verifier, "reproduced", "--source", source,
                             "--generated", args.generated, "--output", args.root])

        def corrupt(name, path, contents, message):
            original = path.read_bytes() if path.exists() else None
            try:
                if contents is None:
                    path.unlink()
                else:
                    path.write_bytes(contents)
                run(name, verify, message)
            finally:
                if original is None:
                    path.unlink(missing_ok=True)
                else:
                    path.write_bytes(original)

        seed = fixture / "bootstrap/seeds" / manifest["modules"][0]["path"]
        corrupt("missing-seed", seed, None, "Bootstrap seed inventory differs")
        corrupt("changed-seed", seed, seed.read_bytes() + b"changed", "Missing or changed")
        corrupt("extra-seed", seed.parent / "unexpected.beam", seed.read_bytes(), "Bootstrap seed inventory differs")
        input_path = fixture / "lib/compiler/src/compile.erl"
        corrupt("changed-source", input_path, input_path.read_bytes() + b"\n% changed\n", "Missing or changed")
        corrupt("extra-source", input_path.parent / "unexpected.erl", b"-module(unexpected).\n", "source inventory differs")
        generated_path = generated / "compiler/beam_opcodes.hrl"
        corrupt("changed-generated", generated_path, generated_path.read_bytes() + b"\n", "Missing or changed")
        changed = json.loads(manifest_path.read_text())
        changed["modules"].append(changed["modules"][0])
        corrupt("duplicate-module", manifest_path, json.dumps(changed).encode(), "Duplicate bootstrap modules")
        changed = json.loads(manifest_path.read_text())
        del changed["sources"]["lib/compiler/src/compile.erl"]
        corrupt("missing-source-attestation", manifest_path, json.dumps(changed).encode(), "Unattested bootstrap module source")
        corrupt("duplicate-key", manifest_path,
                manifest_path.read_bytes().replace(b'"format": 1,', b'"format": 1, "format": 1,', 1),
                "Duplicate bootstrap manifest key")
        run("invalid-partial-verification", [sys.executable, verifier, "reproduced",
                                             "--source", fixture, "--seeds-only"],
            "--seeds-only applies only")

        output = work / "literal arguments 日本/parsetools/ebin"
        host_root = args.root.resolve()
        command = [args.host, "-S2:2", "-SDcpu2:2", "-SDio2", "--",
                   "-root", host_root, "-bindir", args.host.parent,
                   "-boot", host_root / "bin/bootstrap", "-noshell", "-noinput",
                   "-pa", host_root / f"lib/compiler-{args.compiler_version}/ebin",
                   "-pa", host_root / "build/ebin", "-s", "otp_bootstrap", "-extra",
                   "tools", fixture, output, host_root]
        run("literal-arguments", command)
        modules = {"ms_transform", "qlc", "qlc_pt", "yecc", "yeccscan", "yeccparser", "leex"}
        if {p.stem for p in output.glob("*.beam")} != modules:
            raise RuntimeError("Literal-argument build produced the wrong tool inventory")
        for module in modules:
            if (output / (module + ".beam")).read_bytes() != (args.tools / (module + ".beam")).read_bytes():
                raise RuntimeError(f"Literal source/output paths changed {module} bytecode")
        print(f"OTP bootstrap integrity and literal arguments passed ({len(results)} checks)")


if __name__ == "__main__":
    main()
