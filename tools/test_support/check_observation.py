#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Qualify native observations, including detached private executable cleanup."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from host_testing import owned_processes, stop_owned_processes, snapshot

observer, image = map(lambda value: Path(value).resolve(strict=True), sys.argv[1:])
subprocess.run([str(observer), '--self-test', str(image)], check=True, close_fds=True)
if sys.platform == 'darwin':
    work = observer.parent.parent / (observer.parent.name + '-acceptance') / 'observation'
    work.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='native-', dir=work) as directory:
        root = Path(directory)
        helper = root / 'sleep'
        shutil.copyfile('/bin/sleep', helper)
        helper.chmod(0o755)
        child = None
        try:
            child = subprocess.Popen([str(helper), '30'], close_fds=True, start_new_session=True)
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                observed = owned_processes(observer, root)
                if any(record['pid'] == child.pid for record in observed):
                    break
                time.sleep(.01)
            else:
                raise RuntimeError('Private executable did not appear')
            state = snapshot(observer, child.pid)
            if Path(state['executable']) != helper or not state['threads'] or not state['descriptors']:
                raise RuntimeError('Private executable observations differ')
            stop_owned_processes(observer, root)
            child.wait(timeout=5)
            if owned_processes(observer, root):
                raise RuntimeError('Private executable did not disappear')
        finally:
            if child is not None and child.poll() is None:
                child.kill()
                child.wait()
            stop_owned_processes(observer, root)
print('Native descriptor/thread/child/mapping and owned-image restoration passed')
