#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise resident regex upgrades with acknowledged native lifetime checkpoints."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import time

from check_compatibility import execute
from host_testing import work_root
from scratch import scratch


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('build', 'source', 'sdk'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--cmake', required=True)
    args = parser.parse_args()
    root = work_root(args.build, 'regex') / str(time.time_ns())
    root.mkdir(parents=True)
    with scratch(root):
        prefix = root / 'otp'
        fixtures = root / 'fixtures'
        fixtures.mkdir()
        bad = root / 'invalid'
        bad.mkdir()
        env = {k: v for k, v in os.environ.items()
               if not k.startswith(('ERL_', 'BEAM_', 'OTP_', 'LD_', 'DYLD_'))}
        env.update(HOME=str(root), LANG='C.UTF-8', LC_ALL='C.UTF-8', ERL_CRASH_DUMP_SECONDS='0')
        execute([args.cmake, '--install', args.build, '--prefix', prefix], root,
                env, root / 'install.log', timeout=120)
        inputs = args.source / 'tools/fixtures'
        execute([prefix / 'bin/erlc', '+debug_info', '-o', fixtures,
                 inputs / 'otp_re_test.erl', inputs / 'otp_re_upgrade.erl',
                 inputs / 're-coexist/otp_re_coexist.erl'],
                root, env, root / 'compile.log', timeout=60)
        coexist = root / 'coexist'
        execute([args.cmake, '-S', inputs / 're-coexist', '-B', coexist,
                 '-DCMAKE_BUILD_TYPE=Release', '-DBEAM_DIR=' + str(args.sdk / 'lib/cmake/BEAM')],
                root, env, root / 'coexist-configure.log', timeout=60)
        execute([args.cmake, '--build', coexist], root, env, root / 'coexist-build.log', timeout=60)
        expression = ('ok=otp_re_coexist:load(' + json.dumps(str(coexist / 'otp_re_coexist')) + '),'
                      'stock_ok=otp_re_coexist:stock(),false=erlang:is_builtin(re,run,3),'
                      '{ok,P}=re:compile(<<"(?<x>a)">>),{re,B,F}=code:get_object_code(re),'
                      'true=code:unstick_mod(re),{module,re}=code:load_binary(re,F,B),'
                      '{match,[<<"a">>]}=re:run(<<"a">>,P,[{capture,[x],binary}]),'
                      'true=code:soft_purge(re),stock_ok=otp_re_coexist:stock(),'
                      'io:put_chars("OTP_REGEX_PRODUCTION_OK\\n"),halt().')
        stdout, _ = execute([prefix / 'bin/erl', '+S1', '+SDcpu1', '+SDio1', '-noshell', '-noinput',
                             '-pa', fixtures, '-eval', expression], root, env,
                            root / 'production.log', timeout=30)
        if stdout != 'OTP_REGEX_PRODUCTION_OK\n':
            raise RuntimeError('Production regex/coexistence check failed: ' + stdout)
        execute([prefix / 'bin/erlc', '-o', bad, inputs / 're-invalid-load/re.erl'],
                root, env, root / 'compile-invalid.log', timeout=60)
        execute([args.cmake, '--build', args.build, '--target', 'otp_re_instrumented_host', '-j2'],
                root, env, root / 'build-host.log', timeout=300)
        host = next(prefix.glob('erts-*/bin/beam.smp'))
        production = digest(host)
        shutil.copyfile(args.build / 'otp_re_instrumented_host', host)
        expression = ('{ok,Bad}=file:read_file(' + json.dumps(str(bad / 're.beam')) + '),'
                      'ok=otp_re_upgrade:run(Bad),io:put_chars("OTP_REGEX_UPGRADE_OK\\n"),halt().')
        stdout, _ = execute([prefix / 'bin/erl', '+S2', '+SDcpu2', '+SDio1', '-noshell', '-noinput',
                             '-pa', fixtures, '-eval', expression], root, env,
                            root / 'upgrade.log', timeout=60)
        if stdout.splitlines().count('OTP_REGEX_UPGRADE_OK') != 1:
            raise RuntimeError('Missing regex upgrade completion')
        (root / 'results.json').write_text(json.dumps({
            'sdk': json.loads((args.build / 'sdk-selection.json').read_text()),
            'production_host_sha256': production, 'instrumented_host_sha256': digest(host),
            'native_source_sha256': digest(args.source / 'lib/stdlib/c_src/re/re_nif.c'),
            'checks': ['production upgrade and host-PCRE coexistence', 'retained-pattern upgrade', 'staged rollback', 'invalid load information',
                       'acknowledged suspended match', 'active dirty compilation',
                       'caller death during dirty compilation', 'eventual resource reclamation']}, indent=2) + '\n')
        print('OTP resident regex upgrade and lifetime checks passed')


if __name__ == '__main__':
    main()
