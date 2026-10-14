#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Reconcile explicitly selected local evidence without changing raw test outcomes.

Unresolved commands, required behavior gates and unexecuted suites fail closed.
Publication eligibility is deliberately outside this local report.
"""
import argparse
import hashlib
import json
from pathlib import Path

from installation_inventory import UPSTREAM_COMMIT, read_record, verify_installation
from compatibility_inventory import (REQUIRED_GATES, command_manuals, expand_selection, primary_owner,
    resolve_specifications, source_directories, specification_classification)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def matches_product(result, candidate):
    installation = result.get('installation') or {}
    if installation.get('runtime') != 'candidate':
        return False
    expected = candidate['build'].get('sdk_selection', {})
    actual = result.get('sdk') or {}
    if not all(isinstance(expected.get(key), str) and expected[key]
               for key in ('version', 'build_id', 'flavor')):
        return False
    if any(actual.get(key) != expected.get(key) for key in ('version', 'build_id', 'flavor')):
        return False
    if actual.get('artifacts') != expected.get('artifacts'):
        return False
    # A VM image can remain unchanged while application bytecode, resources or
    # native libraries change. Bind the complete attested installation.
    expected_provenance = candidate.get('provenance_sha256')
    return bool(expected_provenance) and installation.get('provenance_sha256') == expected_provenance


def complete_selection(result, source, expected_hash):
    if result.get('suite') != Path(source).stem:
        return False
    hashes = result.get('source_sha256', {})
    # The BEAM VM runner records its source-relative emulator path, while this
    # inventory retains the pinned upstream path. Bind the source by digest.
    if expected_hash not in hashes.values():
        return False
    if result.get('instrumented') or result.get('case_selection', 'complete suite') != 'complete suite':
        return False
    cases = result.get('cases', [])
    if not cases or any(case.get('status') != 'passed' for case in result.get('configurations', [])):
        return False
    declaration = result.get('declared_selection') or {}
    if declaration.get('status') == 'resolved':
        # Group/repetition policies need their own execution-context comparison.
        # Do not flatten them into an apparently complete flat suite.
        if any(case.get('groups') for case in declaration['cases']):
            return False
        expected = [(case['suite'], case['name']) for case in declaration['cases']]
        actual = [(case.get('suite'), case['name']) for case in cases]
        return result.get('case_evidence_complete') is True and actual == expected
    if 'expected_case_names' in result:
        return result['expected_case_names'] == [case['name'] for case in cases]
    return False


def complete_suite(result, source, expected_hash):
    return result.get('complete') is True and complete_selection(result, source, expected_hash) and all(
        case.get('status') == 'passed' for case in result['cases'])


def case_identity(case):
    return {key:case.get(key) for key in ('suite', 'name', 'context', 'occurrence')}


def approved_skip(case, source, expected_hash, flavor, policies, results, references):
    """Return one exact limitation ID only with original and supplemental proof."""
    if case.get('status') not in ('user_skipped', 'auto_skipped'):
        return None
    for policy in policies:
        if (policy['flavor'], policy['suite_source'], policy['source_sha256'],
            policy['case_identity'], policy['status'], policy['reason']) != (
                flavor, source, expected_hash, case_identity(case), case['status'], case['reason']):
            continue
        reference = references.get(flavor)
        if not reference or policy['reference_provenance_sha256'] != reference.get('provenance_sha256'):
            continue
        original = results.get(policy['reference_result_sha256'])
        if not original or not complete_selection(original, source, expected_hash):
            continue
        if any(other.get('status') == 'failed' for other in original['cases']):
            continue
        installation = original.get('installation') or {}
        if (installation.get('runtime'), installation.get('flavor'), installation.get('provenance_sha256')) != (
                'reference', flavor, reference['provenance_sha256']):
            continue
        if not any(case_identity(other) == case_identity(case) and
                   (other['status'], other['reason']) == (case['status'], case['reason'])
                   for other in original['cases']):
            continue
        supplements = [results.get(value) for value in policy['supplemental_results']]
        if supplements and all(item and item.get('complete') is True and
                not item.get('instrumented') and all(case.get('status') == 'passed'
                    for case in item.get('cases',[])) and
                item.get('gate') == 'limitation:' + policy['id'] and item.get('_selected_candidate')
                for item in supplements):
            return policy['id']
    return None


def validate_limitations(policies):
    identities = set()
    for policy in policies:
        keys = ('id', 'flavor', 'suite_source', 'source_sha256', 'case_identity', 'status',
                'reason', 'reference_result_sha256', 'reference_provenance_sha256',
                'supplemental_results', 'rationale')
        if not all(policy.get(key) for key in keys):
            raise ValueError('Named limitation lacks exact case, original or supplemental evidence')
        if policy['status'] not in ('user_skipped', 'auto_skipped') or policy['flavor'] not in ('emu', 'jit'):
            raise ValueError('A named limitation must preserve a raw skip on a selected flavor')
        if policy['id'] in identities:
            raise ValueError('Duplicate named limitation ID')
        identities.add(policy['id'])


def reconcile(inventory, candidates, results, references=None):
    if inventory.get('format') != 1 or inventory.get('upstream_commit') != UPSTREAM_COMMIT:
        raise ValueError('Unsupported inventory or upstream pin')
    policies = inventory.get('limitations', [])
    validate_limitations(policies)
    references = references or {}
    if sorted(inventory['target']['flavors']) != ['emu', 'jit']:
        raise ValueError('Local qualification requires both EMU and JIT')
    required = {}
    for specification in inventory['specifications']:
        if specification['classification'] == 'benchmark':
            continue
        for suite in specification['suites']:
            if suite.get('applicability') == 'upstream-benchmark-exclusion':
                continue
            previous = required.setdefault(suite['source'], suite)
            if previous['sha256'] != suite['sha256'] or previous['owner'] != suite['owner']:
                raise ValueError('Conflicting specification source identity or owner')
    report = {'format':1, 'upstream_commit':UPSTREAM_COMMIT, 'qualified':False,
              'flavors':{}, 'blocked_specifications':[row['path'] for row in inventory['specifications']
                                                     if row['status'] != 'resolved']}
    controls = [(manual,control) for manual in inventory.get('command_manuals', []) for control in manual['controls']]
    report['pending_command_controls'] = report['pending_command_entries'] = 0
    used_limitations = set()
    for flavor in inventory['target']['flavors']:
        candidate = candidates.get(flavor)
        selected = [result for result in results if candidate and matches_product(result, candidate)]
        indexed = {result['_evidence_sha256']:dict(result, _selected_candidate=result in selected)
                   for result in results if result.get('_evidence_sha256')}
        coverage, details = {}, {}
        for name, suite in required.items():
            runs = [result for result in selected if result.get('suite') == Path(name).stem and
                    result.get('case_selection', 'complete suite') == 'complete suite']
            accepted, raw, invalid = set(), True, not bool(runs)
            for result in runs:
                raw = raw and complete_suite(result, name, suite['sha256'])
                if not complete_selection(result, name, suite['sha256']):
                    invalid = True
                    continue
                for case in result['cases']:
                    if case.get('status') == 'passed':
                        continue
                    limitation = approved_skip(case, name, suite['sha256'], flavor,
                                               policies, indexed, references)
                    if limitation:
                        accepted.add(limitation)
                    else:
                        invalid = True
                if result.get('complete') is not True and all(
                        case.get('status') == 'passed' for case in result['cases']):
                    # A false raw outcome without an evidenced skip has another
                    # unresolved cause; local reconciliation cannot erase it.
                    invalid = True
            coverage[name] = 'uncovered' if invalid else 'covered with limitations' if accepted else 'covered'
            used_limitations.update(accepted)
            details[name] = {'raw_complete':bool(runs) and raw, 'limitations':sorted(accepted),
                             'selected_runs':len(runs)}
        gates = {gate:any(result.get('gate') == gate and result.get('complete') is True
                         and not result.get('instrumented')
                         for result in selected) for gate in inventory['required_gates']}
        pending_controls = [control['id'] for manual,control in controls if not any(
            result.get('complete') is True and not result.get('instrumented') and
            result.get('source_sha256',{}).get(manual['source']) == manual['sha256'] and
            control['id'] in result.get('command_controls',[]) for result in selected)]
        pending_commands = [command['path'] for command in inventory['commands'] if not any(
            result.get('complete') is True and not result.get('instrumented') and
            command['path'] in result.get('command_entries',[]) for result in selected)]
        report['pending_command_controls'] += len(pending_controls)
        report['pending_command_entries'] += len(pending_commands)
        report['flavors'][flavor] = {'selected_product':bool(candidate), 'suites':coverage,
            'suite_evidence':details,
            'pending_command_controls':pending_controls, 'pending_command_entries':pending_commands,
            'missing_gates':[gate for gate,complete in gates.items() if not complete],
            'covered_suites':sum(status != 'uncovered' for status in coverage.values()),
            'uncovered_suites':sum(status == 'uncovered' for status in coverage.values())}
    report['unmatched_limitations'] = sorted(policy['id'] for policy in policies if policy['id'] not in used_limitations)
    report['qualified'] = not (report['blocked_specifications'] or report['unmatched_limitations'] or report['pending_command_controls']
        or report['pending_command_entries'] or any(not row['selected_product'] or row['uncovered_suites']
            or row['missing_gates'] for row in report['flavors'].values()))
    return report


def validate_inventory_sources(inventory, source, references, candidate):
    """Reject omissions or stale policy before reconciling actual local results."""
    if (source/'UPSTREAM_COMMIT').read_text().strip() != UPSTREAM_COMMIT:
        raise ValueError('Qualification source pin differs')
    specifications = {str(path.relative_to(source)):path for directory in source_directories(source)
                      for pattern in ('*.spec','*.dynspec') for path in directory.glob(pattern)}
    rows = inventory['specifications']
    if len(rows) != len(specifications) or {row['path'] for row in rows} != specifications.keys():
        raise ValueError('Inventory omits or duplicates a top-level specification')
    if inventory['required_gates'] != REQUIRED_GATES:
        raise ValueError('Inventory changes the required local qualification gates')
    sources = {str(path.relative_to(source)):digest(path) for directory in source_directories(source)
               for path in directory.glob('*_SUITE.erl')}
    if inventory['suite_sources'] != sources:
        raise ValueError('Top-level suite-source inventory differs')
    resolved = {row['path']:row for row in resolve_specifications(source,Path(candidate['prefix']))}
    for row in rows:
        path = specifications[row['path']]
        if row['sha256'] != digest(path) or row['classification'] != specification_classification(path):
            raise ValueError('Stale or reclassified specification: ' + row['path'])
        if any(row.get(key) != value for key,value in resolved[row['path']].items()):
            raise ValueError('Inventory changes the Common Test specification selection: ' + row['path'])
        expected = expand_selection(source,resolved[row['path']])
        if [{k:v for k,v in item.items() if k != 'case_expansion'} for item in row['suites']] != [
                {k:v for k,v in item.items() if k != 'case_expansion'} for item in expected]:
            raise ValueError('Inventory omits or changes a resolved suite selection: ' + row['path'])
        for suite in row['suites']:
            if suite['sha256'] != digest(source/suite['source']) or suite['owner'] != primary_owner(suite['source']):
                raise ValueError('Stale suite source or changed primary owner: ' + suite['source'])
            if suite.get('applicability') == 'upstream-benchmark-exclusion' and not any(
                    skip['suite'].strip("'") == Path(suite['source']).stem and
                    skip['selection'] == 'all' and 'benchmark' in skip['reason'].lower()
                    for node in row.get('nodes',[]) for skip in node.get('skip_selections',[])):
                raise ValueError('Benchmark exclusion lacks an upstream selection')
    def without_annotations(manuals):
        return [dict(manual,controls=[{k:v for k,v in control.items() if k != 'coverage'}
                                     for control in manual['controls']]) for manual in manuals]
    if without_annotations(inventory['command_manuals']) != without_annotations(command_manuals(source)):
        raise ValueError('Command-manual inventory differs')
    original = next((record for record in references.values() if
                     record['provenance_sha256'] == inventory['resolver']['reference_sha256']),None)
    if original is None:
        raise ValueError('Inventory reference provenance is not selected')
    commands = {path:entry for path,entry in original['entries'].items() if '/bin/' in '/'+path
                and entry['kind'] != 'directory' and (entry['kind'] != 'file' or int(entry['mode'],8)&0o111)}
    if len(inventory['commands']) != len(commands) or {
            row['path']:row['entry'] for row in inventory['commands']} != commands:
        raise ValueError('Installed command/helper inventory differs from the reference')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--candidate-provenance', type=Path, action='append', required=True)
    parser.add_argument('--reference-provenance', type=Path, action='append', required=True)
    parser.add_argument('--result', type=Path, action='append', default=[])
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    candidates = {}
    for path in args.candidate_provenance:
        record = read_record(path)
        if record['runtime'] != 'candidate' or record['flavor'] in candidates:
            parser.error('Select exactly one candidate product per flavor')
        verify_installation(Path(record['prefix']),path)
        record['provenance_sha256'] = digest(path)
        candidates[record['flavor']] = record
    references = {}
    for path in args.reference_provenance:
        record = read_record(path)
        if record['runtime'] != 'reference' or record['flavor'] in references:
            parser.error('Select at most one original OTP 29.0 reference per flavor')
        references[record['flavor']] = dict(record, provenance_sha256=digest(path))
    results = [dict(json.loads(path.read_text()), _evidence_sha256=digest(path)) for path in args.result]
    inventory = json.loads(args.inventory.read_text())
    validate_inventory_sources(inventory,args.source.resolve(strict=True),references,next(iter(candidates.values())))
    report = reconcile(inventory, candidates, results, references)
    report['inputs'] = {str(path.resolve()):digest(path) for path in
                       [args.inventory, *args.candidate_provenance, *args.reference_provenance, *args.result]}
    args.output.write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
    for flavor, row in report['flavors'].items():
        print(f'{flavor}: {row["covered_suites"]} covered; {row["uncovered_suites"]} uncovered; '
              f'{len(row["missing_gates"])} missing behavior gates')
    print('Qualified:',report['qualified'])
    raise SystemExit(0 if report['qualified'] else 1)


if __name__ == '__main__':
    main()
