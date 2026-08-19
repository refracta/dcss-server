#!/usr/bin/env python3
"""Tests for the numeric Housing snapshot binding migration."""

import hashlib
import os
from pathlib import Path
import sqlite3
import stat
import subprocess
import sys
import tempfile
import unittest

try:
    from . import backfill_housing_bindings as backfill
except ImportError:
    import backfill_housing_bindings as backfill


class HousingBindingBackfillTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.maps = self.root / "housing-maps"
        self.database = self.root / "dgamelaunch.db"
        with sqlite3.connect(str(self.database)) as connection:
            connection.execute(
                "CREATE TABLE dglusers ("
                "id INTEGER PRIMARY KEY, username TEXT, email TEXT, "
                "env TEXT, password TEXT, flags INTEGER)")

    def tearDown(self):
        self.temporary.cleanup()

    def add_user(self, account_id, username):
        with sqlite3.connect(str(self.database)) as connection:
            connection.execute(
                "INSERT INTO dglusers(id, username) VALUES (?, ?)",
                (account_id, username))

    def add_snapshot(self, account_id, map_id="main"):
        account = self.maps / str(account_id)
        account.mkdir(parents=True, exist_ok=True)
        (account / (map_id + ".hmap")).write_bytes(b"package")

    def binding(self, username):
        return self.maps / "by-name" / username.lower() / ".account-id"

    def test_missing_map_root_is_a_noop_without_opening_database(self):
        self.database.unlink()
        self.assertEqual(backfill.backfill_bindings(
            str(self.database), str(self.maps)), (0, 0))

    def test_numeric_snapshots_are_bound_from_read_only_database(self):
        self.add_user(17, "OwnerName")
        self.add_snapshot(17)
        (self.maps / "17" / "ignored.tmp").write_bytes(b"partial")
        (self.maps / "empty").mkdir()
        before = hashlib.sha256(self.database.read_bytes()).digest()

        self.assertEqual(backfill.backfill_bindings(
            str(self.database), str(self.maps)), (1, 1))
        binding = self.binding("OwnerName")
        self.assertEqual(binding.read_text(), "17")
        self.assertTrue(stat.S_ISREG(binding.lstat().st_mode))
        self.assertEqual(stat.S_IMODE(binding.stat().st_mode), 0o600)
        self.assertEqual(hashlib.sha256(self.database.read_bytes()).digest(),
                         before)
        self.assertFalse(Path(str(self.database) + "-journal").exists())
        self.assertFalse(Path(str(self.database) + "-wal").exists())
        self.assertFalse(Path(str(self.database) + "-shm").exists())

    def test_repeat_is_idempotent(self):
        self.add_user(17, "Owner")
        self.add_snapshot(17)
        self.assertEqual(backfill.backfill_bindings(
            str(self.database), str(self.maps)), (1, 1))
        self.assertEqual(backfill.backfill_bindings(
            str(self.database), str(self.maps)), (1, 0))
        self.assertEqual(self.binding("Owner").read_text(), "17")
        self.assertEqual(list(self.binding("Owner").parent.glob(
            ".account-id.tmp.*")), [])

    def test_stdin_execution_runs_main_without_script_path_traversal(self):
        self.add_user(17, "Owner")
        self.add_snapshot(17)

        # Reproduce a root-readable script below a directory that the target
        # account cannot traverse.  The launching shell reads it first; Python
        # receives only stdin and still executes __main__ with argparse.
        blocked_parent = self.root / "root-only"
        blocked_parent.mkdir(mode=0o700)
        blocked_script = blocked_parent / "backfill.py"
        blocked_script.write_text(Path(backfill.__file__).read_text())
        script_input = blocked_script.read_text()
        blocked_parent.chmod(0)
        try:
            if os.geteuid() != 0:
                direct = subprocess.run(
                    [sys.executable, str(blocked_script),
                     "--database", str(self.database),
                     "--maps-dir", str(self.maps)],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    text=True, check=False)
                self.assertNotEqual(direct.returncode, 0)

            via_stdin = subprocess.run(
                [sys.executable, "-", "--database", str(self.database),
                 "--maps-dir", str(self.maps)],
                input=script_input, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE, text=True, check=False)
        finally:
            blocked_parent.chmod(0o700)

        self.assertEqual(via_stdin.returncode, 0, via_stdin.stderr)
        self.assertIn("1 eligible account(s), 1 created", via_stdin.stdout)
        self.assertEqual(self.binding("Owner").read_text(), "17")

    def test_empty_numeric_directory_is_not_bound(self):
        self.add_user(17, "Owner")
        (self.maps / "17").mkdir(parents=True)
        self.assertEqual(backfill.backfill_bindings(
            str(self.database), str(self.maps)), (0, 0))
        self.assertFalse((self.maps / "by-name").exists())

    def test_missing_database_row_fails_closed(self):
        self.add_snapshot(17)
        with self.assertRaisesRegex(backfill.BackfillError, "no account DB row"):
            backfill.backfill_bindings(str(self.database), str(self.maps))
        self.assertFalse((self.maps / "by-name").exists())

    def test_invalid_database_username_fails_closed(self):
        self.add_user(17, "bad-name")
        self.add_snapshot(17)
        with self.assertRaisesRegex(backfill.BackfillError,
                                   "invalid canonical username"):
            backfill.backfill_bindings(str(self.database), str(self.maps))
        self.assertFalse((self.maps / "by-name").exists())

    def test_case_insensitive_database_name_reuse_fails_closed(self):
        self.add_user(17, "Owner")
        self.add_user(18, "OWNER")
        self.add_snapshot(17)
        with self.assertRaisesRegex(backfill.BackfillError, "is ambiguous"):
            backfill.backfill_bindings(str(self.database), str(self.maps))
        self.assertFalse((self.maps / "by-name").exists())

    def test_existing_mismatch_is_never_replaced(self):
        self.add_user(17, "Owner")
        self.add_snapshot(17)
        binding = self.binding("Owner")
        binding.parent.mkdir(parents=True)
        binding.write_text("18")

        with self.assertRaisesRegex(backfill.BackfillError,
                                   "already bound to account 18"):
            backfill.backfill_bindings(str(self.database), str(self.maps))
        self.assertEqual(binding.read_text(), "18")

    def test_all_existing_bindings_are_preflighted_before_writes(self):
        self.add_user(17, "Alpha")
        self.add_user(18, "Beta")
        self.add_snapshot(17)
        self.add_snapshot(18)
        bad = self.binding("Beta")
        bad.parent.mkdir(parents=True)
        bad.write_text("19")

        with self.assertRaises(backfill.BackfillError):
            backfill.backfill_bindings(str(self.database), str(self.maps))
        self.assertFalse(self.binding("Alpha").exists())
        self.assertEqual(bad.read_text(), "19")

    @unittest.skipUnless(hasattr(os, "symlink"), "requires symlinks")
    def test_numeric_account_symlink_fails_closed(self):
        self.maps.mkdir()
        outside = self.root / "outside"
        outside.mkdir()
        (outside / "main.hmap").write_bytes(b"package")
        os.symlink(str(outside), str(self.maps / "17"))

        with self.assertRaisesRegex(backfill.BackfillError,
                                   "not a real directory"):
            backfill.backfill_bindings(str(self.database), str(self.maps))

    @unittest.skipUnless(hasattr(os, "symlink"), "requires symlinks")
    def test_snapshot_symlink_fails_closed(self):
        self.add_user(17, "Owner")
        account = self.maps / "17"
        account.mkdir(parents=True)
        outside = self.root / "outside.hmap"
        outside.write_bytes(b"package")
        os.symlink(str(outside), str(account / "main.hmap"))

        with self.assertRaisesRegex(backfill.BackfillError,
                                   "not a non-empty regular file"):
            backfill.backfill_bindings(str(self.database), str(self.maps))

    @unittest.skipUnless(hasattr(os, "symlink"), "requires symlinks")
    def test_by_name_symlink_fails_closed(self):
        self.add_user(17, "Owner")
        self.add_snapshot(17)
        outside = self.root / "outside"
        outside.mkdir()
        os.symlink(str(outside), str(self.maps / "by-name"))

        with self.assertRaisesRegex(backfill.BackfillError,
                                   "not a real directory"):
            backfill.backfill_bindings(str(self.database), str(self.maps))
        self.assertEqual(list(outside.iterdir()), [])

    @unittest.skipUnless(hasattr(os, "symlink"), "requires symlinks")
    def test_binding_symlink_fails_closed(self):
        self.add_user(17, "Owner")
        self.add_snapshot(17)
        owner = self.binding("Owner").parent
        owner.mkdir(parents=True)
        outside = self.root / "outside-binding"
        outside.write_text("17")
        os.symlink(str(outside), str(owner / ".account-id"))

        with self.assertRaisesRegex(backfill.BackfillError,
                                   "unsafe or inaccessible"):
            backfill.backfill_bindings(str(self.database), str(self.maps))
        self.assertEqual(outside.read_text(), "17")

    def test_noncanonical_numeric_directory_fails_closed(self):
        (self.maps / "017").mkdir(parents=True)
        (self.maps / "017" / "main.hmap").write_bytes(b"package")
        with self.assertRaisesRegex(backfill.BackfillError, "non-canonical"):
            backfill.backfill_bindings(str(self.database), str(self.maps))


if __name__ == "__main__":
    unittest.main()
