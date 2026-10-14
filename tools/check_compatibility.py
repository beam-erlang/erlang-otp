#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise the transferred OTP application/service contract through product commands."""
import argparse
import hashlib
import json
import os
from pathlib import Path
from scratch import scratch
import shutil
import signal
import subprocess
import time
import sys
from host_testing import work_root, seatbelt, select_observer


MODULES = (
    "otp_fixture", "otp_hello", "otp_supervision", "otp_counter_app",
    "otp_counter_sup", "otp_counter", "otp_services", "otp_service_app",
    "otp_service_sup", "otp_service",
)
APPLICATIONS = ("otp_counter", "otp_service")
CASES = (
    ("otp_hello", (), "OTP_HELLO_OK"),
    ("otp_supervision", (), "OTP_SUPERVISION_OK"),
    ("otp_services", ("inet",), "OTP_SERVICES_OK inet"),
    ("otp_services", ("socket",), "OTP_SERVICES_OK socket"),
)


def execute(command, cwd, environment, log, timeout=30):
    command = [str(arg) for arg in command]
    process = subprocess.Popen(command, cwd=cwd, env=environment,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               text=True, start_new_session=True)
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except BaseException:
        # Cleanup only failure paths. A successful exit cannot rely on this
        # runner killing surviving processes to satisfy the product contract.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        stdout, stderr = process.communicate()
        log.write_text(json.dumps(command) + "\n" + stdout + "\nSTDERR\n" + stderr)
        raise
    log.write_text(json.dumps(command) + "\n" + stdout + "\nSTDERR\n" + stderr)
    if process.returncode:
        raise RuntimeError(f"Command failed ({process.returncode}); see {log}\n{stdout}\n{stderr}")
    return stdout, stderr


def check_prefix(args, root, prefix, label, isolated=False):
    phase = root / label
    work, fixtures, ebin = phase / "work", phase / "fixtures 日本", phase / "ebin 日本"
    for directory in (work, fixtures, ebin):
        directory.mkdir(parents=True)
    fixture_source = args.source / "tools/fixtures/compatibility"
    for module in MODULES:
        shutil.copyfile(fixture_source / (module + ".erl"), fixtures / (module + ".erl"))
    for application in APPLICATIONS:
        shutil.copyfile(fixture_source / (application + ".app"), ebin / (application + ".app"))
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith(("ERL_", "ERLC_", "ESCRIPT_", "BEAM_", "LD_"))
                   and key not in {"ROOTDIR", "BINDIR", "EMU", "PROGNAME"}}
    homes = {"HOME": "home", "XDG_CONFIG_HOME": "config", "XDG_DATA_HOME": "data",
             "XDG_CACHE_HOME": "cache", "XDG_STATE_HOME": "state", "XDG_RUNTIME_DIR": "runtime",
             "XDG_CONFIG_DIRS": "config-dirs", "XDG_DATA_DIRS": "data-dirs"}
    for key, name in homes.items():
        (work / name).mkdir(mode=0o700)
        environment[key] = str(work / name)
    environment.update(PATH=str(prefix / "bin") + ":/usr/bin:/bin", BEAM_EXPECT_PREFIX=str(prefix))
    if sys.platform == "darwin":
        select_observer(args.build, phase, environment)
    mounts = () if sys.platform == "darwin" else ((str(prefix), "/OTP prefix 日本"), (str(phase), "/fixture 日本"))

    def translate(value):
        text = str(value)
        for source, destination in mounts:
            text = text.replace(source, destination)
        return text

    def run(command, log_name, timeout=30):
        if isolated and sys.platform == 'darwin':
            isolation = seatbelt(args, phase, (args.source, args.build, args.sdk))
            command = isolation + [str(arg) for arg in command]
        elif isolated:
            isolation = [args.bwrap, "--unshare-user", "--unshare-pid", "--die-with-parent"]
            for system_path in ("/usr", "/bin", "/lib", "/lib64", "/etc"):
                if Path(system_path).exists():
                    isolation += ["--ro-bind", system_path, system_path]
            # An operating-system installation of Erlang cannot satisfy a
            # missing candidate dependency inside this namespace.
            for system_runtime in ("/usr/lib/erlang", "/usr/local/lib/erlang"):
                if Path(system_runtime).exists():
                    isolation += ["--tmpfs", system_runtime]
            isolation += ["--dev", "/dev", "--proc", "/proc", "--tmpfs", "/tmp",
                          "--ro-bind", str(prefix), mounts[0][1],
                          "--bind", str(phase), mounts[1][1],
                          "--chdir", translate(work)]
            for key in (*homes, "PATH", "BEAM_EXPECT_PREFIX"):
                isolation += ["--setenv", key, translate(environment[key])]
            command = isolation + ["--"] + [translate(arg) for arg in command]
        return execute(command, work, environment, phase / (log_name + ".log"), timeout)

    if isolated:
        for number, absent in enumerate((args.source, args.build, args.sdk)):
            run(["/bin/test" if sys.platform == 'darwin' else "/usr/bin/test", "!", "-e", str(absent)], f"absent-{number}")
    run([prefix / "bin/erlc", "-o", ebin,
         *[fixtures / (module + ".erl") for module in MODULES]], "compile", timeout=90)
    for number, (module, arguments, marker) in enumerate(CASES):
        stdout, stderr = run([prefix / "bin/erl", "+S2", "+SDcpu2", "+SDio2",
                              "-noshell", "-noinput", "-pa", ebin,
                              "-s", module, "main", "-extra", *arguments], f"case-{number}")
        if stdout.splitlines().count(marker) != 1:
            raise RuntimeError(f"{label}: missing or repeated completion for {module}\n{stdout}\n{stderr}")
        if module == "otp_hello" and (stdout != "OTP_HELLO_OK\n" or stderr):
            raise RuntimeError(f"{label}: unexpected hello output: {stdout!r} {stderr!r}")
    retained = {path.name for path in work.iterdir()} - set(homes.values())
    if retained:
        raise RuntimeError(f"{label}: applications retained working files: {retained}")
    print(f"{label}: all four application/service scenarios passed", flush=True)
    return {"phase": label, "cases": [entry[2] for entry in CASES], "isolated": isolated}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("build", "source", "sdk", "bwrap"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--cmake", required=True)
    args = parser.parse_args()
    for name in ("build", "source", "sdk", "bwrap"):
        setattr(args, name, getattr(args, name).resolve())
    root = work_root(args.build, "compatibility") / str(time.time_ns())
    root.mkdir(parents=True)
    with scratch(root):
        prefix = root / "fresh OTP 日本"
        execute([args.cmake, "--install", args.build, "--prefix", prefix], root,
                os.environ.copy(), root / "install.log", timeout=60)
        sources = args.source / "tools/fixtures/compatibility"
        inventory = {name: hashlib.sha256((sources / name).read_bytes()).hexdigest()
                     for name in [*[module + ".erl" for module in MODULES],
                                  *[application + ".app" for application in APPLICATIONS]]}
        result = {"fixtures": inventory,
                  "executable_sha256": hashlib.sha256(next(prefix.glob("erts-*/bin/beam.smp")).read_bytes()).hexdigest(),
                  "phases": []}
        result_path = root / "results.json"
        for label in ("fresh", "relocated", "isolated"):
            if label == "relocated":
                relocated = root / "relocated OTP 日本"
                prefix.rename(relocated)
                prefix = relocated
            result["phases"].append(check_prefix(args, root, prefix, label, label == "isolated"))
            result_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
        print(f"Transferred OTP compatibility acceptance passed; evidence: {root}")


if __name__ == "__main__":
    main()
