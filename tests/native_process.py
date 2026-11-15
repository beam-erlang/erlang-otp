"""Native process ownership for installed-product and build-tree checks.

Windows children enter a kill-on-close Job before their initial thread runs.
No process-name searches, shell translation or ambient VM lookup are used.
"""
from __future__ import annotations

import contextlib
import os
from pathlib import Path
import signal
import subprocess
import uuid

WINDOWS = os.name == "nt"


def program(path):
    path = Path(path)
    if path.is_file():
        return path
    if WINDOWS and not path.suffix.lower() in (".exe", ".com", ".bat", ".cmd", ".dll"):
        return path.with_name(path.name + ".exe")
    return path


def command(arguments):
    arguments = [str(value) for value in arguments]
    if WINDOWS and arguments and Path(arguments[0]).is_absolute():
        arguments[0] = str(program(arguments[0]))
    return arguments


if WINDOWS:
    import ctypes
    from ctypes import wintypes as w

    kernel = ctypes.WinDLL("kernel32", use_last_error=True)

    class BASIC_LIMITS(ctypes.Structure):
        _fields_ = [("PerProcessUserTimeLimit", ctypes.c_int64), ("PerJobUserTimeLimit", ctypes.c_int64),
                    ("LimitFlags", w.DWORD), ("MinimumWorkingSetSize", ctypes.c_size_t),
                    ("MaximumWorkingSetSize", ctypes.c_size_t), ("ActiveProcessLimit", w.DWORD),
                    ("Affinity", ctypes.c_size_t), ("PriorityClass", w.DWORD), ("SchedulingClass", w.DWORD)]

    class IO_COUNTERS(ctypes.Structure):
        _fields_ = [(name, ctypes.c_uint64) for name in
                    ("ReadOperationCount", "WriteOperationCount", "OtherOperationCount",
                     "ReadTransferCount", "WriteTransferCount", "OtherTransferCount")]

    class EXTENDED_LIMITS(ctypes.Structure):
        _fields_ = [("BasicLimitInformation", BASIC_LIMITS), ("IoInfo", IO_COUNTERS),
                    ("ProcessMemoryLimit", ctypes.c_size_t), ("JobMemoryLimit", ctypes.c_size_t),
                    ("PeakProcessMemoryUsed", ctypes.c_size_t), ("PeakJobMemoryUsed", ctypes.c_size_t)]

    class THREADENTRY32(ctypes.Structure):
        _fields_ = [("dwSize", w.DWORD), ("cntUsage", w.DWORD), ("th32ThreadID", w.DWORD),
                    ("th32OwnerProcessID", w.DWORD), ("tpBasePri", w.LONG), ("tpDeltaPri", w.LONG),
                    ("dwFlags", w.DWORD)]

    for name, restype, argtypes in (
        ("CreateJobObjectW", w.HANDLE, [ctypes.c_void_p, w.LPCWSTR]),
        ("SetInformationJobObject", w.BOOL, [w.HANDLE, ctypes.c_int, ctypes.c_void_p, w.DWORD]),
        ("AssignProcessToJobObject", w.BOOL, [w.HANDLE, w.HANDLE]),
        ("TerminateJobObject", w.BOOL, [w.HANDLE, w.UINT]),
        ("CloseHandle", w.BOOL, [w.HANDLE]),
        ("CreateToolhelp32Snapshot", w.HANDLE, [w.DWORD, w.DWORD]),
        ("Thread32First", w.BOOL, [w.HANDLE, ctypes.POINTER(THREADENTRY32)]),
        ("Thread32Next", w.BOOL, [w.HANDLE, ctypes.POINTER(THREADENTRY32)]),
        ("OpenThread", w.HANDLE, [w.DWORD, w.BOOL, w.DWORD]),
        ("ResumeThread", w.DWORD, [w.HANDLE]),
    ):
        function = getattr(kernel, name)
        function.restype, function.argtypes = restype, argtypes

    def _checked(value):
        if not value:
            raise ctypes.WinError(ctypes.get_last_error())
        return value

    def _contain_and_resume(process, name):
        job = _checked(kernel.CreateJobObjectW(None, name))
        if ctypes.get_last_error() == 183:
            kernel.CloseHandle(job)
            raise RuntimeError('Owned controller Job already exists')
        try:
            limits = EXTENDED_LIMITS()
            limits.BasicLimitInformation.LimitFlags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            _checked(kernel.SetInformationJobObject(job, 9, ctypes.byref(limits), ctypes.sizeof(limits)))
            _checked(kernel.AssignProcessToJobObject(job, int(process._handle)))
            snapshot = kernel.CreateToolhelp32Snapshot(4, 0)  # TH32CS_SNAPTHREAD
            if snapshot == w.HANDLE(-1).value:
                raise ctypes.WinError(ctypes.get_last_error())
            try:
                entry = THREADENTRY32()
                entry.dwSize = ctypes.sizeof(entry)
                more = kernel.Thread32First(snapshot, ctypes.byref(entry))
                threads = []
                while more:
                    if entry.th32OwnerProcessID == process.pid:
                        threads.append(entry.th32ThreadID)
                    more = kernel.Thread32Next(snapshot, ctypes.byref(entry))
                if len(threads) != 1:
                    raise RuntimeError("Suspended controller has no unique initial thread")
                thread = _checked(kernel.OpenThread(2, False, threads[0]))  # THREAD_SUSPEND_RESUME
                try:
                    if kernel.ResumeThread(thread) != 1:
                        raise RuntimeError("Controller initial thread was not suspended exactly once")
                finally:
                    kernel.CloseHandle(thread)
            finally:
                kernel.CloseHandle(snapshot)
            return job
        except BaseException:
            kernel.TerminateJobObject(job, 1)
            kernel.CloseHandle(job)
            raise


class ContainedProcess(subprocess.Popen):
    def __init__(self, arguments, **options):
        self._owned_job = None
        if WINDOWS:
            if options.pop("preexec_fn", None) is not None:
                raise ValueError("POSIX pre-exec hooks are unavailable on Windows")
            options.pop("start_new_session", None)
            self.job_name = 'otp-validation-' + uuid.uuid4().hex
            options["creationflags"] = options.get("creationflags", 0) | 4  # CREATE_SUSPENDED
        else:
            options["start_new_session"] = True
        super().__init__(command(arguments), **options)
        if WINDOWS:
            try:
                self._owned_job = _contain_and_resume(self, self.job_name)
            except BaseException:
                self.kill()
                self.wait(timeout=5)
                raise

    def close_tree(self):
        if WINDOWS:
            job, self._owned_job = self._owned_job, None
            if job is not None:
                try:
                    _checked(kernel.TerminateJobObject(job, 1))
                finally:
                    _checked(kernel.CloseHandle(job))
        else:
            with contextlib.suppress(ProcessLookupError):
                os.killpg(self.pid, signal.SIGKILL)


def stop_tree(process, signum=None):
    if WINDOWS:
        process.close_tree()
    else:
        with contextlib.suppress(ProcessLookupError):
            os.killpg(process.pid, signum or signal.SIGKILL)
