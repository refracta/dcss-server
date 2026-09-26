#!/usr/bin/env python3

"""Exercise entrypoint lock recovery without starting system services."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


class EntrypointTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.config = self.root / "config"
        self.scripts = self.root / "scripts"
        self.bin = self.root / "bin"
        self.events = self.root / "events"
        self.locks = [
            self.config / "locks/crawl-update.lock",
            self.config / "crawl-build/crawl-git-repository/.git/index.lock",
            self.config / "crawl-build/crawl-git-repository/.git/HEAD.lock",
            self.config / "crawl-build/crawl-git-repository/.git/refs/heads/origin/master.lock",
        ]
        for lock in self.locks:
            lock.parent.mkdir(parents=True, exist_ok=True)
            lock.write_text("stale")

        def executable(path, body):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("#!/bin/bash\nset -eu\n" + body + "\n")
            path.chmod(0o755)

        executable(self.bin / "git", ":")
        executable(self.bin / "dgl", 'echo "dgl:$*" >> "$EVENTS"')
        executable(self.bin / "service", 'echo "service:$*" >> "$EVENTS"')
        executable(self.bin / "sleep", ":")
        executable(self.scripts / "dgl/generate-conf.sh", ":")
        executable(self.scripts / "init.sh", ":")
        executable(self.root / "webtiles", 'echo "webtiles:$*" >> "$EVENTS"')
        executable(
            self.scripts / "run.sh",
            'for lock in "$BUILD_LOCK" "$INDEX_LOCK" "$HEAD_LOCK" "$REF_LOCK"; do\n'
            '    if [ -e "$lock" ]; then echo "run:stale" >> "$EVENTS"; exit 23; fi\n'
            'done\necho "run:clean" >> "$EVENTS"',
        )
        # Simulate an updater still owning locks when shutdown begins.
        executable(
            self.bin / "tail",
            'for lock in "$BUILD_LOCK" "$INDEX_LOCK" "$HEAD_LOCK" "$REF_LOCK"; do\n'
            '    echo active > "$lock"\ndone',
        )

        source = Path(__file__).with_name("entrypoint.sh").read_text()
        # Redirect the two fixed system paths; all commands/services are stubs.
        source = source.replace(
            'INIT_FLAG_FILE="/var/run/dcss-server-init"',
            f'INIT_FLAG_FILE="{self.root}/initialized"',
        ).replace("/etc/init.d/webtiles", str(self.root / "webtiles"))
        self.entrypoint = self.root / "entrypoint.sh"
        self.entrypoint.write_text(source)
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "DGL_CONF_HOME": str(self.config),
            "DGL_CHROOT": str(self.root / "chroot"),
            "SCRIPTS": str(self.scripts),
            "EVENTS": str(self.events),
            "BUILD_LOCK": str(self.locks[0]),
            "INDEX_LOCK": str(self.locks[1]),
            "HEAD_LOCK": str(self.locks[2]),
            "REF_LOCK": str(self.locks[3]),
            "CMD": "",
        }

    def run_entrypoint(self, cmd=""):
        return subprocess.run(
            ["bash", str(self.entrypoint)],
            env={**self.env, "CMD": cmd},
            capture_output=True,
            text=True,
            timeout=10,
        )

    def test_restart_recovers_stale_locks_and_keeps_shutdown_locks(self):
        unrelated = self.locks[2].with_name("unrelated.lock")
        unrelated.write_text("keep")
        for _ in range(2):
            result = self.run_entrypoint()
            self.assertEqual(result.returncode, 0, result.stderr)
            events = self.events.read_text().splitlines()
            self.assertIn("run:clean", events)
            self.assertNotIn("run:stale", events)
            self.assertLess(events.index("service:cron stop"), events.index("service:ssh stop"))
            for lock in self.locks:
                self.assertEqual(lock.read_text().strip(), "active")
            self.assertEqual(unrelated.read_text(), "keep")
            self.events.unlink()

    def test_one_off_command_keeps_existing_locks(self):
        result = self.run_entrypoint('echo "cmd:ran" >> "$EVENTS"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("cmd:ran", self.events.read_text())
        self.assertNotIn("service:", self.events.read_text())
        for lock in self.locks:
            self.assertEqual(lock.read_text(), "stale")

    def test_cleanup_failure_stops_before_initialization(self):
        self.locks[2].unlink()
        self.locks[2].mkdir()
        result = self.run_entrypoint()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.events.exists())


if __name__ == "__main__":
    unittest.main()
