#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise installed standalone libraries and the upstream native test table."""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prefix', type=Path)
    parser.add_argument('--build', type=Path)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--cc', required=True)
    parser.add_argument('--cmake', default='cmake')
    args = parser.parse_args()
    environment = {k: v for k, v in os.environ.items()
                   if not k.startswith(('ERL_', 'ERLC_', 'LD_')) and k not in ('ROOTDIR', 'BINDIR', 'EMU')}
    with tempfile.TemporaryDirectory(prefix='otp-development-') as temporary:
        work = Path(temporary)

        def run(command):
            process = subprocess.Popen([str(x) for x in command], cwd=work, env=environment,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, start_new_session=True)
            try:
                output, _ = process.communicate(timeout=90)
            except BaseException:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()
                raise
            if process.returncode:
                raise RuntimeError(f'{command}: {process.returncode}\n{output}')
            return output

        if args.prefix:
            prefix = args.prefix.resolve()
        else:
            if not args.build:
                parser.error('Select --prefix or --build')
            prefix = work / 'OTP development 日本'
            run([args.cmake, '--install', args.build.resolve(), '--prefix', prefix])
        erts, = prefix.glob('erts-*')
        fixture = args.source.resolve() / 'tools/fixtures'
        for library in ('ei', 'ei_st'):
            client = work / (library + '_probe')
            run([args.cc, fixture / 'ei_probe.c', '-I', prefix / 'usr/include',
                 prefix / f'usr/lib/lib{library}.a',
                 *(['-pthread'] if library == 'ei' else []), '-lm', '-o', client])
            if run([client]) != 'ei_passed\n':
                raise RuntimeError(f'Installed {library} contract failed')
        includes = ['-I', erts / 'include', '-I', erts / 'include/internal']
        flags = ['-D_GNU_SOURCE', '-DUSE_THREADS', '-D_REENTRANT', '-pthread']
        run([args.cc, *flags, *includes, fixture / 'development_support.c',
             erts / 'lib/internal/libethread.a', erts / 'lib/internal/liberts_internal_r.a',
             '-lm', *([] if sys.platform == 'darwin' else ['-lrt']), '-o', work / 'support'])
        run([work / 'support'])
        run([args.cc, *flags, *includes, *(['-bundle', '-Wl,-undefined,dynamic_lookup'] if sys.platform == 'darwin' else ['-shared', '-fPIC']), fixture / 'development_probe.c',
             '-o', work / 'development_probe.so'])
        run([prefix / 'bin/erlc', '-o', work, fixture / 'development_probe.erl'])
        expression = (f'ok=development_probe:load({json.dumps(str(work / "development_probe"))}),'
                      'ok=development_probe:check(),halt().')
        run([prefix / 'bin/erl', '+S1', '-noshell', '-pa', work, '-eval', expression])
        print('Installed standalone support and native test-table ABI passed')


if __name__ == '__main__':
    main()
