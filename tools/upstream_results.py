# SPDX-License-Identifier: Apache-2.0
"""Reconcile Common Test terminal events with its independent aggregate."""
import json

STATUSES = ('passed', 'failed', 'user_skipped', 'auto_skipped')


def case_results(path, totals):
    events = [json.loads(line) for line in path.read_text().splitlines()]
    if not events or events[0] != {'event': 'handler_start'} or events[-1] != {'event': 'handler_stop'}:
        raise ValueError('Common Test event stream is incomplete')
    cases, configurations, occurrences = [], [], {}
    for index, event in enumerate(events[1:-1], 1):
        if event.get('event') not in {'tc_done', 'tc_user_skip', 'tc_auto_skip'}:
            raise ValueError('Unexpected Common Test event')
        if event.get('status') not in STATUSES or type(event.get('configuration')) is not bool:
            raise ValueError('Malformed Common Test outcome')
        if not all(isinstance(event.get(key), str) and event[key]
                   for key in ('suite', 'name', 'context', 'reason')):
            raise ValueError('Missing Common Test case identity or reason')
        status = event['status']
        if event['event'] == 'tc_user_skip' and status != 'user_skipped' or (
                event['event'] == 'tc_auto_skip' and status != 'auto_skipped'):
            raise ValueError('Conflicting Common Test skip outcome')
        identity = (event['suite'], event['context'])
        occurrences[identity] = occurrences.get(identity, 0) + 1
        item = {key:event[key] for key in ('suite', 'name', 'context', 'status', 'reason')}
        item['occurrence'] = occurrences[identity]
        item['event_index'] = index
        (configurations if event['configuration'] else cases).append(item)
    observed = tuple(sum(case['status'] == status for case in cases) for status in STATUSES)
    if observed != tuple(totals):
        raise ValueError(f'Common Test case events {observed} disagree with aggregate {tuple(totals)}')
    return cases, configurations
