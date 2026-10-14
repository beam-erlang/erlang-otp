#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Reproduce the startup option required by Observer's crash-dump fixtures."""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--prefix', type=Path, required=True)
args = parser.parse_args()
prefix = args.prefix.resolve(strict=True)
command = [str(prefix / 'bin/erl'), '+S2', '+Muatags', 'true', '-noshell',
           '-eval', 'io:format("ALLOCATOR_TAGS_OK~n"),halt().']
environment = {key: value for key, value in os.environ.items()
               if not key.startswith(('ERL_', 'ERLC_', 'ESCRIPT_', 'BEAM_', 'OTP_', 'LD_'))
               and key not in ('ROOTDIR', 'BINDIR', 'EMU', 'PROGNAME')}
process = subprocess.Popen(command, env=environment, start_new_session=True,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
timed_out = False
try:
    out, err = process.communicate(timeout=15)
except subprocess.TimeoutExpired:
    timed_out = True
    os.killpg(process.pid, signal.SIGKILL)
    out, err = process.communicate()
passed = not timed_out and process.returncode == 0 and out == b'ALLOCATOR_TAGS_OK\n' and not err
print(json.dumps({'command': command, 'exit_status': process.returncode,
                  'timed_out': timed_out, 'stdout': out.decode(errors='replace'),
                  'stderr': err.decode(errors='replace'),
                  'status': 'passed' if passed else 'failed'}, indent=2))
raise SystemExit(0 if passed else 1)
