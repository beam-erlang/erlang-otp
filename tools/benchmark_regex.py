#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare preserved BIF OTP and final resident-NIF OTP with distinct provenance."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import statistics
import shutil
import signal
import subprocess
import tempfile
import tomllib

from check_compatibility import execute

CASES = {'compile': 200, 'compiled': 5000, 'implicit': 500, 'large': 10,
         'unicode': 10, 'backtrack': 30, 'global': 20, 'captures': 100,
         'filelib': 20, 'shell_docs': 100, 'release': 20, 'common_test': 100,
         'xmerl_xsd': 100}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source', 'baseline-otp', 'baseline-sdk', 'candidate-otp',
                 'candidate-build', 'candidate-sdk', 'work'):
        parser.add_argument('--' + name, type=Path, required=True)
    for name in ('baseline-source-id', 'candidate-source-id'):
        parser.add_argument('--' + name, required=True)
    parser.add_argument('--samples', type=int, default=5)
    parser.add_argument('--warmups', type=int, default=2)
    parser.add_argument('--cases', nargs='+', choices=CASES, default=list(CASES))
    parser.add_argument('--cmake', default='/usr/bin/cmake')
    args = parser.parse_args()
    for name in ('source', 'baseline_otp', 'baseline_sdk', 'candidate_otp',
                 'candidate_build', 'candidate_sdk', 'work'):
        setattr(args, name, getattr(args, name).resolve())
    def interrupted(signum, frame):
        raise SystemExit(128 + signum)
    signal.signal(signal.SIGTERM, interrupted)
    if not 1 <= args.samples <= 30 or not 0 <= args.warmups <= 20:
        parser.error('samples must be 1..30 and warmups 0..20')
    args.work = args.work.resolve()
    args.work.mkdir(parents=True, exist_ok=True)
    for path in (args.baseline_otp, args.baseline_sdk, args.candidate_otp, args.candidate_sdk):
        if args.work.is_relative_to(path.resolve()):
            parser.error('work must be outside immutable installations')
    sdks = {key: tomllib.loads((path / 'lib/beam/sdk.toml').read_text())
            for key, path in [('baseline', args.baseline_sdk), ('candidate', args.candidate_sdk)]}
    targets = {key: tomllib.loads((path / 'lib/beam/target.toml').read_text())
               for key, path in [('baseline', args.baseline_sdk), ('candidate', args.candidate_sdk)]}
    for key in ('system', 'architecture', 'flavor', 'compiler-environment', 'native-compiler-version', 'libc'):
        if targets['baseline'].get(key) != targets['candidate'].get(key):
            raise RuntimeError('Incomparable target/compiler: ' + key)
    result = {'completed': False, 'sdks': sdks, 'targets': targets,
              'runtime_sources': {'baseline': args.baseline_source_id, 'candidate': args.candidate_source_id},
              'source_equivalence': 'distinct sources; physical VM backend removal',
              'native_sha256': digest(args.source / 'lib/stdlib/c_src/re/re_nif.c'),
              'fixture_sha256': digest(args.source / 'tools/fixtures/otp_re_bench.erl'),
              'samples': args.samples, 'warmups': args.warmups, 'cases': {},
              'method': {'schedulers': [1, 1, 1], 'clocks': 'process CPU and monotonic wall nanoseconds',
                         'order': 'alternating baseline/candidate per sample',
                         'candidate': 'same-source memory-instrumented host; DEBUG/yield coverage disabled',
                         'memory': 'backend requested allocation volume and post-GC retained counters; excludes VM/Erlang storage, NIF resource payloads and environments',
                         'baseline_memory': 'unavailable, not zero', 'threshold': None}}
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(('ERL_', 'BEAM_', 'OTP_', 'LD_', 'DYLD_'))}
    env.update(HOME=str(args.work), LANG='C.UTF-8', LC_ALL='C.UTF-8', ERL_CRASH_DUMP_SECONDS='0')
    try:
        with tempfile.TemporaryDirectory(prefix='run-', dir=args.work) as temporary:
            root = Path(temporary)
            fixtures = root / 'fixtures'
            fixtures.mkdir()
            files = root / 'files'
            files.mkdir()
            for number in range(32):
                (files / f'sample{number}.txt').write_text('regex\n')
            execute([args.candidate_otp / 'bin/erlc', '-o', fixtures,
                     args.source / 'tools/fixtures/otp_re_bench.erl',
                     args.source / 'tools/fixtures/otp_re_test.erl'], root, env,
                    args.work / 'compile.log', timeout=90)
            helper = root / 'clock'
            helper.mkdir()
            (helper / 'CMakeLists.txt').write_text('''cmake_minimum_required(VERSION 3.25)
project(otp_regex_clock C)
find_package(BEAM CONFIG REQUIRED COMPONENTS NIF)
add_library(otp_re_clock MODULE "${CONTROL_SOURCE}")
target_compile_features(otp_re_clock PRIVATE c_std_11)
target_compile_definitions(otp_re_clock PRIVATE OTP_RE_CLOCK_ONLY _POSIX_C_SOURCE=200809L)
beam_target_nif(otp_re_clock MODULE otp_re_test)
set_target_properties(otp_re_clock PROPERTIES PREFIX "" OUTPUT_NAME otp_re_test)
''')
            execute([args.cmake, '-S', helper, '-B', helper / 'build',
                     '-DCMAKE_BUILD_TYPE=Release', '-DBEAM_DIR=' + str(args.baseline_sdk / 'lib/cmake/BEAM'),
                     '-DCONTROL_SOURCE=' + str(args.source / 'tools/fixtures/re_test_control.c')],
                    root, env, args.work / 'clock-configure.log', timeout=60)
            execute([args.cmake, '--build', helper / 'build'], root, env,
                    args.work / 'clock-build.log', timeout=60)
            execute([args.cmake, '--build', args.candidate_build, '--target', 'otp_re_measured_host', '-j2'],
                    root, env, args.work / 'candidate-host.log', timeout=300)
            candidate = root / 'candidate'
            shutil.copytree(args.candidate_otp, candidate, symlinks=True)
            host = next(candidate.glob('erts-*/bin/beam.smp'))
            shutil.copyfile(args.candidate_build / 'otp_re_measured_host', host)
            result['host_sha256'] = {'baseline': digest(next(args.baseline_otp.glob('erts-*/bin/beam.smp'))),
                                     'candidate': digest(host)}
            controls = {'baseline': str(helper / 'build/otp_re_test'), 'candidate': 'otp_re_test'}
            for case in args.cases:
                pairs = {key: [] for key in ('baseline', 'candidate')}
                for sample in range(args.samples):
                    for kind in (('baseline', 'candidate') if sample % 2 == 0 else ('candidate', 'baseline')):
                        builtin = kind == 'baseline'
                        prefix = args.baseline_otp if builtin else candidate
                        memory = 'null' if builtin else 'otp_re_test:stats()'
                        expression = (
                            f'ok=otp_re_test:load({json.dumps(controls[kind])}),'
                            f'ok=otp_re_bench:verify({str(builtin).lower()}),'
                            f'Base={memory},ok=otp_re_bench:prepare({case},{CASES[case]}),'
                            f'lists:foreach(fun(_)->ok=otp_re_bench:sample(),ok=otp_re_bench:contended() end,lists:seq(1,{args.warmups})),'
                            f'ok=otp_re_bench:collect(),Before={memory},'
                            '{C0,W0}=otp_re_test:clocks(),ok=otp_re_bench:sample(),{C1,W1}=otp_re_test:clocks(),'
                            f'ok=otp_re_bench:collect(),After={memory},'
                            '{C2,W2}=otp_re_test:clocks(),ok=otp_re_bench:contended(),{C3,W3}=otp_re_test:clocks(),'
                            'Latency=json:decode(otp_re_bench:latency_json()),ok=otp_re_bench:finish(),'
                            f'Final={memory},'
                            'io:put_chars(["REGEX_MEASUREMENT ",json:encode(#{cpu_ns=>C1-C0,wall_ns=>W1-W0,'
                            'contended_cpu_ns=>C3-C2,contended_wall_ns=>W3-W2,latency=>Latency,'
                            'base=>Base,before=>Before,after_gc=>After,final=>Final}),"\n"]),halt().')
                        out, _ = execute([prefix / 'bin/erl', '+S1', '+SDcpu1', '+SDio1', '-noshell', '-noinput',
                                          '-pa', fixtures, '-eval', expression], root, env,
                                         args.work / 'last-sample.log', timeout=120)
                        lines = [line.removeprefix('REGEX_MEASUREMENT ') for line in out.splitlines()
                                 if line.startswith('REGEX_MEASUREMENT ')]
                        if len(lines) != 1:
                            raise RuntimeError('Missing measurement: ' + out)
                        pairs[kind].append(json.loads(lines[0]))
                cpu = {key: statistics.median(row['cpu_ns'] for row in values) for key, values in pairs.items()}
                result['cases'][case] = {'iterations': CASES[case], 'raw': pairs,
                                         'cpu_ratio': cpu['candidate'] / cpu['baseline']}
                (args.work / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
                print(f'{case}: candidate/baseline CPU {result["cases"][case]["cpu_ratio"]:.3f}', flush=True)
            result['completed'] = True
    finally:
        (args.work / 'results.json').write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    main()
