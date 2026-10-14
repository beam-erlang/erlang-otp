#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare an independently installed product with its complete upstream reference."""
import argparse
import json
import os
from pathlib import Path
from scratch import scratch
import signal
import shutil
import subprocess
import time
from installation_inventory import UPSTREAM_COMMIT, compare, inventory, read_record


def install(cmake, build, prefix, work, label, environment=None):
    process = subprocess.Popen([cmake, '--install', str(build), '--prefix', str(prefix)],
                               env=environment, start_new_session=True,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        output, _ = process.communicate(timeout=120)
    except BaseException:
        os.killpg(process.pid, signal.SIGKILL)
        output, _ = process.communicate()
        (work / (label + '.log')).write_bytes(output)
        raise
    (work / (label + '.log')).write_bytes(output)
    if process.returncode:
        raise RuntimeError(f'{label}: installation failed; see {work}')


def inspection_lifetimes(prefix, work, label):
    environment = {k: v for k, v in os.environ.items()
                   if not k.startswith(('ERL_', 'ERLC_', 'ESCRIPT_', 'BEAM_', 'OTP_', 'LD_'))
                   and k not in ('ROOTDIR', 'BINDIR', 'EMU', 'PROGNAME')}
    expression = ('P=lists:sort(erlang:pre_loaded()),22=length(P),'
                  'lists:foreach(fun(M)->preloaded=code:which(M),true=code:is_sticky(M) end,P),'
                  '"inspection-ok"=os:cmd("printf inspection-ok"),'
                  'F=[{K,erlang:system_info(K)} || K <- '
                  '[otp_release,emu_flavor,wordsize,smp_support,threads,dynamic_trace]],'
                  'D=lists:sort(element(2,erl_ddll:loaded_drivers())),'
                  'C=lists:sort([{K,lists:sort(V)} || {K,V} <- crypto:supports()]),'
                  'S=lists:sort([{K,case V of L when is_list(L)->lists:sort(L);_->V end} '
                  '|| {K,V} <- socket:supports()]),'
                  'io:format("~tp~n",[{P,F,D,C,S}]),halt().')
    outputs = []
    inspection, = prefix.glob('lib/erts-*/ebin')
    modules = sorted(inspection.glob('*.beam'))
    if len(modules) != 22:
        raise RuntimeError('Unexpected ERTS inspection module inventory')
    holding = work / ('hidden-' + label)
    holding.mkdir()
    for phase in ('present', 'absent', 'recovered'):
        if phase == 'absent':
            for module in modules:
                module.rename(holding / module.name)
        elif phase == 'recovered':
            for module in modules:
                (holding / module.name).rename(module)
        process = subprocess.Popen([str(prefix / 'bin/erl'), '+S1', '-noshell', '-eval', expression],
            cwd=work, env=environment, start_new_session=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            stdout, stderr = process.communicate(timeout=30)
        except BaseException:
            os.killpg(process.pid, signal.SIGKILL)
            stdout, stderr = process.communicate()
            (work / f'{label}-{phase}.log').write_bytes(stdout + b'\nSTDERR\n' + stderr)
            raise
        (work / f'{label}-{phase}.log').write_bytes(stdout + b'\nSTDERR\n' + stderr)
        if process.returncode or stderr:
            raise RuntimeError(f'{label}/{phase}: inspection-file startup failed')
        outputs.append(stdout)
    if len(set(outputs)) != 1:
        raise RuntimeError('Inspection files changed preload behavior')
    return outputs[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('build', 'reference-prefix', 'reference-provenance'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--cmake', required=True)
    args = parser.parse_args()
    reference = read_record(args.reference_provenance)
    if inventory(args.reference_prefix.resolve(strict=True)) != reference['entries']:
        raise RuntimeError('Selected original-build reference differs from its provenance')
    build = args.build.resolve()
    selection = json.loads((build / 'sdk-selection.json').read_text())
    if reference['flavor'] != selection['flavor']:
        raise RuntimeError('Reference flavor differs from the selected SDK')
    work = build / 'checks/installed-tree' / str(time.time_ns())
    work.mkdir(parents=True)
    with scratch(work):
        prefix = work / 'installed'
        install(args.cmake, build, prefix, work, 'install')
        candidate = {'format': 1, 'runtime': 'candidate', 'flavor': selection['flavor'],
                     'upstream_commit': UPSTREAM_COMMIT, 'prefix': str(prefix),
                     'build': {'linkage': 'static', 'sdk_selection': selection}, 'entries': inventory(prefix)}
        differences = compare(candidate, reference)
        (work / 'candidate.json').write_text(json.dumps(candidate, indent=2) + '\n')
        result = {'candidate_entries': len(candidate['entries']), 'reference_entries': len(reference['entries']),
                  'differences': differences, 'tree_status': 'failed' if differences else 'passed',
                  'status': 'failed' if differences else 'incomplete'}
        (work / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        if differences:
            raise RuntimeError(f'{len(differences)} installed-tree differences; see {work}')
        reference_copy = work / 'reference-copy'
        shutil.copytree(args.reference_prefix, reference_copy, symlinks=True)
        try:
            logical = '/otp-tree-' + str(time.time_ns())
            destination = work / 'destdir'
            staged = destination / logical.lstrip('/')
            install(args.cmake, build, logical, work, 'destdir-install',
                    dict(os.environ, DESTDIR=str(destination)))
            staged_candidate = dict(candidate, prefix=str(staged), entries=inventory(staged))
            staged_differences = compare(staged_candidate, reference)
            result['destdir'] = {'logical_prefix': logical, 'entries':len(staged_candidate['entries']),
                                 'differences':staged_differences, 'status':'incomplete'}
            if staged_differences:
                raise RuntimeError('DESTDIR installation differs from the original tree')
            adjusted = []
            for name, entry in candidate['entries'].items():
                if entry['kind'] != 'file':
                    continue
                before, after = (prefix / name).read_bytes(), (staged / name).read_bytes()
                if str(destination).encode() in after:
                    raise RuntimeError('Physical DESTDIR leaked into installed content: ' + name)
                if before != after:
                    if b'\0' in before or b'\0' in after:
                        raise RuntimeError('DESTDIR changed binary content: ' + name)
                    normalized = [data.decode('utf-8').replace(root, '${INSTALL_PREFIX}')
                                  for data, root in ((before,str(prefix)),(after,logical))]
                    if normalized[0] != normalized[1]:
                        raise RuntimeError('DESTDIR changed content beyond its logical prefix: ' + name)
                    adjusted.append(name)
            result['destdir'].update(status='passed', prefix_adjusted_files=adjusted)
            relocated = work / 'staged-relocated'
            staged.rename(relocated)
            observed = inspection_lifetimes(prefix, work, 'candidate')
            expected = inspection_lifetimes(reference_copy, work, 'reference')
            staged_observed = inspection_lifetimes(relocated, work, 'staged')
            if observed != expected or staged_observed != expected:
                raise RuntimeError('Candidate preload behavior or native capabilities differ from upstream')
            result['status'] = 'passed'
            result['inspection_lifetimes'] = {'candidate': 3, 'reference': 3, 'staged':3, 'status': 'passed'}
            result['native_capability_comparison'] = 'passed'
            (work / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        except Exception as error:
            result.update(status='failed', error=str(error))
            (work / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
            raise
        else:
            shutil.rmtree(reference_copy)
        print(f'Exact installed tree: {len(candidate["entries"])} entries; {work}')


if __name__ == '__main__':
    main()
