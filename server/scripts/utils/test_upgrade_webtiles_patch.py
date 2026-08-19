#!/usr/bin/env python3

import difflib
import pathlib
import subprocess
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).with_name("upgrade_webtiles_patch.sh")

BASE = """import os

import webtiles
from webtiles import auth
from webtiles import game_data_handler, util


def start():
    util.start()
"""

WITH_SITE = BASE.replace(
    "from webtiles import game_data_handler, util",
    "from webtiles import game_data_handler, server_metrics, util")
WITH_SITE_2 = WITH_SITE.replace(
    "game_data_handler, server_metrics, util",
    "game_data_handler, server_metrics, status_metrics, util")
WITH_LEGACY = BASE.replace(
    "import webtiles\n",
    "import webtiles\nfrom webtiles import housing_session\n")
WITH_CURRENT = WITH_LEGACY.replace(
    "def start():\n",
    "def start():\n    housing_session.cleanup_stale_sessions()\n")


def patch_text(before, after, context=3):
    return "".join(difflib.unified_diff(
        before.splitlines(True), after.splitlines(True),
        fromfile="webtiles/server.py", tofile="webtiles/server.py",
        n=context))


class UpgradeWebtilesPatchTest(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tempdir.name)
        self.webdir = self.root / "webserver"
        (self.webdir / "webtiles").mkdir(parents=True)
        self.source = self.webdir / "webtiles/server.py"
        self.source.write_text(BASE)
        self.site = self.root / "site.patch"
        self.site.write_text(patch_text(BASE, WITH_SITE))
        self.site_2 = self.root / "site-2.patch"
        self.site_2.write_text(patch_text(WITH_SITE, WITH_SITE_2))
        self.current = self.root / "housing-session.patch"
        self.current.write_text(patch_text(BASE, WITH_CURRENT, context=1))
        self.migrations = self.root / "migrations"
        self.migrations.mkdir()
        self.legacy = self.migrations / "housing-session-legacy.patch"
        self.legacy.write_text(patch_text(BASE, WITH_LEGACY, context=1))

    def tearDown(self):
        self.tempdir.cleanup()

    def patch(self, patch_file, reverse=False, dry_run=False):
        command = ["patch",
                   "--force" if reverse else "--batch",
                   "--fuzz=0", "-d", str(self.webdir)]
        if dry_run:
            command.append("--dry-run")
        command.append("--reverse" if reverse else "--forward")
        command.extend(["-p0", "-i", str(patch_file)])
        return subprocess.run(command, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, text=True, check=False)

    def upgrade(self):
        return subprocess.run(
            ["bash", str(SCRIPT), str(self.webdir), str(self.current),
             str(self.migrations), str(self.site), str(self.site_2)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            check=False)

    def assert_current_stack(self):
        self.assertEqual(self.patch(self.current, reverse=True,
                                    dry_run=True).returncode, 0)
        self.assertEqual(self.patch(self.current, reverse=True).returncode, 0)
        self.assertEqual(self.patch(self.site_2, reverse=True,
                                    dry_run=True).returncode, 0)
        self.assertEqual(self.patch(self.site_2, reverse=True).returncode, 0)
        self.assertEqual(self.patch(self.site, reverse=True,
                                    dry_run=True).returncode, 0)
        self.assertEqual(self.patch(self.site, reverse=True).returncode, 0)
        self.assertEqual(self.patch(self.site).returncode, 0)
        self.assertEqual(self.patch(self.site_2).returncode, 0)
        self.assertEqual(self.patch(self.current).returncode, 0)

    def test_pristine_installs_site_then_current(self):
        self.assertEqual(self.upgrade().returncode, 0)
        self.assert_current_stack()

    def test_legacy_stack_upgrades_to_current(self):
        self.assertEqual(self.patch(self.site).returncode, 0)
        self.assertEqual(self.patch(self.site_2).returncode, 0)
        self.assertEqual(self.patch(self.legacy).returncode, 0)
        self.assertNotEqual(self.patch(self.site, reverse=True,
                                       dry_run=True).returncode, 0)
        self.assertEqual(self.upgrade().returncode, 0)
        self.assert_current_stack()

    def test_current_stack_is_idempotent(self):
        self.assertEqual(self.upgrade().returncode, 0)
        before = self.source.read_text()
        self.assertEqual(self.upgrade().returncode, 0)
        self.assertEqual(self.source.read_text(), before)
        self.assert_current_stack()

    def test_new_site_patch_can_be_inserted_below_current(self):
        self.assertEqual(self.patch(self.current).returncode, 0)
        self.assertEqual(self.upgrade().returncode, 0)
        self.assert_current_stack()

    def test_partial_state_fails_before_mutating_live_tree(self):
        self.assertEqual(self.patch(self.legacy).returncode, 0)
        self.source.write_text(self.source.read_text().replace(
            "game_data_handler, util", "game_data_handler, broken, util"))
        before = self.source.read_text()
        self.assertNotEqual(self.upgrade().returncode, 0)
        self.assertEqual(self.source.read_text(), before)


if __name__ == "__main__":
    unittest.main()
