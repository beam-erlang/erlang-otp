#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Run GUI acceptance on a disposable X server inside private namespaces."""
import argparse
import os
from pathlib import Path
import select
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--xvfb', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--timeout', type=int, help='Optional command deadline in seconds')
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('a command is required')
    environment = {key: value for key, value in os.environ.items()
                   if key not in {'DISPLAY', 'WAYLAND_DISPLAY', 'XAUTHORITY',
                                  'DBUS_SESSION_BUS_ADDRESS', 'SESSION_MANAGER', 'XDG_RUNTIME_DIR'}}
    environment.update(LIBGL_ALWAYS_SOFTWARE='1', GDK_BACKEND='x11')
    read_fd, write_fd = os.pipe()
    with (args.work / 'xvfb.log').open('w') as log:
        server = subprocess.Popen([str(args.xvfb), '-displayfd', str(write_fd),
            '-screen', '0', '1024x768x24', '+extension', 'GLX', '-nolisten', 'tcp', '-ac'],
            env=environment, stdout=log, stderr=subprocess.STDOUT, pass_fds=(write_fd,))
        os.close(write_fd)
        try:
            readable, _, _ = select.select([read_fd], [], [], 15)
            if not readable:
                raise RuntimeError('Xvfb did not report display readiness')
            display = os.read(read_fd, 64).decode().strip()
            if not display.isdigit() or server.poll() is not None:
                raise RuntimeError('Xvfb failed to start; inspect xvfb.log')
            environment.update(DISPLAY=':' + display, OTP_WX_STATE=str(args.work / 'wx-restart'))
            status = subprocess.run(command, env=environment, timeout=args.timeout).returncode
        finally:
            os.close(read_fd)
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
    raise SystemExit(status)


if __name__ == '__main__':
    main()
