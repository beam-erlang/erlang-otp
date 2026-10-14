# SPDX-License-Identifier: Apache-2.0
"""Native host observations and execution isolation for product acceptance only."""
import json
from pathlib import Path
import shutil
import subprocess
import sys


def work_root(build, category):
    build = Path(build).resolve()
    base = build.parent / (build.name + '-acceptance') if sys.platform == 'darwin' else build / 'checks'
    return base / category


def seatbelt(args, work, denied):
    if sys.platform != 'darwin':
        raise RuntimeError('Seatbelt requires a Darwin host')
    tool = Path(args.bwrap).resolve(strict=True)
    if tool.name != 'sandbox-exec' or not tool.is_file():
        raise RuntimeError('Select the required sandbox-exec isolation backend')
    work = Path(work).resolve(strict=True)
    rules = ['(version 1)', '(allow default)']
    for item in sorted({str(Path(path).resolve(strict=True)) for path in denied}):
        if work.is_relative_to(item):
            raise RuntimeError('Execution scratch must be outside denied assembly inputs')
        rules.append('(deny file-read* file-write* process-exec file-map-executable '
                     '(subpath ' + json.dumps(item) + '))')
    profile = work / 'execution-isolation.sb'
    profile.write_text('\n'.join(rules) + '\n')
    return [str(tool), '-f', str(profile)]


def identity_expression(build, work):
    """Inspect the actual live host using a copied test-owned OS executable."""
    observer = Path(work) / 'host-observer'
    source = Path(build)
    shutil.copy2(source if source.is_file() else source / 'otp_test_host_observer', observer)
    return ('Host=filename:join([code:root_dir(),"erts-"++erlang:system_info(version),"bin","beam.smp"]),'
            'HostProbe=open_port({spawn_executable,' + json.dumps(str(observer), ensure_ascii=False) + '},'
            '[binary,exit_status,{args,["--verify-static",os:getpid(),Host]}]),'
            'HostRead=fun F(Acc)->receive '
            '{HostProbe,{data,B}}->F(<<Acc/binary,B/binary>>);'
            '{HostProbe,{exit_status,0}}-><<"STATIC_HOST_OK\\n">>=Acc '
            'after 5000->error(host_observation_timeout) end end,'
            'HostRead(<<>>),')


def select_observer(build, work, environment):
    observer = Path(work) / 'host-observer'
    source = Path(build)
    shutil.copy2(source if source.is_file() else source / 'otp_test_host_observer', observer)
    environment['OTP_TEST_HOST_OBSERVER'] = str(observer)
    return observer


def terminal_mode(fd):
    import termios
    mode = termios.tcgetattr(fd)
    if sys.platform == 'darwin':
        # PENDIN is kernel input history set by canonical-mode restoration.
        mode[3] &= ~termios.PENDIN
    return mode


def stream_flags(fd):
    import fcntl
    flags = fcntl.fcntl(fd, fcntl.F_GETFL)
    if sys.platform == 'darwin':
        # XNU FWASWRITTEN is descriptor history, not a mutable F_SETFL option.
        # https://github.com/apple/darwin-xnu/blob/main/bsd/sys/fcntl.h
        flags &= ~0x00010000
    return flags


class TerminalAnchor:
    """Keep Darwin's controlling session alive to inspect VM exit restoration.

    A session leader's exit revokes Darwin PTYs. The anchor never changes the
    terminal modes or stream flags; the product remains responsible for them.
    """
    def __init__(self, command, *, cwd, env, slave, preexec_fn):
        import os
        self.status_read, status_write = os.pipe()
        control_read, self.control_write = os.pipe()
        script = (f'trap "" INT; "$@" {status_write}>&- {control_read}<&-; '
                  f'code=$?; printf "%s\\n" "$code" >&{status_write}; '
                  f'IFS= read -r done <&{control_read}; exit 0')
        try:
            self.anchor = subprocess.Popen(['/bin/sh', '-c', script, 'terminal-anchor',
                                            *map(str, command)], cwd=cwd, env=env,
                stdin=slave, stdout=slave, stderr=slave, preexec_fn=preexec_fn,
                close_fds=True, pass_fds=(status_write, control_read))
        except BaseException:
            os.close(self.status_read)
            os.close(self.control_write)
            raise
        finally:
            os.close(status_write)
            os.close(control_read)
        self.pid = self.anchor.pid
        self.returncode = None
        self.status = bytearray()

    def poll(self):
        import os
        import select
        if self.returncode is None and select.select([self.status_read], [], [], 0)[0]:
            chunk = os.read(self.status_read, 64)
            if not chunk:
                raise RuntimeError('Terminal anchor lost the VM exit status')
            self.status.extend(chunk)
            if b'\n' in self.status:
                if not self.status.endswith(b'\n') or not self.status[:-1].isdigit():
                    raise RuntimeError('Invalid VM exit status from terminal anchor')
                self.returncode = int(self.status[:-1])
        if self.returncode is None and self.anchor.poll() is not None:
            raise RuntimeError('Terminal anchor exited before the VM')
        return self.returncode

    def close(self):
        import os
        import signal
        try:
            if self.returncode is not None:
                os.write(self.control_write, b'done\n')
            elif self.anchor.poll() is None:
                os.killpg(self.pid, signal.SIGKILL)
            try:
                self.anchor.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(self.pid, signal.SIGKILL)
                self.anchor.wait()
        finally:
            os.close(self.control_write)
            os.close(self.status_read)


def owned_processes(observer, root):
    """Find running executables inside one uniquely owned validation prefix."""
    import os
    result = subprocess.run([str(observer), '--owned-prefix', str(root)],
                            capture_output=True, timeout=5, check=True, close_fds=True)
    if result.stderr or len(result.stdout) > 1048576:
        raise RuntimeError('Owned-process observation failed')
    record = json.loads(result.stdout)
    if set(record) != {'processes'} or not isinstance(record['processes'], list):
        raise RuntimeError('Invalid owned-process inventory')
    for process in record['processes']:
        if (set(process) != {'pid', 'executable'} or type(process['pid']) is not int or
                process['pid'] <= 1 or process['pid'] == os.getpid() or
                not Path(process['executable']).is_relative_to(root)):
            raise RuntimeError('Invalid owned process origin')
    return record['processes']


def stop_owned_processes(observer, root):
    import os
    import signal
    import time
    for signum in (signal.SIGTERM, signal.SIGKILL):
        for process in owned_processes(observer, root):
            try:
                os.kill(process['pid'], signum)
            except ProcessLookupError:
                pass
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if not owned_processes(observer, root):
                return
            time.sleep(0.02)
    raise RuntimeError('Task-owned validation processes survived cleanup')


def snapshot(observer, pid):
    result = subprocess.run([str(observer), '--snapshot', str(pid)],
                            capture_output=True, timeout=5, check=True, close_fds=True)
    if result.stderr or len(result.stdout) > 1048576:
        raise RuntimeError('Native process snapshot failed')
    record = json.loads(result.stdout)
    if (set(record) != {'executable', 'files', 'threads', 'descriptors', 'children'} or
            not record['files'] or record['threads'] <= 0 or not record['descriptors']):
        raise RuntimeError('Invalid native process snapshot')
    return record


from contextlib import contextmanager

@contextmanager
def owned_runtime_scope(build, root):
    """Stop detached images from this unique fixture before removing payloads."""
    if sys.platform != 'darwin':
        yield
        return
    observer = Path(root) / 'host-observer'
    shutil.copy2(Path(build) / 'otp_test_host_observer', observer)
    failed = False
    try:
        yield
    except BaseException:
        failed = True
        raise
    finally:
        survivors = owned_processes(observer, root)
        if survivors:
            stop_owned_processes(observer, root)
        (Path(root) / 'process-cleanup.json').write_text(json.dumps({
            'survivors_before_cleanup': survivors,
            'owned_processes_after_cleanup': owned_processes(observer, root)}, indent=2) + '\n')
        if survivors and not failed:
            raise RuntimeError(f'Validation left task-owned processes: {survivors}')
