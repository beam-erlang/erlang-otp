#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Run installed-product checks with an unprivileged Linux filesystem policy.

Only the explicit system directories and the private work directory can be
read or executed. System files cannot be opened for writing; the work directory
permits ordinary file operations. Metadata-only operations such as stat/chdir
are outside Landlock's filesystem access rights. No network policy is added.
"""
from __future__ import annotations

import argparse
import ctypes
import errno
import os
from pathlib import Path
import sys
import tempfile


UNAVAILABLE = 77
SETUP_FAILED = 125
SYSTEM_DIRECTORIES = ("/usr", "/bin", "/sbin", "/lib", "/lib64", "/etc",
                      "/dev", "/proc", "/sys", "/run")
EXECUTE = 1 << 0
WRITE_FILE = 1 << 1
READ_FILE = 1 << 2
READ_DIR = 1 << 3
REFER = 1 << 13
TRUNCATE = 1 << 14
V1_RIGHTS = (1 << 13) - 1
READ_ONLY = EXECUTE | READ_FILE | READ_DIR


class Ruleset(ctypes.Structure):
    _fields_ = [("handled_access_fs", ctypes.c_uint64)]


class PathBeneath(ctypes.Structure):
    _pack_ = 1
    _fields_ = [("allowed_access", ctypes.c_uint64), ("parent_fd", ctypes.c_int32)]


class NotAvailable(RuntimeError):
    pass


def libc():
    if sys.platform != "linux" or os.uname().machine not in {"aarch64", "arm64", "x86_64"}:
        raise NotAvailable("requires native Linux AArch64 or x86-64")
    library = ctypes.CDLL(None, use_errno=True)
    library.syscall.restype = ctypes.c_long
    return library


def syscall(library, number, *arguments):
    result = library.syscall(ctypes.c_long(number), *arguments)
    if result < 0:
        code = ctypes.get_errno()
        raise OSError(code, os.strerror(code))
    return result


def abi_version(library):
    try:
        return syscall(library, 444, ctypes.c_void_p(), ctypes.c_size_t(0), ctypes.c_uint(1))
    except OSError as error:
        if error.errno in {errno.ENOSYS, errno.EOPNOTSUPP, errno.EPERM, errno.EACCES}:
            raise NotAvailable(f"Landlock is unavailable or forbidden: {error}") from error
        raise


def restrict(work: Path):
    library = libc()
    abi = abi_version(library)
    rights = V1_RIGHTS
    # Preserve renames within the work tree and constrain truncation when the
    # kernel supports these newer filesystem rights. The base policy uses v1.
    if abi >= 2:
        rights |= REFER
    if abi >= 3:
        rights |= TRUNCATE
    attributes = Ruleset(rights)
    ruleset = syscall(library, 444, ctypes.byref(attributes),
                      ctypes.c_size_t(ctypes.sizeof(attributes)), ctypes.c_uint(0))
    try:
        def allow(path: Path, access: int):
            descriptor = os.open(path, os.O_PATH | os.O_CLOEXEC)
            try:
                rule = PathBeneath(access, descriptor)
                syscall(library, 445, ctypes.c_int(ruleset), ctypes.c_int(1),
                        ctypes.byref(rule), ctypes.c_uint(0))
            finally:
                os.close(descriptor)

        for directory in SYSTEM_DIRECTORIES:
            path = Path(directory)
            if path.is_dir():
                if path.resolve() == Path("/"):
                    raise RuntimeError(f"refusing a system-directory alias to /: {path}")
                allow(path, READ_ONLY)
        # Standard helpers may open this exact sink for output. Other devices
        # retain the read-only rule; no device creation is permitted there.
        if Path("/dev/null").exists():
            allow(Path("/dev/null"), READ_FILE | WRITE_FILE)
        allow(work, rights)
        if library.prctl(ctypes.c_int(38), ctypes.c_ulong(1), ctypes.c_ulong(0),
                         ctypes.c_ulong(0), ctypes.c_ulong(0)) != 0:
            code = ctypes.get_errno()
            raise OSError(code, "PR_SET_NO_NEW_PRIVS: " + os.strerror(code))
        syscall(library, 446, ctypes.c_int(ruleset), ctypes.c_uint(0))
    finally:
        os.close(ruleset)
    return abi


def check():
    # Applying Landlock is irreversible for the calling process and descendants.
    # Test the complete setup in a child, leaving the test runner unrestricted.
    library = libc()
    abi = abi_version(library)
    with tempfile.TemporaryDirectory(prefix="otp-landlock-check-") as temporary:
        child = os.fork()
        if child == 0:
            try:
                restrict(Path(temporary))
            except NotAvailable as error:
                os.write(2, f"Landlock unavailable: {error}\n".encode())
                os._exit(UNAVAILABLE)
            except OSError as error:
                unavailable = error.errno in {errno.ENOSYS, errno.EOPNOTSUPP, errno.EPERM, errno.EACCES}
                os.write(2, f"Landlock check failed: {error}\n".encode())
                os._exit(UNAVAILABLE if unavailable else SETUP_FAILED)
            except Exception as error:
                os.write(2, f"Landlock check failed: {error}\n".encode())
                os._exit(SETUP_FAILED)
            os._exit(0)
        _, status = os.waitpid(child, 0)
        result = os.waitstatus_to_exitcode(status)
    if result == 0:
        print(f"Landlock filesystem policy available (ABI {abi})")
    return result if result >= 0 else SETUP_FAILED


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--work", type=Path)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    arguments = parser.parse_args()
    try:
        if arguments.check:
            if arguments.work is not None or arguments.command:
                parser.error("--check takes no work directory or command")
            return check()
        if arguments.work is None:
            parser.error("--work is required")
        work = arguments.work.resolve(strict=True)
        if not work.is_dir() or work.parent == Path("/") or work == Path("/"):
            parser.error("--work must be a private directory below a top-level directory")
        command = arguments.command
        if command[:1] == ["--"]:
            command = command[1:]
        if not command:
            parser.error("a command after -- is required")
        restrict(work)
    except NotAvailable as error:
        print(f"Landlock unavailable: {error}", file=sys.stderr)
        return UNAVAILABLE if arguments.check else SETUP_FAILED
    except (OSError, RuntimeError) as error:
        print(f"Landlock policy setup failed: {error}", file=sys.stderr)
        return SETUP_FAILED
    try:
        os.execvpe(command[0], command, os.environ)
    except OSError as error:
        print(f"Landlock command execution failed: {error}", file=sys.stderr)
        return 127 if error.errno == errno.ENOENT else 126


if __name__ == "__main__":
    sys.exit(main())
