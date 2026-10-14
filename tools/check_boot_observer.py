#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Observe OTP primitive activation and restart through the installed product host."""
import argparse
import hashlib
import json
import os
from pathlib import Path
from scratch import scratch
import shutil
import time
import sys
from host_testing import work_root, seatbelt, terminal_mode, stream_flags

from check_compatibility import execute


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('build', 'source', 'sdk', 'bwrap', 'observer-host'):
        parser.add_argument('--' + name, required=True, type=Path)
    parser.add_argument('--cmake', required=True)
    args = parser.parse_args()
    for name in ('build', 'source', 'sdk', 'bwrap'):
        setattr(args, name, getattr(args, name).resolve())
    args.observer_host = args.observer_host.resolve()
    root = work_root(args.build, 'boot-observer') / str(time.time_ns())
    root.mkdir(parents=True)
    with scratch(root):
        prefix = root / 'fresh OTP 日本'
        fixture = root / 'fixture'
        fixture.mkdir()
        environment = {key: value for key, value in os.environ.items()
                       if not key.startswith(('ERL_', 'ERLC_', 'ESCRIPT_', 'BEAM_', 'LD_', 'XDG_'))
                       and key not in {'ROOTDIR', 'BINDIR', 'EMU', 'PROGNAME'}}
        environment.update(HOME=str(root), PATH='/usr/bin:/bin', TERM='dumb')
        execute([args.cmake, '--install', args.build, '--prefix', prefix], root,
                environment, root / 'install.log', timeout=120)
        source = args.source / 'erts/preloaded/src/init.erl'
        observer = args.source / 'tools/fixtures/boot_observer.hrl'
        original = source.read_text()
        entry = 'boot(BootArgs) ->\n    register(init, self()),'
        if original.count(entry) != 1 or original.count('-module(init).') != 1:
            raise RuntimeError('Expected one production init registration entry and module declaration')
        generated = original.replace('-module(init).', '-module(init).\n-export([after_boot/0]).')
        generated = generated.replace(entry, 'boot(BootArgs) ->\n    before_boot(),\n    register(init, self()),')
        generated += '\n-include("boot_observer.hrl").\n'
        (fixture / 'init.erl').write_text(generated)
        shutil.copyfile(observer, fixture / observer.name)
        execute([prefix / 'bin/erlc', '-I', fixture, '-o', fixture, fixture / 'init.erl'],
                root, environment, root / 'compile.log', timeout=90)
        destinations = list((prefix / 'lib').glob('erts-*/ebin/init.beam'))
        if len(destinations) != 1:
            raise RuntimeError('Expected exactly one product init artifact')
        production_hash = hashlib.sha256(destinations[0].read_bytes()).hexdigest()
        embedded = args.build / 'generated/boot-observer'
        embedded.mkdir(parents=True, exist_ok=True)
        manifest = json.loads((args.source / 'bootstrap/manifest.json').read_text())
        for module in manifest['preloads']:
            shutil.copyfile(destinations[0].parent / (module + '.beam'), embedded / (module + '.beam'))
        shutil.copyfile(fixture / 'init.beam', embedded / 'init.beam')
        execute([args.cmake, '--build', args.build, '--target', 'otp_boot_observer_host'],
                root, environment, root / 'link-observer.log', timeout=90)
        product_host = next(prefix.glob('erts-*/bin/beam.smp'))
        production_host_hash = hashlib.sha256(product_host.read_bytes()).hexdigest()
        shutil.copyfile(args.observer_host, product_host)
        result = {'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                  'observer_sha256': hashlib.sha256(observer.read_bytes()).hexdigest(),
                  'production_init_sha256': production_hash,
                  'fixture_init_sha256': hashlib.sha256((embedded / 'init.beam').read_bytes()).hexdigest(),
                  'production_host_sha256': production_host_hash,
                  'observer_host_sha256': hashlib.sha256(product_host.read_bytes()).hexdigest(),
                  'phases': []}
        expected = 'boot_activation_before_init\nboot_activation_first_boot\nboot_activation_restart_ok\n'
        for label in ('fresh', 'relocated', 'isolated'):
            if label == 'relocated':
                moved = root / 'relocated OTP 日本'
                prefix.rename(moved)
                prefix = moved
            work = root / label
            work.mkdir()
            environment['HOME'] = str(work)
            command = [prefix / 'bin/erl', '+S2', '+SDcpu2', '+SDio2',
                       '-noshell', '-noinput', '-s', 'init', 'after_boot']
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
            stdout, stderr = execute(command, work, environment, root / (label + '.log'))
            if stdout.replace('\r\n', '\n') != expected or stderr:
                raise RuntimeError(f'{label}: unexpected observer output: {stdout!r} {stderr!r}')
            result['phases'].append(label)
            (root / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
            print(f'{label}: pre-init activation, 22 preloads and three restarts passed', flush=True)
        print(f'OTP startup observer passed; evidence: {root}')


if __name__ == '__main__':
    main()
