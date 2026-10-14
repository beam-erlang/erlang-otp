#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Independent standard-release startup, restart and native lifecycle acceptance."""
import argparse
import errno
import hashlib
import json
import os
from pathlib import Path
from scratch import scratch
import pty
import re
import select
import shutil
import signal
import socket
import subprocess
import tarfile
import time
import zipfile
import sys
from host_testing import work_root, seatbelt, snapshot, owned_processes, stop_owned_processes

REBAR_SHA256 = 'af85aab41f9fd74bdd6341ebdf6fe9c88077aab9f8eac82371583fa02f2b0bdf'


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def host_vm_pid(root_pid, reported_pid):
    if sys.platform == 'darwin':
        if os.getpgid(reported_pid) != root_pid:
            raise RuntimeError('Reported release VM is outside its owned process group')
        return reported_pid
    # A release's private PID namespace also contains its daemonized EPMD.
    # Resolve the reported VM through our child tree for host-side origin checks.
    pending, seen, matches = [root_pid], set(), []
    while pending:
        pid = pending.pop()
        if pid in seen:
            continue
        seen.add(pid)
        proc = Path(f'/proc/{pid}')
        try:
            status = (proc / 'status').read_text()
            ids = re.search(r'^NSpid:\s+(.+)$', status, re.MULTILINE)
            if ids and int(ids.group(1).split()[-1]) == reported_pid and Path(os.readlink(proc / 'exe')).name == 'beam.smp':
                matches.append(pid)
            for task in (proc / 'task').iterdir():
                pending.extend(map(int, (task / 'children').read_text().split()))
        except FileNotFoundError:
            continue
    if len(matches) != 1:
        raise RuntimeError(f'Cannot identify the selected VM in its process group: {matches}')
    return matches[0]


def console(command, env, work, expected, log):
    child, terminal = pty.fork()
    if child == 0:
        os.chdir(work)
        os.execvpe(str(command[0]), list(map(str, command)), env)
    transcript = bytearray()
    waited = False

    def prompt(number):
        output = bytearray()
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            clean = re.sub(rb'\x1b\[[0-9;?]*[ -/]*[@-~]', b'', output).replace(b'\r\n', b'\n')
            if re.search(rb'(?:^|\n)(?:\([^\n]*\))?' + str(number).encode() + rb'> ', clean):
                return clean
            if select.select([terminal], [], [], max(0, deadline - time.monotonic()))[0]:
                try:
                    data = os.read(terminal, 65536)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    break
                if not data:
                    break
                output.extend(data)
                transcript.extend(data)
        raise RuntimeError(f'Release prompt {number} missing; see {log}')

    origins = []
    try:
        prompt(1)
        for cycle in range(3):
            os.write(terminal, b'ok=otp_release_probe:check(),io:format("CHECK_OK PID=~s~n",[os:getpid()]).\n')
            output = prompt(2)
            match = re.search(rb'\nCHECK_OK PID=(\d+)\n', output)
            if not match:
                raise RuntimeError(f'Release lifecycle failed; see {log}')
            pid = host_vm_pid(child, int(match[1]))
            if sys.platform == 'darwin':
                state = snapshot(expected['observer'], pid)
                executable = state['executable']
                release = expected['release']
                if executable != str(release / expected['host_path']) or sha256(Path(executable)) != expected['host']:
                    raise RuntimeError('Release executable differs from selected host')
                images, helpers = [], []
                for image in state['files']:
                    path = Path(image)
                    if path.name in ('libbeam.so', 'libbeam.dylib'):
                        raise RuntimeError('Release mapped a shared VM')
                    if path.is_relative_to(release):
                        relative = path.relative_to(release).as_posix()
                        if expected['images'].get(relative) != sha256(path):
                            raise RuntimeError(f'Release image differs from selected input: {image}')
                        images.append(image)
                    elif not image.startswith(('/usr/', '/System/')):
                        raise RuntimeError(f'Release image escaped selected inputs: {image}')
                for helper_pid in state['children']:
                    helper_state = snapshot(expected['observer'], helper_pid)
                    image = Path(helper_state['executable'])
                    if image.name == 'erl_child_setup':
                        if image != release / expected['helper_path'] or sha256(image) != expected['helper']:
                            raise RuntimeError('Release helper escaped selected ERTS')
                        helpers.append(str(image))
                if len(helpers) != 1:
                    raise RuntimeError('Release child helper was not observed')
                origins.append({'cycle': cycle, 'pid': pid, 'executable': executable,
                                'helpers': helpers, 'images': sorted(images),
                                'threads': state['threads'], 'descriptors': state['descriptors']})
                if cycle < 2:
                    os.write(terminal, b'init:restart().\n')
                    prompt(1)
                continue
            executable = os.readlink(f'/proc/{pid}/exe')
            if executable != '/release 日本/' + expected['host_path'] or sha256(Path(f'/proc/{pid}/exe')) != expected['host']:
                raise RuntimeError('Release executable differs from selected host')
            maps = Path(f'/proc/{pid}/maps').read_text()
            if 'libbeam.so' in maps:
                raise RuntimeError('Release mapped a shared VM')
            images = set()
            for line in maps.splitlines():
                fields = line.split(maxsplit=5)
                if len(fields) < 6 or not fields[5].startswith('/') or fields[5].startswith('/memfd:'):
                    continue
                image = fields[5]
                if image.startswith('/release 日本/'):
                    images.add(image)
                    path = image.removeprefix('/release 日本/')
                    if expected['images'].get(path) != sha256(Path(f'/proc/{pid}/root') / image.lstrip('/')):
                        raise RuntimeError(f'Release image differs from selected input: {image}')
                elif not image.startswith(('/usr/', '/lib/', '/lib64/')):
                    raise RuntimeError(f'Release image escaped isolation: {image}')
            children = set()
            for task in Path(f'/proc/{pid}/task').iterdir():
                children.update((task / 'children').read_text().split())
            helpers = []
            for helper_pid in children:
                try:
                    image = os.readlink(f'/proc/{helper_pid}/exe')
                except FileNotFoundError:
                    continue
                if Path(image).name == 'erl_child_setup':
                    if image != '/release 日本/' + expected['helper_path'] or sha256(Path(f'/proc/{helper_pid}/exe')) != expected['helper']:
                        raise RuntimeError('Release helper escaped selected ERTS')
                    helpers.append(image)
            if len(helpers) != 1:
                raise RuntimeError('Release child helper was not observed')
            origins.append({'cycle': cycle, 'pid': pid, 'executable': executable,
                            'helpers': helpers, 'images': sorted(images)})
            if cycle < 2:
                os.write(terminal, b'init:restart().\n')
                prompt(1)
        os.write(terminal, b'q().\n')
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            ended, status = os.waitpid(child, os.WNOHANG)
            if ended:
                waited = True
                if os.waitstatus_to_exitcode(status):
                    raise RuntimeError(f'Release exit status {status}')
                log.with_suffix('.origins.json').write_text(json.dumps(origins, indent=2) + '\n')
                return
            if select.select([terminal], [], [], 0.02)[0]:
                try:
                    transcript.extend(os.read(terminal, 65536))
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
        raise RuntimeError('Release did not quit')
    finally:
        if not waited:
            try:
                os.killpg(child, signal.SIGKILL)
            except ProcessLookupError:
                pass
            os.waitpid(child, 0)
        os.close(terminal)
        log.write_bytes(transcript)


def darwin_release(args, root, prefix, project, release, work, env, expected, epmd_port, run):
    observer = root / 'host-observer'
    shutil.copy2(args.build / 'otp_test_host_observer', observer)
    expected.update(observer=observer, release=release)
    isolation = seatbelt(args, work, [prefix, project, args.sdk, args.source, args.build, args.rebar3])
    for index, absent in enumerate((prefix, project, args.sdk, args.source, args.build, args.rebar3)):
        run([*isolation, '/bin/test', '!', '-e', absent.resolve()], f'absent-{index}')
    selected = dict(env, ERL_EPMD_PORT=epmd_port, ERL_AFLAGS='-start_epmd false')
    with (root / 'epmd.log').open('w') as log:
        daemon = subprocess.Popen([str(release / 'erts-17.0/bin/epmd'), '-port', epmd_port,
                                   '-address', '127.0.0.1'], env=selected, cwd=work,
                                   stdout=log, stderr=subprocess.STDOUT, start_new_session=True, close_fds=True)
        try:
            deadline = time.monotonic() + 10
            while True:
                if daemon.poll() is not None:
                    raise RuntimeError('Private release EPMD exited')
                try:
                    with socket.create_connection(('127.0.0.1', int(epmd_port)), timeout=.2):
                        break
                except OSError:
                    if time.monotonic() >= deadline:
                        raise RuntimeError('Private release EPMD did not listen')
                    time.sleep(.02)
            console([*isolation, release / 'bin/otp_release_probe', 'console'], selected,
                    work, expected, root / 'console.log')
        finally:
            if daemon.poll() is None:
                os.killpg(daemon.pid, signal.SIGTERM)
                try:
                    daemon.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(daemon.pid, signal.SIGKILL)
                    daemon.wait()
            survivors = owned_processes(observer, release)
            if survivors:
                stop_owned_processes(observer, release)
                raise RuntimeError(f'Release left task-owned processes: {survivors}')
    (root / 'result.json').write_text(json.dumps({'status': 'passed', 'host_sha256': expected['host'],
        'helper_sha256': expected['helper'], 'rebar3_sha256': REBAR_SHA256,
        'sdk': json.loads((args.build / 'sdk-selection.json').read_text()),
        'lifetimes': 3, 'assembly_inputs_denied': True, 'owned_processes_restored': True}, indent=2) + '\n')
    print(f'Standard isolated release: three startup/native lifetimes passed; {root}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source', 'build', 'sdk', 'rebar3', 'bwrap'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--cmake', required=True)
    args = parser.parse_args()
    if not args.rebar3.is_file() or sha256(args.rebar3) != REBAR_SHA256:
        parser.error('Supply the pinned Rebar3 3.27.0 archive explicitly')
    with zipfile.ZipFile(args.rebar3) as archive:
        for app, version in (('rebar', '3.27.0'), ('relx', '4.10.0')):
            names = [n for n in archive.namelist() if n.endswith('/ebin/' + app + '.app')]
            if len(names) != 1 or f'"{version}"'.encode() not in archive.read(names[0]):
                parser.error(f'Unexpected {app} version')
    root = work_root(args.build, 'release') / str(time.time_ns())
    root.mkdir(parents=True)
    with scratch(root):
        env = {k: v for k, v in os.environ.items()
               if not k.startswith(('ERL_', 'ERLC_', 'ESCRIPT_', 'BEAM_', 'OTP_', 'LD_', 'DYLD_', 'REBAR_', 'HEX_', 'XDG_'))
               and k not in ('BINDIR', 'ROOTDIR', 'EMU', 'PROGNAME')}
        env.update(PATH='/usr/bin:/bin', LANG='C.UTF-8', TERM='xterm', REBAR_COLOR='none')
        for key in ('HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_DATA_HOME', 'REBAR_GLOBAL_CONFIG_DIR', 'REBAR_CACHE_DIR'):
            directory = root / key.lower()
            directory.mkdir()
            env[key] = str(directory)

        def run(command, name, cwd=root):
            process = subprocess.Popen(list(map(str, command)), cwd=cwd, env=env,
                                       start_new_session=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            try:
                output, _ = process.communicate(timeout=120)
            except BaseException:
                os.killpg(process.pid, signal.SIGKILL)
                output, _ = process.communicate()
                (root / (name + '.log')).write_bytes(output)
                raise
            (root / (name + '.log')).write_bytes(output)
            if process.returncode:
                raise RuntimeError(f'{name} failed ({process.returncode}); see {root}')

        prefix = root / 'original'
        run([args.cmake, '--install', args.build.resolve(), '--prefix', prefix], 'install')
        host, = prefix.glob('erts-*/bin/beam.smp')
        helper, = prefix.glob('erts-*/bin/erl_child_setup')
        expected = {'host_path': host.relative_to(prefix).as_posix(), 'host': sha256(host),
                    'helper_path': helper.relative_to(prefix).as_posix(), 'helper': sha256(helper),
                    'images': {p.relative_to(prefix).as_posix(): sha256(p) for p in prefix.rglob('*') if p.is_file()}}
        project = root / 'project'
        shutil.copytree(args.source.resolve() / 'tools/fixtures/release', project)
        run([prefix / 'bin/escript', args.rebar3.resolve(), 'tar'], 'assemble', project)
        archive, = (project / '_build/default/rel/otp_release_probe').glob('*.tar.gz')
        release = root / 'relocated release 日本 é'
        release.mkdir()
        with tarfile.open(archive) as stream:
            stream.extractall(release, filter='data')
        work = root / 'work'
        work.mkdir()
        with socket.socket() as reservation:
            reservation.bind(('127.0.0.1', 0))
            epmd_port = str(reservation.getsockname()[1])
        if sys.platform == 'darwin':
            darwin_release(args, root, prefix, project, release, work, env, expected, epmd_port, run)
            return
        command = [args.bwrap, '--unshare-user', '--unshare-pid', '--die-with-parent']
        for directory in ('/usr', '/bin', '/lib', '/lib64', '/etc'):
            if Path(directory).exists():
                command += ['--ro-bind', directory, directory]
        for directory in ('/usr/lib/erlang', '/usr/local/lib/erlang'):
            if Path(directory).exists():
                command += ['--tmpfs', directory]
        command += ['--dev', '/dev', '--proc', '/proc', '--tmpfs', '/tmp',
                    '--bind', release, '/release 日本', '--bind', work, '/work', '--chdir', '/work',
                    '--clearenv', '--setenv', 'PATH', '/usr/bin:/bin', '--setenv', 'HOME', '/work',
                    '--setenv', 'LANG', 'C.UTF-8', '--setenv', 'TERM', 'xterm',
                    '--setenv', 'ERL_EPMD_PORT', epmd_port, '--']
        for index, absent in enumerate((prefix, args.sdk.resolve(), args.source.resolve(), args.rebar3.resolve())):
            run([*command, '/usr/bin/test', '!', '-e', absent], f'absent-{index}')
        console([*command, '/release 日本/bin/otp_release_probe', 'console'], env, work, expected, root / 'console.log')
        (root / 'result.json').write_text(json.dumps({'status': 'passed', 'host_sha256': expected['host'],
            'helper_sha256': expected['helper'], 'rebar3_sha256': REBAR_SHA256, 'lifetimes': 3}, indent=2) + '\n')
        print(f'Standard isolated release: three startup/native lifetimes passed; {root}')


if __name__ == '__main__':
    main()
