#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Checks for the retained upstream embedded-system launcher."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import sys
import shutil


def root_discovery(prefix, fallback, work, run):
    """Execute the installed discovery code without starting its daemon."""
    (work / "absent").mkdir(exist_ok=True)
    starts = [prefix / "bin/start", *prefix.glob("erts-*/bin/start")]
    if len(starts) != 2:
        raise RuntimeError("Expected both upstream start copies")
    version = starts[1].parent.parent.name.removeprefix("erts-")
    for index, start in enumerate(starts):
        text = start.read_text()
        if "%VSN%" in text or f'erts-{version}' not in text:
            raise RuntimeError(f"Unresolved ERTS version in {start}")
        functions = text[text.index("absolute_parent()"):text.index("if touch /var/log")]
        selection = text[text.index('if [ -z "$ERL_ROOTDIR" ]'):text.index('if [ -z "$RELDIR" ]')]
        probe = work / f"start-discovery-{index}.sh"
        # Supply the real installed script name as $0.
        probe.write_text(functions + selection + '\nprintf "%s\\n" "$ROOTDIR"\n')
        for name, override, expected in (
                (start, "", prefix), (work / "absent/start", "", fallback),
                (start, "/explicit/root 日本", "/explicit/root 日本")):
            result = run(["sh", "-c", probe.read_text(), str(name)],
                         {"ERL_ROOTDIR": override})
            if result.strip() != str(expected):
                raise RuntimeError(f"start root discovery: {result!r}, expected {expected}")


def isolated_chain(prefix, work, run, *, build=None, source=None):
    """Run the real daemon chain under a PID namespace with only this tree."""
    if sys.platform == 'darwin':
        return darwin_chain(prefix, work, run, build, source)
    host, = prefix.glob("erts-*/bin/beam.smp")
    helper, = prefix.glob("erts-*/bin/erl_child_setup")
    expected = {str(p.relative_to(prefix)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (host, helper)}
    controller = work / "start-controller.py"
    controller.write_text(Path(__file__).read_text())
    (work / "start-expected.json").write_text(json.dumps(expected))
    command = ["bwrap", "--unshare-user", "--unshare-pid", "--die-with-parent"]
    for directory in ("/usr", "/bin", "/lib", "/lib64", "/etc"):
        if Path(directory).exists():
            command += ["--ro-bind", directory, directory]
    for directory in ("/usr/lib/erlang", "/usr/local/lib/erlang"):
        if Path(directory).exists():
            command += ["--tmpfs", directory]
    command += ["--dev", "/dev", "--proc", "/proc", "--tmpfs", "/tmp",
                "--dir", "/var", "--dir", "/var/log",
                "--ro-bind", str(prefix), "/otp", "--bind", str(work), "/work",
                "--chdir", "/work", "--clearenv", "--setenv", "HOME", "/work",
                "--setenv", "PATH", "/usr/bin:/bin", "--setenv", "LANG", "C.UTF-8",
                "--", "/usr/bin/python3", "/work/start-controller.py", str(prefix)]
    run(command)
    return json.loads((work / "start-chain.json").read_text())


def darwin_chain(prefix, work, run, build, source):
    from types import SimpleNamespace
    from host_testing import seatbelt
    root = work / 'start-chain'
    root.mkdir()
    relocated = root / 'OTP 日本'
    shutil.copytree(prefix, relocated, symlinks=True)
    for name in ('check_start.py', 'host_testing.py'):
        shutil.copy2(Path(__file__).parent / name, root / name)
    shutil.copy2(build / 'otp_test_host_observer', root / 'host-observer')
    sdk = Path(json.loads((build / 'sdk-selection.json').read_text())['prefix'])
    isolation = seatbelt(SimpleNamespace(bwrap=shutil.which('sandbox-exec')), root,
                         [prefix, source, build, sdk])
    run([*isolation, sys.executable, str(root / 'check_start.py'), '--darwin', str(root)])
    result = json.loads((root / 'start-chain.json').read_text())
    (work / 'start-chain.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


def darwin_controller(root):
    from host_testing import snapshot, owned_processes, stop_owned_processes
    root = Path(root).resolve(strict=True)
    prefix, observer = root / 'OTP 日本', root / 'host-observer'
    ready, stop = root / 'start-ready', root / 'start-stop'
    expected = {str(p.relative_to(prefix)): hashlib.sha256(p.read_bytes()).hexdigest()
                for pattern in ('erts-*/bin/beam.smp', 'erts-*/bin/erl_child_setup')
                for p in prefix.glob(pattern)}
    expression = ('P=open_port({spawn,"cat"},[]),'
        f'ok=file:write_file({json.dumps(str(ready))},os:getpid()),'
        f'Wait=fun F()->case file:read_file({json.dumps(str(stop))}) of '
        '{ok,_}->ok;_->receive after 20->F() end end end,'
        'Wait(),true=port_close(P),init:stop().')
    pipes = root / 'pipes'
    pipes.mkdir()
    env = dict(os.environ, RUN_ERL_PIPE_DIR=str(pipes) + '/',
               XDG_STATE_HOME=str(root / 'state'), HOME=str(root),
               ERL_FLAGS="+S2 +SDcpu2 +SDio2 +Ktrue -noshell -eval '" + expression + "'")
    try:
        subprocess.run([str(prefix / 'bin/start')], env=env, check=True, timeout=10, close_fds=True)
        deadline = time.monotonic() + 20
        while not ready.exists() and time.monotonic() < deadline:
            time.sleep(.02)
        if not ready.exists():
            raise RuntimeError('start chain did not boot OTP')
        pid = int(ready.read_text())
        host = snapshot(observer, pid)
        if any(Path(path).name in ('libbeam.so', 'libbeam.dylib') for path in host['files']):
            raise RuntimeError('Static OTP mapped a shared VM')
        observed = {}
        pending, seen = [pid], set()
        while pending:
            current = pending.pop()
            if current in seen:
                continue
            seen.add(current)
            state = snapshot(observer, current)
            image = Path(state['executable'])
            if image.is_relative_to(prefix):
                relative = str(image.relative_to(prefix))
                digest = hashlib.sha256(image.read_bytes()).hexdigest()
                if expected.get(relative) != digest:
                    raise RuntimeError(f'Unexpected runtime image: {image}')
                observed[relative] = digest
            pending.extend(state['children'])
        if observed != expected:
            raise RuntimeError(f'Missing selected runtime/helper: {observed}')
        stop.touch()
        deadline = time.monotonic() + 15
        while owned_processes(observer, root) and time.monotonic() < deadline:
            time.sleep(.02)
        if owned_processes(observer, root):
            raise RuntimeError('start chain did not stop orderly')
        (root / 'start-chain.json').write_text(json.dumps(
            {'status': 'passed', 'images': observed, 'pid': pid,
             'descriptors': len(host['descriptors']), 'threads': host['threads']}, indent=2) + '\n')
    finally:
        stop_owned_processes(observer, root)


def controller():
    import sys
    if Path(sys.argv[1]).exists():
        raise RuntimeError("Original installation is visible inside launcher namespace")
    work = Path("/work")
    expected = json.loads((work / "start-expected.json").read_text())
    # Keep the VM alive while inspecting its actual image/helper, then request
    # OTP shutdown through the ordinary booted evaluator.
    expression = (
        'P=open_port({spawn,"cat"},[]),'
        'ok=file:write_file("/work/start-ready",os:getpid()),'
        'Wait=fun F()->case file:read_file("/work/start-stop") of '
        '{ok,_}->ok;_->receive after 20->F() end end end,'
        'Wait(),true=port_close(P),init:stop().')
    env = dict(os.environ, ERL_FLAGS="+S2 +SDcpu2 +SDio2 +Ktrue -noshell -eval '" + expression + "'")
    subprocess.run(["/otp/bin/start"], env=env, check=True, timeout=10)
    deadline = time.monotonic() + 20
    ready = work / "start-ready"
    while not ready.exists() and time.monotonic() < deadline:
        time.sleep(.02)
    if not ready.exists():
        raise RuntimeError("start chain did not boot OTP")
    pid = int(ready.read_text())
    observed = {}
    pending = [pid]
    while pending:
        child = pending.pop()
        proc = Path(f"/proc/{child}")
        image = os.readlink(proc / "exe")
        if image.startswith("/otp/"):
            relative = image.removeprefix("/otp/")
            digest = hashlib.sha256((proc / "exe").read_bytes()).hexdigest()
            if expected.get(relative) != digest:
                raise RuntimeError(f"Unexpected runtime image: {image}")
            observed[relative] = digest
        for task in (proc / "task").iterdir():
            pending.extend(map(int, (task / "children").read_text().split()))
    if observed != expected:
        raise RuntimeError(f"Missing selected runtime/helper: {observed}")
    maps = Path(f"/proc/{pid}/maps").read_text()
    if "libbeam.so" in maps:
        raise RuntimeError("Static OTP mapped a shared VM")
    (work / "start-stop").touch()
    deadline = time.monotonic() + 15
    while Path(f"/proc/{pid}").exists() and time.monotonic() < deadline:
        time.sleep(.02)
    if Path(f"/proc/{pid}").exists():
        raise RuntimeError("start chain did not stop orderly")
    (work / "start-chain.json").write_text(json.dumps(
        {"status": "passed", "images": observed, "pid": pid}, indent=2) + "\n")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == '--darwin':
        darwin_controller(sys.argv[2])
    else:
        controller()
