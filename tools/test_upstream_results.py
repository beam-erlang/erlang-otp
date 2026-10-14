# SPDX-License-Identifier: Apache-2.0
"""Evidence integrity checks independent of a running OTP product."""
import json
from pathlib import Path
import tempfile
import unittest

from upstream_results import case_results
from qualify_local import approved_skip, complete_suite, matches_product, reconcile


class CaseEvidence(unittest.TestCase):
    def parse(self, events, counts):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'events.log'
            path.write_text('\n'.join(json.dumps(event) for event in events))
            return case_results(path, counts)

    def event(self, status='passed', configuration=False, context='test'):
        return {'event':'tc_done', 'suite':'suite', 'name':'test', 'context':context,
                'configuration':configuration, 'status':status, 'reason':'ok'}

    def stream(self, *events):
        return [{'event':'handler_start'}, *events, {'event':'handler_stop'}]

    def test_repeated_group_case_keeps_occurrence(self):
        cases, _ = self.parse(self.stream(self.event(context='{test,group}'),
                                         self.event(context='{test,group}')), (2,0,0,0))
        self.assertEqual([1,2], [case['occurrence'] for case in cases])

    def test_configuration_does_not_inflate_case_total(self):
        cases, configurations = self.parse(self.stream(self.event(configuration=True),
                                                     self.event()), (1,0,0,0))
        self.assertEqual(1,len(cases))
        self.assertEqual(1,len(configurations))

    def test_truncated_stream_is_rejected(self):
        with self.assertRaisesRegex(ValueError,'incomplete'):
            self.parse(self.stream(self.event())[:-1],(1,0,0,0))

    def test_forged_aggregate_is_rejected(self):
        with self.assertRaisesRegex(ValueError,'disagree'):
            self.parse(self.stream(self.event('failed')),(1,0,0,0))

    def test_skip_reason_and_raw_status_survive(self):
        event = self.event('user_skipped')
        event.update(event='tc_user_skip', reason='{not_yet_implemented,feature}')
        cases, _ = self.parse(self.stream(event),(0,0,1,0))
        self.assertEqual(event['reason'],cases[0]['reason'])
        self.assertEqual('user_skipped',cases[0]['status'])

    def test_conflicting_skip_status_is_rejected(self):
        event = self.event()
        event['event'] = 'tc_auto_skip'
        with self.assertRaisesRegex(ValueError,'Conflicting'):
            self.parse(self.stream(event),(1,0,0,0))


class QualificationIntegrity(unittest.TestCase):
    def result(self):
        return {'suite':'sample_SUITE', 'source_sha256':{'sample_SUITE.erl':'source-hash'},
            'complete':True, 'case_evidence_complete':True, 'case_selection':'complete suite',
            'cases':[{'suite':'sample_SUITE','name':'one','status':'passed'}],
            'declared_selection':{'status':'resolved','cases':[{'suite':'sample_SUITE','name':'one'}]}}

    def test_complete_source_selection_is_accepted(self):
        self.assertTrue(complete_suite(self.result(),'sample_SUITE.erl','source-hash'))

    def test_matching_candidate_provenance_is_accepted(self):
        sdk = {'version':'version','build_id':'identity','flavor':'emu'}
        candidate = {'build':{'sdk_selection':sdk},'provenance_sha256':'whole-installation'}
        result = {'installation':{'runtime':'candidate','provenance_sha256':'whole-installation'},'sdk':sdk,
                  'runtime_images':{'erts/bin/beam.smp':'image'}}
        self.assertTrue(matches_product(result,candidate))

    def test_same_vm_does_not_cover_changed_applications(self):
        sdk = {'version':'version','build_id':'identity','flavor':'emu'}
        candidate = {'build':{'sdk_selection':sdk},'provenance_sha256':'new-application-tree',
                     'entries':{'erts/bin/beam.smp':{'sha256':'image'}}}
        result = {'installation':{'runtime':'candidate','provenance_sha256':'old-application-tree'},
                  'sdk':sdk,'runtime_images':{'erts/bin/beam.smp':'image'}}
        self.assertFalse(matches_product(result,candidate))

    def test_subset_does_not_cover_complete_suite(self):
        result = self.result()
        result['case_selection'] = '{testcase,[one]},'
        self.assertFalse(complete_suite(result,'sample_SUITE.erl','source-hash'))

    def test_terminal_failure_overrides_complete_flag(self):
        result = self.result()
        result['cases'][0]['status'] = 'failed'
        self.assertFalse(complete_suite(result,'sample_SUITE.erl','source-hash'))

    def test_declared_case_mismatch_is_rejected(self):
        result = self.result()
        result['declared_selection']['cases'][0]['name'] = 'missing'
        self.assertFalse(complete_suite(result,'sample_SUITE.erl','source-hash'))

    def test_stale_source_does_not_cover_suite(self):
        self.assertFalse(complete_suite(self.result(),'sample_SUITE.erl','changed-source'))

    def test_instrumented_run_does_not_qualify(self):
        result = self.result()
        result['instrumented'] = True
        self.assertFalse(complete_suite(result,'sample_SUITE.erl','source-hash'))

    def test_ordered_cases_cannot_be_reordered(self):
        result = self.result()
        result['declared_selection']['cases'].append({'suite':'sample_SUITE','name':'two'})
        result['cases'].insert(0, {'suite':'sample_SUITE','name':'two','status':'passed'})
        self.assertFalse(complete_suite(result,'sample_SUITE.erl','source-hash'))

    def test_group_policy_needs_context_evidence(self):
        result = self.result()
        result['declared_selection']['cases'][0]['groups'] = [{'name':'sequence'}]
        self.assertFalse(complete_suite(result,'sample_SUITE.erl','source-hash'))

    def test_reference_cannot_qualify_candidate(self):
        sdk = {'version':'version','build_id':'identity','flavor':'emu'}
        candidate = {'build':{'sdk_selection':sdk},'entries':{'erts/bin/beam.smp':{'sha256':'image'}}}
        result = {'installation':{'runtime':'reference'},'sdk':sdk,
                  'runtime_images':{'erts/bin/beam.smp':'image'}}
        self.assertFalse(matches_product(result,candidate))

    def test_unproven_exception_is_not_a_blanket_waiver(self):
        from installation_inventory import UPSTREAM_COMMIT
        inventory = {'format':1,'upstream_commit':UPSTREAM_COMMIT,'limitations':[{'reason':'skip'}]}
        with self.assertRaises(ValueError):
            reconcile(inventory,{},[])


class NamedLimitationIntegrity(unittest.TestCase):
    def setUp(self):
        self.case = {'suite':'sample_SUITE','name':'unsupported','context':'unsupported','occurrence':1,
                     'status':'user_skipped','reason':'{skipped,not_supported}'}
        self.policy = {'id':'sample-emu','flavor':'emu','suite_source':'sample_SUITE.erl',
            'source_sha256':'source-hash','case_identity':{key:self.case[key] for key in
                ('suite','name','context','occurrence')},'status':'user_skipped',
            'reason':self.case['reason'],'reference_result_sha256':'original-result',
            'reference_provenance_sha256':'original-installation',
            'supplemental_results':['supplemental-result'],'rationale':'Exact upstream unsupported path'}
        original = {'suite':'sample_SUITE','source_sha256':{'sample_SUITE.erl':'source-hash'},
            'case_evidence_complete':True,'case_selection':'complete suite','cases':[dict(self.case)],
            'declared_selection':{'status':'resolved','cases':[{'suite':'sample_SUITE','name':'unsupported'}]},
            'installation':{'runtime':'reference','flavor':'emu','provenance_sha256':'original-installation'}}
        self.results = {'original-result':original,'supplemental-result':{
            'complete':True,'gate':'limitation:sample-emu','_selected_candidate':True}}
        self.references = {'emu':{'provenance_sha256':'original-installation'}}

    def accepted(self):
        return approved_skip(self.case,'sample_SUITE.erl','source-hash','emu',
                             [self.policy],self.results,self.references)

    def test_exact_skip_with_original_and_supplement_is_accepted(self):
        self.assertEqual('sample-emu',self.accepted())
        self.assertEqual('user_skipped',self.case['status'])

    def test_changed_skip_reason_is_rejected(self):
        self.case['reason'] = '{skipped,prerequisite_missing}'
        self.assertIsNone(self.accepted())

    def test_candidate_only_skip_is_rejected(self):
        self.results['original-result']['cases'][0]['status'] = 'passed'
        self.assertIsNone(self.accepted())

    def test_original_from_other_installation_is_rejected(self):
        self.results['original-result']['installation']['provenance_sha256'] = 'different-reference'
        self.assertIsNone(self.accepted())

    def test_unproven_supplement_is_rejected(self):
        self.results['supplemental-result']['_selected_candidate'] = False
        self.assertIsNone(self.accepted())

    def test_failed_case_cannot_be_named_skip(self):
        self.case['status'] = 'failed'
        self.assertIsNone(self.accepted())


class WholeQualificationIntegrity(unittest.TestCase):
    def inputs(self):
        from installation_inventory import UPSTREAM_COMMIT
        inventory = {'format':1,'upstream_commit':UPSTREAM_COMMIT,
            'target':{'flavors':['emu','jit']},'limitations':[],
            'specifications':[{'path':'sample.spec','status':'resolved','classification':'functional',
                'suites':[{'source':'sample_SUITE.erl','sha256':'source-hash','owner':'otp'}]}],
            'command_manuals':[],'commands':[],'required_gates':[]}
        candidates, results = {}, []
        for flavor in ('emu','jit'):
            sdk = {'version':'version','build_id':flavor,'flavor':flavor}
            candidates[flavor] = {'build':{'sdk_selection':sdk},'provenance_sha256':flavor+'-installation'}
            result = QualificationIntegrity().result()
            result.update(sdk=sdk,installation={'runtime':'candidate',
                'provenance_sha256':flavor+'-installation'},_evidence_sha256=flavor+'-result')
            results.append(result)
        return inventory,candidates,results

    def test_both_complete_products_can_qualify(self):
        self.assertTrue(reconcile(*self.inputs())['qualified'])

    def test_any_selected_failure_blocks_historical_pass(self):
        inventory,candidates,results = self.inputs()
        import copy
        failed = copy.deepcopy(results[0])
        failed.update(complete=False,_evidence_sha256='failed-run')
        failed['cases'][0]['status'] = 'failed'
        results.append(failed)
        report = reconcile(inventory,candidates,results)
        self.assertFalse(report['qualified'])
        self.assertEqual('uncovered',report['flavors']['emu']['suites']['sample_SUITE.erl'])

    def test_false_raw_complete_flag_remains_blocking(self):
        inventory,candidates,results = self.inputs()
        results[0]['complete'] = False
        self.assertFalse(reconcile(inventory,candidates,results)['qualified'])

    def test_missing_flavor_remains_blocking(self):
        inventory,candidates,results = self.inputs()
        del candidates['jit']
        self.assertFalse(reconcile(inventory,candidates,results)['qualified'])

    def test_command_annotation_needs_each_flavors_actual_evidence(self):
        inventory,candidates,results = self.inputs()
        inventory['commands'] = [{'path':'bin/erl','coverage':'complete'}]
        inventory['command_manuals'] = [{'source':'erl_cmd.md','sha256':'manual-hash',
            'controls':[{'id':'erl:option','coverage':'complete'}]}]
        self.assertFalse(reconcile(inventory,candidates,results)['qualified'])
        for result in results:
            result.update(command_entries=['bin/erl'],command_controls=['erl:option'])
            result['source_sha256']['erl_cmd.md'] = 'manual-hash'
        self.assertTrue(reconcile(inventory,candidates,results)['qualified'])
        results[1]['source_sha256']['erl_cmd.md'] = 'stale-manual'
        self.assertFalse(reconcile(inventory,candidates,results)['qualified'])


if __name__ == '__main__':
    unittest.main()
