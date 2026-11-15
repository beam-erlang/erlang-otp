"""Windows publication must reject in-use files before replacing any leaf."""
import argparse
import ctypes
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile
import unittest


GUARD = None
CMAKE = shutil.which("cmake")
PUBLISH = Path(__file__).resolve().parents[1] / "cmake/OTPPublishInstall.cmake"


@unittest.skipUnless(os.name == "nt", "Windows native publication guard")
class WindowsPublication(unittest.TestCase):
    def setUp(self):
        scratch = Path(__file__).resolve().parents[2] / "tmp"
        scratch.mkdir(exist_ok=True)
        self.work = tempfile.TemporaryDirectory(prefix="otp-windows-publish-", dir=scratch)
        self.prefix = Path(self.work.name) / "installed tree with spaces λ"
        self.prefix.mkdir()
        self.stage = self.prefix / ".otp-install-probe"
        self.stage.mkdir()
        (self.prefix / "lib").mkdir()
        (self.stage / "lib").mkdir()
        self.destination = self.prefix / "lib/payload.dll"
        self.destination.write_bytes(b"original")
        (self.stage / "lib/payload.dll").write_bytes(b"replacement")
        (self.stage / "early.txt").write_bytes(b"new leaf")

    def tearDown(self):
        self.work.cleanup()

    def publish(self):
        return subprocess.run([GUARD, str(self.stage), str(self.prefix), CMAKE,
            f"-DOTP_INSTALL_STAGE={self.stage}", f"-DOTP_INSTALL_PREFIX={self.prefix}",
            "-P", str(PUBLISH)], capture_output=True, text=True, encoding="utf-8", errors="replace")

    def test_replaces_complete_tree_in_unicode_directory(self):
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.destination.read_bytes(), b"replacement")
        self.assertEqual((self.prefix / "early.txt").read_bytes(), b"new leaf")
        self.assertFalse(self.stage.exists())

    def test_locked_leaf_rejects_before_first_replacement(self):
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.CreateFileW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32,
            ctypes.c_uint32, ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
        kernel.CreateFileW.restype = ctypes.c_void_p
        kernel.CloseHandle.argtypes = [ctypes.c_void_p]
        handle = kernel.CreateFileW(str(self.destination), 0x80000000, 1, None, 3, 0, None)
        self.assertNotEqual(handle, ctypes.c_void_p(-1).value)
        try:
            result = self.publish()
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(self.destination.read_bytes(), b"original")
            self.assertFalse((self.prefix / "early.txt").exists())
            self.assertEqual((self.stage / "lib/payload.dll").read_bytes(), b"replacement")
            self.assertIn("in use", result.stderr)
        finally:
            kernel.CloseHandle(handle)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--guard", required=True)
    parser.add_argument("--cmake", default=CMAKE)
    args, remaining = parser.parse_known_args()
    GUARD, CMAKE = args.guard, args.cmake
    unittest.main(argv=[sys.argv[0], *remaining])
