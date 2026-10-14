#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise the product-owned ET event-file fixture through a selected installation."""
import argparse
import hashlib
import json
import sys
from host_testing import identity_expression
import os
from pathlib import Path
from scratch import scratch
import shutil
import signal
import subprocess
import tempfile

from installation_inventory import verify_installation


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument("--build", type=Path)
    selection.add_argument("--prefix", type=Path)
    parser.add_argument("--provenance", type=Path)
    parser.add_argument("--work-root", type=Path)
    parser.add_argument("--cmake", default="cmake")
    args = parser.parse_args()
    if args.prefix and (not args.provenance or not args.work_root):
        parser.error("--prefix requires --provenance and --work-root")
    if args.provenance and not args.prefix:
        parser.error("--provenance requires --prefix")
    record = verify_installation(args.prefix, args.provenance) if args.prefix else None
    root = args.work_root.resolve() if args.work_root else args.build.resolve() / "checks/et"
    if args.prefix and root.is_relative_to(args.prefix.resolve()):
        parser.error("Test output must be outside the selected installation")
    root.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="event-file-", dir=root))
    with scratch(work):
        if record:
            prefix = args.prefix.resolve()
            identity = {"runtime": record["runtime"], "flavor": record["flavor"],
                        "provenance_sha256": hashlib.sha256(args.provenance.read_bytes()).hexdigest()}
        else:
            prefix = work / "OTP candidate"
            subprocess.run([args.cmake, "--install", str(args.build), "--prefix", str(prefix)],
                           check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            sdk = json.loads((args.build / "sdk-selection.json").read_text())
            identity = {"runtime": "candidate", "flavor": sdk["flavor"], "sdk": sdk}
        original = args.source / "tools/fixtures/otp_product_probe.erl"
        fixture = work / original.name
        shutil.copyfile(original, fixture)
        source_hash = hashlib.sha256(fixture.read_bytes()).hexdigest()
        environment = {key: value for key, value in os.environ.items()
                       if not key.startswith(("ERL_", "ERLC_", "ESCRIPT_", "LD_"))
                       and key not in {"BINDIR", "ROOTDIR", "EMU"}}
        environment.update(HOME=str(work), PATH=str(prefix / "bin") + ":/usr/bin:/bin")
        result = {"installation": identity, "prefix": str(prefix), "source_sha256": source_hash,
                  "commands": [], "complete": False}

        def run(command):
            process = subprocess.Popen(command, cwd=work, env=environment,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            timed_out = False
            try:
                output, _ = process.communicate(timeout=30)
            except subprocess.TimeoutExpired:
                timed_out = True
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    output, _ = process.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    output, _ = process.communicate()
            result["commands"].append({"argv": command, "exit": process.returncode, "timed_out": timed_out})
            with (work / "execution.log").open("ab") as stream:
                stream.write((json.dumps(command) + "\n").encode() + output + b"\n")
            if timed_out or process.returncode:
                raise RuntimeError(f"ET check failed; see {work / 'execution.log'}")

        try:
            # Identity is checked independently of the identical application workflow.
            expression = (f'{json.dumps(str(prefix), ensure_ascii=False)}=code:root_dir(),'
                          f'{identity["flavor"]}=erlang:system_info(emu_flavor),'
                          '"29"=erlang:system_info(otp_release),'
                          'Host=filename:join([code:root_dir(),"erts-"++erlang:system_info(version),"bin","beam.smp"]),'
                          '{ok,Host}=file:read_link("/proc/self/exe"),'
                          '{ok,Maps}=file:read_file("/proc/self/maps"),nomatch=binary:match(Maps,<<"libbeam.so">>),'
                          '[true=lists:prefix(code:root_dir()++"/",code:which(M)) || M <- [et_collector,disk_log]],halt().')
            if sys.platform == 'darwin':
                linux = ('Host=filename:join([code:root_dir(),"erts-"++erlang:system_info(version),"bin","beam.smp"]),'
                         '{ok,Host}=file:read_link("/proc/self/exe"),'
                         '{ok,Maps}=file:read_file("/proc/self/maps"),nomatch=binary:match(Maps,<<"libbeam.so">>),')
                assert linux in expression
                expression = expression.replace(linux, identity_expression(args.build, work))
            run([str(prefix / "bin/erl"), "+S2", "-noshell", "-eval", expression])
            run([str(prefix / "bin/erlc"), "-o", str(work), str(fixture)])
            run([str(prefix / "bin/erl"), "+S2", "-noshell", "-pa", str(work), "-eval",
                 'ok=otp_product_probe:event_collection("events"),io:format("ET event file passed~n"),halt().'])
            result["complete"] = True
        finally:
            assert hashlib.sha256(original.read_bytes()).hexdigest() == source_hash
            (work / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        print(f"ET event file passed: {identity['runtime']}/{identity['flavor']}; {work}")


if __name__ == "__main__":
    main()
