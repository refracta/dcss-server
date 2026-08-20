#!/usr/bin/env python3

import os
from pathlib import Path
import subprocess
import unittest


GAME_SCRIPTS = Path(__file__).resolve().parents[1] / "game"
RESOLVER = GAME_SCRIPTS / "resolve-housing-git-ref.sh"
SETUP_CRON = GAME_SCRIPTS / "setup-cron.sh"
INSTALL_VERSIONS = GAME_SCRIPTS / "install-crawl-versions.sh"
COMPOSE_FILE = Path(__file__).resolve().parents[2] / "docker-compose.yml"


class HousingGitRefTest(unittest.TestCase):
    def resolve(self, value=None):
        environment = os.environ.copy()
        if value is None:
            environment.pop("HOUSING_GIT_REF", None)
        else:
            environment["HOUSING_GIT_REF"] = value
        return subprocess.run(
            ["bash", str(RESOLVER)], env=environment,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, check=False)

    def test_unset_and_empty_use_production_default(self):
        self.assertTrue(os.access(RESOLVER, os.X_OK),
                        "Housing ref resolver must be executable")
        for value in (None, ""):
            with self.subTest(value=value):
                result = self.resolve(value)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "housing/housing\n")
                self.assertEqual(result.stderr, "")

    def test_staging_override_is_accepted(self):
        result = self.resolve("housing/housing-staging")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "housing/housing-staging\n")
        self.assertEqual(result.stderr, "")

    def test_invalid_override_fails_closed(self):
        invalid_refs = (
            "housing/master",
            "origin/housing-staging",
            "housing/housing-staging ",
            "housing/housing-staging; touch /tmp/housing-ref-injection",
        )
        for value in invalid_refs:
            with self.subTest(value=value):
                result = self.resolve(value)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, "")
                self.assertIn("HOUSING_GIT_REF must be", result.stderr)

    def test_both_update_paths_use_the_validated_ref(self):
        setup_cron = SETUP_CRON.read_text()
        install_versions = INSTALL_VERSIONS.read_text()

        for source in (setup_cron, install_versions):
            self.assertIn("resolve-housing-git-ref.sh", source)
            self.assertNotIn("update-gcc housing housing/housing", source)

        self.assertIn("update-gcc housing $housing_git_ref", setup_cron)
        self.assertIn('update-gcc housing "$housing_git_ref"',
                      install_versions)

    def test_compose_passes_the_override_into_the_container(self):
        compose = COMPOSE_FILE.read_text()

        self.assertIn("      - HOUSING_GIT_REF\n", compose)


if __name__ == "__main__":
    unittest.main()
