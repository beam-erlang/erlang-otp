# SPDX-License-Identifier: Apache-2.0
"""Bootstrap manifest paths are portable, canonical and confined to their root."""
import hashlib
from pathlib import Path
import tempfile
import unittest

from otp_bootstrap import relative, verify_files


class BootstrapPaths(unittest.TestCase):
    def test_canonical_path_acquires_exact_bytes(self):
        name = 'lib/example/ebin/example.beam'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / relative(name)
            target.parent.mkdir(parents=True)
            target.write_bytes(b'FOR1\x00\r\n\xff')
            manifest = {name: hashlib.sha256(target.read_bytes()).hexdigest()}
            verify_files(root, manifest)
            target.write_bytes(b'FOR1\x00\n\xff')
            with self.assertRaises(ValueError):
                verify_files(root, manifest)

    def test_rejects_traversal_and_host_path_aliases(self):
        for name in ('', '.', '/absolute', '../outside', 'lib/../outside',
                     './lib/a', 'lib//a', 'lib/a/', 'C:/outside', 'C:relative',
                     '//server/share/a', r'lib\a', r'\outside', r'\\server\share\a'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                relative(name)


if __name__ == '__main__':
    unittest.main()
