#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Inventory pinned specifications and installed command inputs without running tests.

Common Test resolves specification selections. Compilation/native preparation and
observed case expansion remain explicit downstream requirements, never passes.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

from installation_inventory import UPSTREAM_COMMIT, verify_installation

REQUIRED_GATES = ['installed-sdk-boundary', 'installation-content-review',
    'installed-relocated-isolated-product', 'command-resource-coverage',
    'external-otp29-interoperability', 'release-upgrade-downgrade',
    'wx-native-restart', 'desktop-gui', 'shared-vm-integration']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_directories(source):
    return [*sorted((source / 'lib').glob('*/test')), source / 'erts/test',
            source / 'erts/emulator/test', source / 'erts/epmd/test']


def primary_owner(path):
    if path.startswith('erts/emulator/test/'):
        return 'otp' if Path(path).stem == 'dirty_nif_SUITE' else 'beam-vm'
    if path.startswith('erts/test/') and Path(path).stem in {'erl_print_SUITE', 'ethread_SUITE'}:
        return 'beam-vm'
    return 'otp'


def specification_classification(path):
    return ('dynamic-policy' if path.suffix == '.dynspec' else
            'benchmark' if '_bench.' in path.name else
            'variant' if '_smoke.' in path.name or '_gh.' in path.name else 'functional')


def resolve_specifications(source, prefix):
    fixture = Path(__file__).parent / 'fixtures/otp_spec_inventory.escript'
    with tempfile.TemporaryDirectory(prefix='otp-spec-inventory-') as temporary:
        output = Path(temporary) / 'selections.json'
        command = [str(prefix.resolve() / 'bin/escript'), str(fixture), str(source), str(output)]
        environment = {'PATH': '/usr/bin:/bin', 'HOME': temporary,
                       'ERL_FLAGS': '+S2:2 +SDcpu2:2 +SDio2'}
        result = subprocess.run(command, env=environment, cwd=temporary,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
        if result.returncode:
            raise RuntimeError('Installed specification resolver failed: ' +
                               result.stdout.decode('utf-8', errors='backslashreplace')[-8000:])
        rows = json.loads(output.read_text())['specifications']
    discovered = {str(p.relative_to(source)) for d in source_directories(source)
                  for pattern in ('*.spec', '*.dynspec') for p in d.glob(pattern)}
    if discovered != {r['path'] for r in rows} or len(rows) != len(discovered):
        raise ValueError('Common Test resolver omitted or duplicated a specification')
    return rows


def expand_selection(source, row):
    path = source / row['path']
    suites = []
    for node in row.get('nodes', []):
        for run in node['run']:
            logical = Path(run['directory'])
            directory = path.parent
            if logical.name != directory.parent.name + '_test' and not (
                row['path'].startswith('erts/') and logical.name in {'system_test', 'emulator_test', 'epmd_test'}):
                raise ValueError(f'Unresolved specification directory: {run["directory"]}')
            if run['suite'] == 'all':
                selected = sorted(directory.glob('*_SUITE.erl'))
            else:
                selected = [directory / (run['suite'].strip("'") + '.erl')]
            for selected_source in selected:
                if not selected_source.is_file():
                    raise ValueError(f'Selected suite source is missing: {selected_source}')
                relative = str(selected_source.relative_to(source))
                exclusions = [skip for skip in node['skip_selections'] if
                    skip['suite'].strip("'") == selected_source.stem and
                    skip['directory'] == run['directory'] and skip['selection'] == 'all'
                    and 'benchmark' in skip['reason'].lower()]
                suites.append({'source':relative, 'sha256':digest(selected_source),
                    'owner':primary_owner(relative), 'selection':run['selection'],
                    'applicability':'upstream-benchmark-exclusion' if exclusions else 'required',
                    'exclusion_reasons':[skip['reason'] for skip in exclusions],
                    'case_expansion':'pending-fixture-preparation'})
    return suites


def command_manuals(source):
    manuals = []
    documents = sorted(source.glob('erts/doc/references/*_cmd.md')) + sorted(
        source.glob('lib/*/doc/references/*_cmd.md'))
    for document in documents:
        section, controls = '', []
        relative = str(document.relative_to(source))
        for number, line in enumerate(document.read_text().splitlines(), 1):
            if line.startswith('## '):
                section = line[3:]
            match = re.match(r'- \*\*`([^`]+)`', line)
            if match:
                controls.append({'id':relative + ':' + str(number) + ':' + match.group(1),
                    'syntax':match.group(1), 'section':section, 'line':number,
                    'coverage':'pending-observable-behavior-check'})
        manuals.append({'source':relative, 'sha256':digest(document), 'controls':controls})
    return manuals


def inventory(source, prefix, provenance, reference_prefix, reference_provenance):
    source = source.resolve(strict=True)
    if (source / 'UPSTREAM_COMMIT').read_text().strip() != UPSTREAM_COMMIT:
        raise ValueError('Source is not the selected OTP 29.0 pin')
    candidate = verify_installation(prefix, provenance)
    reference = verify_installation(reference_prefix, reference_provenance)
    if candidate['runtime'] != 'candidate' or reference['runtime'] != 'reference':
        raise ValueError('Select a candidate interpreter and an original-build reference')
    if candidate['flavor'] != reference['flavor']:
        raise ValueError('Candidate and reference inventory flavors differ')
    fixture = Path(__file__).parent / 'fixtures/otp_spec_inventory.escript'
    rows = resolve_specifications(source,prefix)
    adaptation_path = source / 'tools/upstream-test-adaptations.json'
    adaptations = json.loads(adaptation_path.read_text())
    if adaptations.get('format') != 1 or adaptations.get('upstream_commit') != UPSTREAM_COMMIT:
        raise ValueError('Invalid upstream test-adaptation manifest')
    for path, adaptation in adaptations['adaptations'].items():
        if digest(source / path) != adaptation['sha256']:
            raise ValueError('Test-setup source differs from its declared digest: ' + path)
    suites = {str(p.relative_to(source)): p for d in source_directories(source)
              for p in d.glob('*_SUITE.erl')}
    # mnesia_SUITE delegates to retained *_test modules. They remain suite-owned
    # helpers, not independently invented qualification suites.
    for row in rows:
        path = source / row['path']
        row['sha256'] = digest(path)
        row['classification'] = specification_classification(path)
        row['suites'] = expand_selection(source,row)
    manuals = command_manuals(source)
    commands = []
    helpers = {'beam.smp', 'erl_child_setup', 'erlexec', 'inet_gethost',
               'yielding_c_fun', 'odbcserver', 'cpu_sup', 'memsup'}
    for path, entry in reference['entries'].items():
        if '/bin/' not in '/' + path or entry['kind'] == 'directory':
            continue
        if entry['kind'] == 'file' and not int(entry['mode'], 8) & 0o111:
            continue
        name = Path(path).name
        kind = 'template' if name.endswith('.src') else 'helper' if name in helpers else 'command'
        commands.append({'path': path, 'entry': entry, 'kind':kind,
                         'coverage': 'pending-command-option-inventory'})
    return {'format': 1, 'upstream_commit': UPSTREAM_COMMIT,
            'target': {'os': 'Linux', 'architecture': 'x86_64', 'flavors': ['emu', 'jit']},
            'resolver': {'fixture_sha256': digest(fixture), 'candidate': str(provenance.resolve()),
                         'candidate_sha256': digest(provenance),
                         'reference': str(reference_provenance.resolve()),
                         'reference_sha256': digest(reference_provenance)},
            'specifications': rows, 'suite_sources': {p:digest(s) for p,s in sorted(suites.items())},
            'commands': commands, 'command_manuals':manuals,
            'test_adaptations':adaptations, 'test_adaptations_sha256':digest(adaptation_path),
            'required_gates': REQUIRED_GATES,
            'limitations': [], 'qualified': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source', 'prefix', 'provenance', 'reference-prefix', 'reference-provenance', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    for selected in (args.prefix, args.reference_prefix, args.source):
        if args.output.resolve().is_relative_to(selected.resolve()):
            # Durable inventory belongs in source only when explicitly copied
            # after inspection; execution never mutates selected inputs.
            parser.error('Inventory output must be outside selected source/installations')
    record = inventory(args.source, args.prefix, args.provenance,
                       args.reference_prefix, args.reference_provenance)
    args.output.write_text(json.dumps(record, indent=2, sort_keys=True) + '\n')
    print(f'{len(record["specifications"])} specifications; {len(record["suite_sources"])} '
          f'top-level suite sources; {len(record["commands"])} command/helper entries; unqualified')


if __name__ == '__main__':
    main()
