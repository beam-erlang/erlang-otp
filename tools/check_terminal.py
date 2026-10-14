#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check OTP shell break/continue and terminal restoration in installed prefixes."""
import argparse
import errno
import fcntl
import json
import os
from pathlib import Path
from scratch import scratch
import pty
import re
import select
import signal
import subprocess
import termios
import time
import sys
from host_testing import work_root, seatbelt, terminal_mode, stream_flags, TerminalAnchor

from check_compatibility import execute


def shell(command, work, environment, log, isolated=False):
    terminal, slave = pty.openpty()
    initial = terminal_mode(slave)
    flags = stream_flags(slave)
    transcript = bytearray()
    process = None

    def controlling_terminal():
        os.setsid()
        fcntl.ioctl(0, termios.TIOCSCTTY, 0)
        if isolated:
            # Keep the namespace supervisor alive when the terminal signals its
            # foreground group. The product explicitly installs its own SIGINT
            # handler at process entry; that handler must produce the menu.
            signal.signal(signal.SIGINT, signal.SIG_IGN)

    def prompt(marker):
        deadline = time.monotonic() + 20
        output = bytearray()
        while time.monotonic() < deadline:
            clean = re.sub(rb'\x1b\[[0-9;?]*[ -/]*[@-~]', b'', output)
            if marker in clean:
                return clean.replace(b'\r\n', b'\n')
            if select.select([terminal], [], [], max(0, deadline - time.monotonic()))[0]:
                chunk = os.read(terminal, 65536)
                if not chunk:
                    break
                output.extend(chunk)
                transcript.extend(chunk)
        raise RuntimeError(f'Shell did not reach {marker!r} (status {process.poll()}): {bytes(transcript)!r}')

    try:
        if sys.platform == 'darwin':
            process = TerminalAnchor(command, cwd=work, env=dict(environment, TERM='xterm'),
                                     slave=slave, preexec_fn=controlling_terminal)
        else:
            process = subprocess.Popen([str(arg) for arg in command], cwd=work,
                                       env=dict(environment, TERM='xterm'), stdin=slave,
                                       stdout=slave, stderr=slave, preexec_fn=controlling_terminal)
        prompt(b'1> ')
        os.write(terminal, b'X = 40 + 2.\n')
        if b'\n42\n' not in prompt(b'2> '):
            raise RuntimeError('Shell did not evaluate the binding')
        running = terminal_mode(slave)
        running_flags = stream_flags(slave)
        os.write(terminal, b'\x03')
        prompt(b'(d)istribution')
        if terminal_mode(slave) != initial or not os.get_blocking(slave):
            raise RuntimeError('Break menu did not restore initial terminal mode and blocking streams')
        os.write(terminal, b'c\n')
        deadline = time.monotonic() + 5
        while terminal_mode(slave) != running or stream_flags(slave) != running_flags:
            if time.monotonic() >= deadline:
                raise RuntimeError('Continue did not restore the running shell terminal and stream flags')
            time.sleep(0.01)
        os.write(terminal, b'X + 1.\n')
        if b'\n43\n' not in prompt(b'3> '):
            raise RuntimeError('Shell lost its binding after break/continue')
        os.write(terminal, b'halt().\n')
        deadline = time.monotonic() + 10
        while process.poll() is None:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise RuntimeError('Shell did not halt')
            if select.select([terminal], [], [], min(remaining, 0.05))[0]:
                try:
                    transcript.extend(os.read(terminal, 65536))
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
        if process.returncode:
            raise RuntimeError('Shell exited with an error')
        if terminal_mode(slave) != initial or stream_flags(slave) != flags:
            raise RuntimeError('Shell exit did not restore initial terminal and stream flags')
    finally:
        if isinstance(process, TerminalAnchor):
            process.close()
        elif process is not None and process.poll() is None:
            try:
                if os.getpgid(process.pid) == process.pid:
                    os.killpg(process.pid, signal.SIGKILL)
                else:
                    process.kill()
            except ProcessLookupError:
                pass
            except PermissionError:
                process.kill()
            process.wait()
        log.write_bytes(bytes(transcript))
        os.close(slave)
        os.close(terminal)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('build', 'source', 'sdk', 'bwrap'):
        parser.add_argument('--' + name, required=True, type=Path)
    parser.add_argument('--cmake', required=True)
    args = parser.parse_args()
    for name in ('build', 'source', 'sdk', 'bwrap'):
        setattr(args, name, getattr(args, name).resolve())
    root = work_root(args.build, 'terminal') / str(time.time_ns())
    root.mkdir(parents=True)
    with scratch(root):
        prefix = root / 'fresh OTP 日本'
        environment = {key: value for key, value in os.environ.items()
                       if not key.startswith(('ERL_', 'ERLC_', 'ESCRIPT_', 'BEAM_', 'LD_', 'XDG_'))
                       and key not in {'ROOTDIR', 'BINDIR', 'EMU', 'PROGNAME'}}
        environment.update(HOME=str(root), PATH='/usr/bin:/bin')
        execute([args.cmake, '--install', args.build, '--prefix', prefix], root,
                environment, root / 'install.log', timeout=120)
        phases = []
        for label in ('fresh', 'relocated', 'isolated'):
            if label == 'relocated':
                moved = root / 'relocated OTP 日本'
                prefix.rename(moved)
                prefix = moved
            work = root / label
            work.mkdir()
            environment['HOME'] = str(work)
            command = [prefix / 'bin/erl', '+S1', '+SDcpu1', '+SDio1']
            if label == 'isolated' and sys.platform == 'darwin':
                isolation = seatbelt(args, work, (args.source, args.build, args.sdk))
                for number, absent in enumerate((args.source, args.build, args.sdk)):
                    execute([*isolation, '/bin/test', '!', '-e', absent], work,
                            environment, root / f'absent-{number}.log')
                command = [*isolation, *command]
            elif label == 'isolated':
                isolation = [args.bwrap, '--unshare-user', '--unshare-pid', '--die-with-parent']
                for directory in ('/usr', '/bin', '/lib', '/lib64', '/etc'):
                    if Path(directory).exists():
                        isolation += ['--ro-bind', directory, directory]
                for runtime in ('/usr/lib/erlang', '/usr/local/lib/erlang'):
                    if Path(runtime).exists():
                        isolation += ['--tmpfs', runtime]
                isolation += ['--dev', '/dev', '--proc', '/proc', '--tmpfs', '/tmp',
                              '--ro-bind', prefix, '/OTP 日本', '--bind', work, '/work',
                              '--chdir', '/work', '--setenv', 'HOME', '/work', '--']
                for number, absent in enumerate((args.source, args.build, args.sdk)):
                    execute([*isolation, '/usr/bin/test', '!', '-e', absent], work,
                            environment, root / f'absent-{number}.log')
                command = [*isolation, '/OTP 日本/bin/erl', *command[1:]]
            shell(command, work, environment, root / (label + '.log'), label == 'isolated')
            phases.append(label)
            (root / 'results.json').write_text(json.dumps({'phases': phases}, indent=2) + '\n')
            print(f'{label}: shell binding, break/continue and terminal restoration passed', flush=True)
        print(f'OTP terminal acceptance passed; evidence: {root}')


if __name__ == '__main__':
    main()
