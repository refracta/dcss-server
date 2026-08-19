#!/usr/bin/env python3

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ENTRYPOINT = Path(__file__).resolve().parents[1] / "entrypoint.sh"


class EntrypointTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.scripts = self.root / "scripts"
        (self.scripts / "dgl").mkdir(parents=True)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.init_flag = self.root / "dcss-server-init"
        self.run_marker = self.root / "run-called"
        self.init_marker = self.root / "init-called"
        self.entrypoint = self.root / "entrypoint.sh"
        entrypoint_source = ENTRYPOINT.read_text()
        entrypoint_fixture = entrypoint_source.replace(
            'INIT_FLAG_FILE="/var/run/dcss-server-init"',
            'INIT_FLAG_FILE="%s"' % self.init_flag)
        self.assertNotEqual(entrypoint_fixture, entrypoint_source)
        self.entrypoint.write_text(entrypoint_fixture)
        self.entrypoint.chmod(0o755)

        self.write_script(self.scripts / "dgl/generate-conf.sh", "exit 0")
        self.write_script(self.bin / "dgl", "exit 0")
        self.write_script(self.bin / "git", "exit 0")
        self.write_script(
            self.scripts / "run.sh",
            'touch "$ENTRYPOINT_RUN_MARKER"')

    def tearDown(self):
        self.temporary.cleanup()

    def write_script(self, path, body):
        path.write_text("#!/bin/sh\n%s\n" % body)
        path.chmod(0o755)

    def run_entrypoint(self, cmd=""):
        environment = os.environ.copy()
        environment.update({
            "CMD": cmd,
            "DGL_CHROOT": str(self.root),
            "ENTRYPOINT_INIT_MARKER": str(self.init_marker),
            "ENTRYPOINT_RUN_MARKER": str(self.run_marker),
            "PATH": str(self.bin) + os.pathsep + environment["PATH"],
            "SCRIPTS": str(self.scripts),
        })
        return subprocess.run(
            ["bash", str(self.entrypoint)], env=environment,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, check=False)

    def test_failed_init_creates_no_flag_and_never_runs_services(self):
        self.write_script(
            self.scripts / "init.sh",
            'touch "$ENTRYPOINT_INIT_MARKER"\nexit 42')
        result = self.run_entrypoint()

        self.assertEqual(result.returncode, 1)
        self.assertTrue(self.init_marker.exists())
        self.assertFalse(self.init_flag.exists())
        self.assertFalse(self.run_marker.exists())
        self.assertIn("refusing to start services", result.stderr)

    def test_oneoff_cmd_still_exits_before_init_path(self):
        self.write_script(
            self.scripts / "init.sh",
            'touch "$ENTRYPOINT_INIT_MARKER"\nexit 42')
        oneoff_marker = self.root / "oneoff-called"
        result = self.run_entrypoint("touch %s" % oneoff_marker)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(oneoff_marker.exists())
        self.assertFalse(self.init_marker.exists())
        self.assertFalse(self.init_flag.exists())
        self.assertFalse(self.run_marker.exists())


if __name__ == "__main__":
    unittest.main()
