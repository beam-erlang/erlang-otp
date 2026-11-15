#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Focused read/write/exec checks for the Linux installed-test launcher."""
import errno
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    helper = Path(__file__).with_name("landlock.py")
    capability = subprocess.run([sys.executable, str(helper), "--check"])
    if capability.returncode:
        return capability.returncode
    with tempfile.TemporaryDirectory(prefix="otp-landlock-test-") as temporary:
        base = Path(temporary)
        work = base / "private work"
        work.mkdir()
        hidden = base / "producer"
        hidden.mkdir()
        (hidden / "secret").write_text("producer input")
        script = work / "private script"
        script.write_text("#!/bin/sh\nprintf 'landlock-work-script-ok\\n'\n")
        script.chmod(0o755)
        elf = work / "private ELF"
        shutil.copy2("/usr/bin/true", elf)
        blocked_script = hidden / "producer script"
        blocked_script.write_text("#!/bin/sh\nexit 0\n")
        blocked_script.chmod(0o755)
        wrapper = [sys.executable, str(helper), "--work", str(work), "--"]
        # This node is writable by the caller and beneath a read-only system
        # directory, so denial verifies Landlock rather than Unix permissions.
        descriptor, readonly_name = tempfile.mkstemp(prefix="otp-landlock-ro-", dir="/dev/shm")
        os.close(descriptor)
        readonly = Path(readonly_name)
        readonly.write_text("system read-only")
        try:
            # A runtime prefix contains both launcher scripts and ELF programs;
            # exercise them on the same backing filesystem as the private work.
            for command in ([str(script)], [str(elf)], ["/bin/sh", str(script)]):
                executed = subprocess.run(wrapper + command, capture_output=True, text=True)
                if executed.returncode:
                    print(executed.stderr, end="", file=sys.stderr)
                    return executed.returncode
            blocked = subprocess.run(wrapper + [str(blocked_script)], capture_output=True, text=True)
            assert blocked.returncode == 126, blocked.returncode
            expression = r'''
import errno, os, pathlib, sys
work, hidden, readonly = map(pathlib.Path, sys.argv[1:])
def denied(operation):
    try:
        operation()
    except OSError as error:
        assert error.errno in (errno.EACCES, errno.EPERM), error
    else:
        raise AssertionError("filesystem access unexpectedly allowed")
assert readonly.read_text() == "system read-only"
denied(lambda: readonly.write_text("changed"))
denied(lambda: (hidden / "secret").read_bytes())
denied(lambda: list(hidden.iterdir()))
denied(lambda: (hidden / "new").write_text("outside work"))
output = work / "output"
output.write_text("work allowed")
assert output.read_text() == "work allowed"
subdir = work / "subdirectory"
subdir.mkdir()
output.rename(subdir / "renamed")
assert (subdir / "renamed").read_text() == "work allowed"
with open("/dev/null", "wb") as sink:
    sink.write(b"device sink")
print("landlock-read-write-exec-ok")
'''
            completed = subprocess.run([sys.executable, str(helper), "--work", str(work), "--",
                sys.executable, "-c", expression, str(work), str(hidden), str(readonly)],
                capture_output=True, text=True)
            print(completed.stdout, end="")
            print(completed.stderr, end="", file=sys.stderr)
            if completed.returncode:
                return completed.returncode
            assert readonly.read_text(encoding="utf-8") == "system read-only"
            assert not (hidden / "new").exists()
            # exec preserves the launched command's ordinary exit status.
            status = subprocess.run([sys.executable, str(helper), "--work", str(work), "--",
                sys.executable, "-c", "raise SystemExit(23)"])
            assert status.returncode == 23, status.returncode
        finally:
            readonly.unlink()
    return 0


if __name__ == "__main__":
    sys.exit(main())
