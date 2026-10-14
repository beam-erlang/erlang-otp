#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check linked OTP native activation, origins and genuine helper recovery."""
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
from host_testing import work_root, seatbelt, identity_expression


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('build', 'source', 'sdk', 'bwrap'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--cmake', required=True)
    args = parser.parse_args()
    root = work_root(args.build, 'native-activation') / str(time.time_ns())
    root.mkdir(parents=True)
    with scratch(root):
        prefix = root / 'fresh OTP 日本'
        with (root / 'install.log').open('w') as log:
            subprocess.run([args.cmake, '--install', args.build, '--prefix', prefix],
                           check=True, stdout=log, stderr=subprocess.STDOUT)
        inventory = json.loads((args.build / 'native-components.json').read_text())
        builtins = {(record['kind'], record['module']) for record in inventory if record['kind'].startswith('builtin-')}
        assert {('builtin-nif', 'prim_tty'), ('builtin-nif', 'zstd'),
                ('builtin-driver', 'ram_file_drv')} <= builtins
        assert all(not record['installed'] for record in inventory if record['kind'].startswith('builtin-'))
        helper = next(prefix.glob('erts-*/bin/erl_child_setup'))
        selected = {'erl_child_setup': str(helper.relative_to(prefix))}
        hashes = {name: hashlib.sha256((prefix / path).read_bytes()).hexdigest()
                  for name, path in selected.items()}
        env = {k: v for k, v in os.environ.items()
               if not k.startswith(('ERL_', 'ERLC_', 'ESCRIPT_', 'BEAM_', 'LD_', 'XDG_'))
               and k not in {'BINDIR', 'ROOTDIR', 'EMU', 'PROGNAME'}}
        env.update(PATH='/usr/bin:/bin', LANG='C.UTF-8', LC_ALL='C.UTF-8', TERM='dumb',
                   ERL_CRASH_DUMP_SECONDS='0')
        expression = (
            'ok=prim_tty:load(),Data = <<"owned-native">>,'
            'Data=iolist_to_binary(zstd:decompress(zstd:compress(Data))),'
            '{ok,F}=ram_file:open(Data,[read,write,binary]),{ok,Data}=file:read(F,byte_size(Data)),'
            'ok=file:close(F),[]=erlang:system_info(taints),'
            '{ok,Maps}=file:read_file("/proc/self/maps"),'
            'nomatch=binary:match(Maps,<<"libbeam.so">>),'
            'Host=filename:join([code:root_dir(),"erts-"++erlang:system_info(version),"bin","beam.smp"]),'
            '{ok,Host}=file:read_link("/proc/self/exe"),'
            'true=binary:match(Maps,unicode:characters_to_binary(Host))=/=nomatch,'
            '{ok,Loaded}=erl_ddll:loaded_drivers(),'
            'lists:foreach(fun(D)->true=lists:member(D,Loaded),'
            'true=erl_ddll:info(D,linked_in_driver),false=erl_ddll:info(D,permanent),'
            'linked_in_driver=erl_ddll:info(D,processes),'
            '{error,linked_in_driver}=erl_ddll:unload_driver(D) end,["tcp_inet","udp_inet","ram_file_drv"]),'
            '"helper-ok"=os:cmd("printf helper-ok"),'
            'io:put_chars("OTP_NATIVE_ACTIVATION_OK\\n"),halt().')
        if sys.platform == 'darwin':
            linux = ('{ok,Maps}=file:read_file("/proc/self/maps"),'
                     'nomatch=binary:match(Maps,<<"libbeam.so">>),'
                     'Host=filename:join([code:root_dir(),"erts-"++erlang:system_info(version),"bin","beam.smp"]),'
                     '{ok,Host}=file:read_link("/proc/self/exe"),'
                     'true=binary:match(Maps,unicode:characters_to_binary(Host))=/=nomatch,')
            assert linux in expression
            expression = expression.replace(linux, identity_expression(args.build, root))
        result = {'artifacts': hashes, 'phases': []}
        for phase in ('fresh', 'relocated', 'isolated'):
            if phase == 'relocated':
                moved = root / 'relocated OTP 日本'
                prefix.rename(moved)
                prefix = moved
            work = root / phase
            work.mkdir()
            env['HOME'] = str(work)
            isolation = []
            if phase == 'isolated' and sys.platform == 'darwin':
                isolation = seatbelt(args, work, (args.source, args.build, args.sdk))
                for absent in (args.source, args.build, args.sdk):
                    subprocess.run(isolation + ['/bin/test', '!', '-e', str(absent.resolve())],
                                   check=True, env=env, timeout=10, close_fds=True)
            elif phase == 'isolated':
                isolation = [str(args.bwrap), '--unshare-user', '--unshare-pid', '--die-with-parent']
                for path in ('/usr', '/bin', '/lib', '/lib64', '/etc'):
                    if Path(path).exists():
                        isolation += ['--ro-bind', path, path]
                for path in ('/usr/lib/erlang', '/usr/local/lib/erlang'):
                    if Path(path).exists():
                        isolation += ['--tmpfs', path]
                isolation += ['--dev', '/dev', '--proc', '/proc', '--tmpfs', '/tmp',
                              '--ro-bind', str(prefix), '/otp', '--bind', str(work), '/work',
                              '--chdir', '/work', '--setenv', 'HOME', '/work', '--']
                for absent in (args.source, args.build, args.sdk):
                    subprocess.run(isolation + ['/usr/bin/test', '!', '-e', str(absent.resolve())],
                                   check=True, env=env, timeout=10)
            executable = '/otp/bin/erl' if isolation and sys.platform != 'darwin' else str(prefix / 'bin/erl')
            command = isolation + [executable, '+S1', '+SDcpu1', '+SDio1', '-noshell', '-noinput',
                                   '-eval', expression]

            def run(label, missing=None):
                process = subprocess.Popen(command, cwd=work, env=env, stdout=subprocess.PIPE,
                                           stderr=subprocess.STDOUT, text=True, start_new_session=True, close_fds=True)
                try:
                    output, _ = process.communicate(timeout=30)
                except BaseException:
                    os.killpg(process.pid, signal.SIGKILL)
                    output, _ = process.communicate()
                    (work / (label + '.log')).write_text(output)
                    raise
                (work / (label + '.log')).write_text(output)
                if missing:
                    # OTP prints the failed eval expression, which contains the
                    # success string as source text. Only a complete output line
                    # is the success marker.
                    diagnostic = 'program helper is missing or not executable' in output
                    if process.returncode == 0 or 'OTP_NATIVE_ACTIVATION_OK' in output.splitlines() or not diagnostic:
                        raise RuntimeError(f'{phase}/{label}: missing artifact was not rejected: {output}')
                elif process.returncode or output != 'OTP_NATIVE_ACTIVATION_OK\n':
                    raise RuntimeError(f'{phase}/{label}: activation failed ({process.returncode}): {output}')

            run('available')
            for name, path in selected.items():
                artifact = prefix / path
                held = artifact.with_name(artifact.name + '.held')
                artifact.rename(held)
                try:
                    run('missing-' + name, name)
                finally:
                    held.rename(artifact)
                if hashlib.sha256(artifact.read_bytes()).hexdigest() != hashes[name]:
                    raise RuntimeError('Fixture changed artifact bytes')
                run('recovered-' + name)
            result['phases'].append(phase)
            (root / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
            print(f'{phase}: linked native behavior, executable origins and helper recovery passed', flush=True)
        print(f'OTP native activation passed; evidence: {root}')


if __name__ == '__main__':
    main()
