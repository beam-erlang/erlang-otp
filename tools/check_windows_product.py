#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Practical installed Windows commands, services, TLS and native extension smoke."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def run(command, *, cwd, env, input=None, timeout=120):
    command = list(map(str, command))
    child = subprocess.Popen(command, cwd=cwd, env=env, stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             creationflags=subprocess.CREATE_NO_WINDOW)
    try:
        out, err = child.communicate(input, timeout=timeout)
    except BaseException:
        # Terminate only this owned command tree if it cannot finish.
        if child.poll() is None:
            subprocess.run([str(Path(os.environ['SystemRoot'])/'System32/taskkill.exe'),
                            '/PID', str(child.pid), '/T', '/F'], capture_output=True, timeout=10)
        child.communicate(timeout=10)
        raise
    if child.returncode:
        raise AssertionError(f'{command!r}: status={child.returncode}\n'
                             f'{out.decode("utf-8",errors="replace")}\n{err.decode("utf-8",errors="replace")}')
    return out.decode('utf-8', errors='replace').replace('\r\n', '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--cmake', type=Path, required=True)
    parser.add_argument('--openssl', type=Path, required=True)
    parser.add_argument('--flavor', choices=('emu','jit'), required=True)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--ninja', type=Path, required=True)
    args = parser.parse_args()
    work = args.work.resolve()
    work.mkdir(parents=True, exist_ok=True)
    # A failed run must not leave a previous success receipt looking current.
    (work/'results.json').unlink(missing_ok=True)
    with tempfile.TemporaryDirectory(prefix='native-', dir=work) as temporary:
        root = Path(temporary)
        prefix = root/'installed OTP λ'
        cwd = root/'unrelated 日本語'
        cwd.mkdir()
        fixtures = Path(__file__).parent/'fixtures/windows'
        compatibility = Path(__file__).parent/'fixtures/compatibility'
        build_env = os.environ.copy()
        for key in list(build_env):
            if key.startswith(('ERL_', 'BEAM_', 'OPENSSL_', 'LD_', 'DYLD_')):
                del build_env[key]
        build_env['PYTHONUTF8'] = '1'
        openssl_version = run([args.openssl, 'version'], cwd=cwd, env=build_env).split()[1]
        run([args.cmake, '--install', args.build_dir, '--prefix', prefix], cwd=cwd, env=build_env)
        conf = root/'openssl.cnf'
        conf.write_text('[req]\ndistinguished_name=dn\n[dn]\n', encoding='utf-8')
        ca, ca_key = root/'ca.pem', root/'ca-key.pem'
        cert, key, request = root/'cert.pem', root/'key.pem', root/'server.csr'
        run([args.openssl,'req','-x509','-newkey','rsa:2048','-noenc','-days','2',
             '-config',conf,'-subj','/CN=OTP development CA',
             '-addext','basicConstraints=critical,CA:TRUE',
             '-addext','keyUsage=critical,keyCertSign,cRLSign',
             '-keyout',ca_key,'-out',ca], cwd=cwd, env=build_env)
        run([args.openssl,'req','-new','-newkey','rsa:2048','-noenc',
             '-config',conf,'-subj','/CN=localhost','-keyout',key,'-out',request],
            cwd=cwd, env=build_env)
        extensions = root/'server.ext'
        extensions.write_text('subjectAltName=DNS:localhost\nbasicConstraints=critical,CA:FALSE\n'
                              'keyUsage=critical,digitalSignature,keyEncipherment\n'
                              'extendedKeyUsage=serverAuth\n', encoding='utf-8')
        run([args.openssl,'x509','-req','-in',request,'-CA',ca,'-CAkey',ca_key,
             '-CAcreateserial','-days','2','-extfile',extensions,'-out',cert],
            cwd=cwd, env=build_env)
        native = root/'native consumer'
        run([args.cmake,'-S',fixtures/'nif','-B',native,'-G','Ninja',
             '-DCMAKE_BUILD_TYPE=Release',f'-DOTP_PREFIX={prefix.as_posix()}',
             f'-DCMAKE_C_COMPILER={args.compiler.as_posix()}',
             f'-DCMAKE_MAKE_PROGRAM={args.ninja.as_posix()}'], cwd=cwd, env=build_env)
        run([args.cmake,'--build',native], cwd=cwd, env=build_env)
        ebin = root/'ebin'
        ebin.mkdir()
        sources = list(fixtures.glob('*.erl'))
        sources += [compatibility/(name+'.erl') for name in
                    ('otp_counter','otp_counter_app','otp_counter_sup','otp_supervision','otp_fixture')]
        run([prefix/'bin/erlc.exe','+deterministic','-o',ebin,*sources], cwd=cwd, env=build_env)
        shutil.copy2(compatibility/'otp_counter.app', ebin)
        # Escript's generated module name uses its basename and must be Latin-1.
        script = cwd/'hello.escript'
        script.write_text('#!/usr/bin/env escript\n%% -*- erlang -*-\n'
                          'main([]) -> io:format("ESCRIPT_OK~n").\n', encoding='utf-8')
        records = []
        for phase in ('fresh','relocated'):
            if phase == 'relocated':
                moved = root/'relocated OTP 日本語'
                prefix.rename(moved)
                prefix = moved
            env = build_env.copy()
            env['PATH'] = os.pathsep.join([str(prefix/'bin'), str(Path(os.environ['SystemRoot'])/'System32'),
                                          os.environ['SystemRoot']])
            env.update(OTP_EXPECT_PREFIX=prefix.as_posix(), OTP_EXPECT_FLAVOR=args.flavor,
                       OTP_TEST_OPENSSL_VERSION=openssl_version,
                       OTP_TEST_NIF=(native/'otp_windows_nif').as_posix(), OTP_TEST_PYTHON=sys.executable,
                       OTP_TEST_CERT=cert.as_posix(), OTP_TEST_KEY=key.as_posix(),
                       OTP_TEST_CA=ca.as_posix())
            erl = prefix/'bin/erl.exe'
            base = [erl,'+S','2:2','+SDcpu','2:2']
            out = run(base+['-noshell','-noinput','-pa',ebin,'-s','otp_windows_smoke','run',
                            '-extra','two words','','"','λ'], cwd=cwd, env=env)
            assert f'WINDOWS_OTP_SMOKE_OK {args.flavor}' in out, out
            assert run([prefix/'bin/escript.exe',script],cwd=cwd,env=env) == 'ESCRIPT_OK\n'
            shell = run(base,cwd=cwd,env=env,input=b'A = 41.\nA+1.\nq().\n',timeout=30)
            assert '42' in shell, shell
            records.append({'phase':phase,'flavor':args.flavor,'status':'passed'})
        (work/'results.json').write_text(json.dumps(records,indent=2)+'\n',encoding='utf-8')
        print(f'Installed Windows OTP {args.flavor}: commands, shell, supervision, files, both TCP backends, TLS, registry, child and NIF passed fresh/relocated.')


if __name__ == '__main__':
    main()
