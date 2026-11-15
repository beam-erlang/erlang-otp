#!/usr/bin/env python3
"""Regressions for CMake's atomic installation publication boundary."""
import argparse
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "cmake/OTPPublishInstall.cmake"
CMAKE = shutil.which("cmake")


class InstallationBoundary(unittest.TestCase):
    def setUp(self):
        scratch = Path(__file__).resolve().parents[2] / "tmp"
        scratch.mkdir(exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="otp-install-boundary-", dir=scratch)
        self.root = Path(self.temporary.name)
        self.prefix = self.root / "installation prefix with spaces"
        self.prefix.mkdir()
        self.stage = self.prefix / ".otp-install-probe"
        self.stage.mkdir()

    def tearDown(self):
        self.temporary.cleanup()

    def publish(self, stage=None, prefix=None):
        return subprocess.run([CMAKE, f"-DOTP_INSTALL_STAGE={stage or self.stage}",
            f"-DOTP_INSTALL_PREFIX={prefix or self.prefix}", "-P", str(SCRIPT)],
            capture_output=True, text=True)

    def assert_published(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.stage.exists())

    def test_directory_symlink_rejects_before_any_publication(self):
        outside = self.root / "outside"
        outside.mkdir()
        (outside / "sentinel").write_text("outside unchanged")
        (self.prefix / "sentinel").write_text("prefix unchanged")
        (self.prefix / "lib").symlink_to(outside, target_is_directory=True)
        (self.stage / "early-root-file").write_text("must not publish")
        (self.stage / "lib").mkdir()
        (self.stage / "lib/new-file").write_text("must not escape")
        result = self.publish()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.prefix / "early-root-file").exists())
        self.assertFalse((outside / "new-file").exists())
        self.assertEqual((outside / "sentinel").read_text(encoding="utf-8"), "outside unchanged")
        self.assertEqual((self.prefix / "sentinel").read_text(encoding="utf-8"), "prefix unchanged")
        self.assertTrue((self.prefix / "lib").is_symlink())
        self.assertEqual((self.stage / "early-root-file").read_text(encoding="utf-8"), "must not publish")

    def test_stage_symlink_is_rejected_even_with_matching_resolved_parent(self):
        real = self.prefix / "other-work"
        real.mkdir()
        (real / "sentinel").write_text("do not move")
        alias = self.prefix / ".otp-install-alias"
        alias.symlink_to(real, target_is_directory=True)
        self.assertEqual(alias.resolve().parent, self.prefix.resolve())
        result = self.publish(alias)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(alias.is_symlink())
        self.assertEqual((real / "sentinel").read_text(encoding="utf-8"), "do not move")
        self.assertFalse((self.prefix / "sentinel").exists())

    def test_leaf_symlink_is_replaced_without_touching_its_target(self):
        outside = self.root / "outside-target"
        outside.write_text("outside unchanged")
        (self.prefix / "lib").mkdir()
        leaf = self.prefix / "lib/payload"
        leaf.symlink_to(outside)
        (self.stage / "lib").mkdir()
        (self.stage / "lib/payload").write_text("new installed file")
        result = self.publish()
        self.assert_published(result)
        self.assertFalse(leaf.is_symlink())
        self.assertEqual(leaf.read_text(encoding="utf-8"), "new installed file")
        self.assertEqual(outside.read_text(encoding="utf-8"), "outside unchanged")

    def test_non_directory_destination_rejects_before_any_publication(self):
        (self.prefix / "lib").write_text("preserve existing file")
        (self.stage / "early-root-file").write_text("must not publish")
        (self.stage / "lib").mkdir()
        (self.stage / "lib/new-file").write_text("must not publish")
        result = self.publish()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.prefix / "lib").read_text(encoding="utf-8"), "preserve existing file")
        self.assertFalse((self.prefix / "early-root-file").exists())
        self.assertTrue((self.stage / "early-root-file").exists())

    def test_stage_outside_selected_prefix_is_rejected(self):
        stage = self.root / ".otp-install-outside"
        stage.mkdir()
        (stage / "sentinel").write_text("do not move")
        result = self.publish(stage)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((stage / "sentinel").read_text(encoding="utf-8"), "do not move")
        self.assertFalse((self.prefix / "sentinel").exists())

    def test_destination_prefix_symlink_is_rejected(self):
        alias = self.root / "prefix-alias"
        alias.symlink_to(self.prefix, target_is_directory=True)
        (self.stage / "sentinel").write_text("do not move")
        result = self.publish(prefix=alias)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.stage / "sentinel").read_text(encoding="utf-8"), "do not move")
        self.assertFalse((self.prefix / "sentinel").exists())

    def test_symlink_checks_reject_trailing_slash_and_dot_spellings(self):
        (self.stage / "sentinel").write_text("do not move")
        stage_alias = self.prefix / ".otp-install-alias"
        stage_alias.symlink_to(self.stage, target_is_directory=True)
        prefix_alias = self.root / "prefix-alias"
        prefix_alias.symlink_to(self.prefix, target_is_directory=True)
        for suffix in ("/", "/.", "/./", "/.//."):
            for kind in ("stage", "prefix"):
                with self.subTest(suffix=suffix, kind=kind):
                    if kind == "stage":
                        result = self.publish(stage=str(stage_alias) + suffix)
                    else:
                        result = self.publish(prefix=str(prefix_alias) + suffix)
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual((self.stage / "sentinel").read_text(encoding="utf-8"), "do not move")
                    self.assertFalse((self.prefix / "sentinel").exists())

    def test_new_subtree_retains_directory_and_executable_modes(self):
        subtree = self.stage / "lib"
        nested = subtree / "app/include"
        nested.mkdir(parents=True)
        subtree.chmod(0o750)
        nested.chmod(0o700)
        payload = nested / "payload"
        payload.write_text("new executable")
        payload.chmod(0o751)
        subtree_inode = subtree.stat().st_ino
        result = self.publish()
        self.assert_published(result)
        self.assertEqual((self.prefix / "lib").stat().st_ino, subtree_inode)
        for relative, mode in (("lib", 0o750), ("lib/app/include", 0o700),
                               ("lib/app/include/payload", 0o751)):
            self.assertEqual(stat.S_IMODE((self.prefix / relative).stat().st_mode), mode)

    def test_existing_directory_retains_mode_and_open_file_retains_old_inode(self):
        destination = self.prefix / "lib"
        destination.mkdir()
        destination.chmod(0o700)
        leaf = destination / "payload"
        leaf.write_text("old installed file")
        (self.stage / "lib").mkdir()
        source = self.stage / "lib/payload"
        source.write_text("new installed file")
        source.chmod(0o751)
        new_inode = source.stat().st_ino
        with leaf.open("rb") as old_mapping:
            result = self.publish()
            self.assert_published(result)
            self.assertEqual(old_mapping.read(), b"old installed file")
        self.assertEqual(leaf.read_text(encoding="utf-8"), "new installed file")
        self.assertEqual(leaf.stat().st_ino, new_inode)
        self.assertEqual(stat.S_IMODE(leaf.stat().st_mode), 0o751)
        self.assertEqual(stat.S_IMODE(destination.stat().st_mode), 0o700)

    def test_staged_directory_symlink_is_a_leaf(self):
        outside = self.root / "outside-directory"
        outside.mkdir()
        (outside / "sentinel").write_text("outside unchanged")
        (self.stage / "share").symlink_to(outside, target_is_directory=True)
        result = self.publish()
        self.assert_published(result)
        self.assertTrue((self.prefix / "share").is_symlink())
        self.assertEqual((outside / "sentinel").read_text(encoding="utf-8"), "outside unchanged")

    def test_hidden_files_publish_and_unrelated_files_remain(self):
        (self.prefix / "unrelated").write_text("preserve unrelated file")
        (self.stage / ".hidden").write_text("installed hidden file")
        result = self.publish()
        self.assert_published(result)
        self.assertEqual((self.prefix / ".hidden").read_text(encoding="utf-8"), "installed hidden file")
        self.assertEqual((self.prefix / "unrelated").read_text(encoding="utf-8"), "preserve unrelated file")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--cmake", default=CMAKE)
    arguments, remaining = parser.parse_known_args()
    CMAKE = arguments.cmake
    if not CMAKE:
        parser.error("set --cmake to the CMake executable")
    unittest.main(argv=[sys.argv[0], *remaining])
