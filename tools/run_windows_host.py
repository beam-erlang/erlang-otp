#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Run an explicit private build host using Erlang's Windows path spelling."""
import subprocess
import sys


def main():
    # filename:absname/1 lowercases Windows drive letters. Normalize only
    # absolute path arguments, retaining the selected host and all other bytes.
    arguments = [value[0].lower() + value[1:]
                 if len(value) >= 3 and value[0].isalpha() and value[1] == ':'
                 and value[2] in '/\\' else value for value in sys.argv[1:]]
    result = subprocess.run(arguments, stdin=sys.stdin, stdout=sys.stdout,
                            stderr=sys.stderr, creationflags=subprocess.DETACHED_PROCESS)
    return result.returncode


if __name__ == '__main__':
    sys.exit(main())
