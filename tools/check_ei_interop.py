#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise installed candidate libei archives with an attested original node."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import time
from installation_inventory import verify_installation
from host_testing import work_root
from scratch import scratch


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source', 'build', 'reference-prefix', 'reference-provenance'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--cc', required=True)
    parser.add_argument('--cmake', default='cmake')
    parser.add_argument('--work-root', type=Path)
    args = parser.parse_args()
    reference = args.reference_prefix.resolve(strict=True)
    provenance = verify_installation(reference, args.reference_provenance)
    if provenance['runtime'] != 'reference':
        raise RuntimeError('Interoperability requires an original-build reference')
    root = args.work_root or work_root(args.build, 'ei-interop')
    work = root / str(time.time_ns())
    work.mkdir(parents=True)
    with scratch(work):
        prefix = work / 'candidate'
        environment = {k: v for k, v in os.environ.items()
                       if not k.startswith(('ERL_', 'ERLC_', 'LD_', 'DYLD_'))
                       and k not in {'ROOTDIR', 'BINDIR', 'EMU'}}
        environment.update(HOME=str(work), PATH='/usr/bin:/bin')

        def run(command):
            result = subprocess.run(command, cwd=work, env=environment,
                                    capture_output=True, text=True, timeout=90)
            with (work / 'execution.log').open('a') as log:
                log.write(json.dumps(list(map(str,command)))+'\n'+result.stdout+result.stderr)
            if result.returncode:
                raise RuntimeError(result.stdout + result.stderr)
            return result.stdout

        run([args.cmake, '--install', args.build, '--prefix', prefix])
        source = work / 'ei_probe.c'
        shutil.copyfile(args.source / 'tools/fixtures/ei_probe.c', source)
        for library in ('ei', 'ei_st'):
            run([args.cc, source, '-I', prefix / 'usr/include', prefix / f'usr/lib/lib{library}.a',
                 *(['-pthread'] if library == 'ei' else []), '-lm', '-o', work / library])
        with socket.socket() as reservation:
            reservation.bind(('127.0.0.1',0))
            epmd_port = reservation.getsockname()[1]
        environment['ERL_EPMD_PORT'] = str(epmd_port)
        processes = []
        with (work / 'nodes.log').open('w') as log:
            try:
                daemon = subprocess.Popen([reference / 'bin/epmd', '-port', str(epmd_port), '-address', '127.0.0.1'],
                    cwd=work, env=environment, stdout=log, stderr=log, start_new_session=True)
                processes.append(daemon)
                deadline = time.monotonic()+10
                while True:
                    if daemon.poll() is not None:
                        raise RuntimeError('Private reference EPMD exited')
                    try:
                        with socket.create_connection(('127.0.0.1',epmd_port),timeout=0.2):
                            break
                    except OSError:
                        if time.monotonic() > deadline:
                            raise RuntimeError('Reference EPMD did not become ready')
                        time.sleep(0.02)
                port_file = work / 'reference-port'
                node = 'codec_reference_' + str(os.getpid())
                expression = (f'{{port,P,_}}=erl_epmd:port_please("{node}","127.0.0.1"),'
                              f'ok=file:write_file({json.dumps(str(port_file))},integer_to_binary(P)),'
                              'receive stop -> halt() end.')
                process = subprocess.Popen([reference / 'bin/erl','+S2','-noshell','-sname',node+'@localhost',
                    '-setcookie','etf_interop_cookie','-start_epmd','false','-eval',expression],
                    cwd=work,env=environment,stdout=log,stderr=log,start_new_session=True)
                processes.append(process)
                deadline = time.monotonic()+20
                while not port_file.exists():
                    if process.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError('Original node did not publish its distribution port')
                    time.sleep(0.02)
                for library in ('ei','ei_st'):
                    if run([work / library,port_file.read_text()]) != 'ei_passed\n':
                        raise RuntimeError('Unexpected reference roundtrip result')
            finally:
                for process in reversed(processes):
                    if process.poll() is None:
                        os.killpg(process.pid,signal.SIGTERM)
                        try:
                            process.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            os.killpg(process.pid,signal.SIGKILL); process.wait()
        (work / 'result.json').write_text(json.dumps({
            'sdk': json.loads((args.build/'sdk-selection.json').read_text()),
            'reference_provenance_sha256': hashlib.sha256(args.reference_provenance.read_bytes()).hexdigest(),
            'upstream_commit': provenance['upstream_commit'],
            'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'archives': {name: hashlib.sha256((prefix/f'usr/lib/lib{name}.a').read_bytes()).hexdigest()
                         for name in ('ei','ei_st')},
            'passed': True}, indent=2)+'\n')
    print('Both standalone ei archives passed original-node ETF roundtrips')


if __name__ == '__main__':
    main()
