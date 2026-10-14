# SPDX-License-Identifier: Apache-2.0
"""Resolve and verify declared installed public-header dependency closures."""
import hashlib
import json
from pathlib import Path


def header_closure(sdk, roots):
    sdk = sdk.resolve()
    records = json.loads((sdk / 'lib/beam/runtime-artifacts.json').read_text())['artifacts']
    pending, selected = list(roots), set()
    headers = set()
    while pending:
        identity = pending.pop()
        if identity in selected:
            continue
        selected.add(identity)
        record = records[identity]
        relative = Path(record['path'])
        if (record['kind'] not in {'embedding-header', 'native-header'} or
                relative.is_absolute() or '..' in relative.parts or
                relative.parts[0] != 'include'):
            raise RuntimeError(f'Invalid public header artifact: {identity}')
        path = (sdk / relative).resolve()
        if not path.is_relative_to(sdk / 'include'):
            raise RuntimeError(f'Public header escapes the selected SDK: {identity}')
        if hashlib.sha256(path.read_bytes()).hexdigest() != record['sha256']:
            raise RuntimeError(f'Public header differs from its SDK artifact: {identity}')
        headers.add(path)
        pending.extend(record['requires'])
    return headers
