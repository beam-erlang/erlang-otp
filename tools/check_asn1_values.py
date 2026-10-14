#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare generated ASN.1 values with the pinned upstream OTP 29 behavior."""
import argparse
import hashlib
import json
from pathlib import Path
from scratch import scratch
import os
import shutil
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "build"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--cmake", required=True)
    args = parser.parse_args()
    source, build = args.source.resolve(), args.build.resolve()
    work = build / "checks" / ("asn1-values-" + str(time.time_ns()))
    work.mkdir(parents=True)
    with scratch(work):
        prefix = work / "OTP candidate"
        subprocess.run([args.cmake, "--install", str(build), "--prefix", str(prefix)],
                       check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        schema = source / "lib/asn1/examples/P-Record.asn"
        reference = json.loads((source / "tools/fixtures/asn1-value-reference.json").read_text())
        assert (source / "UPSTREAM_COMMIT").read_text().strip() == reference["upstream_pin"]
        assert hashlib.sha256(schema.read_bytes()).hexdigest() == reference["schema_sha256"]
        shutil.copyfile(schema, work / schema.name)
        environment = {k: v for k, v in os.environ.items()
                       if not k.startswith(("ERL_", "ERLC_", "ESCRIPT_", "LD_"))
                       and k not in {"BINDIR", "ROOTDIR", "EMU"}}
        environment.update(HOME=str(work), PATH=str(prefix / "bin") + ":/usr/bin:/bin")
        outcomes = {}
        for rule in ("ber", "per", "uper"):
            out = work / rule
            out.mkdir()
            check = ("{ok,Encoded}='P-Record':encode('PersonnelRecord',Value),"
                     "{ok,Value}='P-Record':decode('PersonnelRecord',Encoded),"
                     if rule == "ber" else
                     "{error,{asn1,{badarg,[{erlang,length,[{'Name',\"Mary\",\"T\",\"Smith\"}],_},"
                     "{'P-Record',enc_PersonnelRecord_children,1,_}|_]}}}="
                     "'P-Record':encode('PersonnelRecord',Value),")
            expression = (
                f'ok=asn1ct:compile("P-Record.asn",[{rule},{{outdir,"{rule}"}}]),'
                "Value='P-Record':v(),"
                'io:format("Generated value: ~tp~n",[Value]),'
                + check + "halt().")
            result = subprocess.run([str(prefix / "bin/erl"), "+S1", "-noshell", "-eval", expression],
                                    cwd=work, env=environment, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=60)
            (work / f"{rule}.log").write_bytes(result.stdout)
            generated = {f"{rule}/P-Record.{extension}": hashlib.sha256(
                (out / f"P-Record.{extension}").read_bytes()).hexdigest() for extension in ("erl", "hrl")}
            same_outputs = all(digest == reference["generated_sha256"][name]
                               for name, digest in generated.items())
            outcomes[rule] = {"passed": result.returncode == 0 and same_outputs,
                              "exit_code": result.returncode, "generated_sha256": generated,
                              "matches_upstream_outputs": same_outputs}
        record = {"sdk": json.loads((build / "sdk-selection.json").read_text()),
                  "schema": "lib/asn1/examples/P-Record.asn",
                  "sha256": hashlib.sha256(schema.read_bytes()).hexdigest(), "rules": outcomes,
                  "reference": reference}
        (work / "result.json").write_text(json.dumps(record, indent=2) + "\n")
        print(f"ASN.1 generated-value coverage: {outcomes}; evidence: {work}")
        if not all(outcome["passed"] for outcome in outcomes.values()):
            raise SystemExit(1)


if __name__ == "__main__":
    main()
