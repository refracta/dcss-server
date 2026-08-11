#!/usr/bin/env python3

"""Fixture tests for update_cnc_dwem_modules.py."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

if __package__:
    from . import update_cnc_dwem_modules as updater
else:
    import update_cnc_dwem_modules as updater


PREFIX = "<!doctype html>\n<html>\n  <body>\n    "
SUFFIX = """
      const socket_server = {{ socket_server }};
      const game_version = {{ game_version }};
      keepThisCall();
    </script>
  </body>
</html>
"""


def legacy_block(modules):
    return "\n".join(
        (
            '<script  type="text/javascript">',
            '      localStorage.removeItem("DWEM");',
            "      localStorage.DWEM_MODULES = JSON.stringify(",
            f'        {json.dumps(modules)}.map('
            'm => "../modules/" + m + "/index.js")',
            "      );",
        )
    )


class UpdateCncDwemModulesTest(unittest.TestCase):
    def update_fixture(self, contents):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "client.html"
            path.write_text(contents, encoding="utf-8", newline="")
            updater.update_template(path)
            return path.read_bytes()

    def test_pristine_template(self):
        result = self.update_fixture(PREFIX + updater.SCRIPT_TAG + SUFFIX).decode()
        self.assertEqual(
            result,
            PREFIX + updater.render_block("\n") + SUFFIX,
        )

    def test_old_patched_template(self):
        for omitted in (
            {"cnc-event", "map-predictor"},
            {"map-predictor"},
        ):
            with self.subTest(omitted=omitted):
                old_modules = tuple(
                    module
                    for module in updater.DWEM_MODULES
                    if module not in omitted
                )
                result = self.update_fixture(
                    PREFIX + legacy_block(old_modules) + SUFFIX
                ).decode()
                self.assertEqual(
                    result, PREFIX + updater.render_block("\n") + SUFFIX
                )
                self.assertIn('"cnc-event"', result)
                self.assertIn('"map-predictor"', result)

    def test_current_patched_template(self):
        result = self.update_fixture(
            PREFIX + legacy_block(updater.DWEM_MODULES) + SUFFIX
        )
        self.assertEqual(
            result.decode(), PREFIX + updater.render_block("\n") + SUFFIX
        )

    def test_second_run_is_byte_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "client.html"
            path.write_text(PREFIX + updater.SCRIPT_TAG + SUFFIX, encoding="utf-8")
            updater.update_template(path)
            first_run = path.read_bytes()
            updater.update_template(path)
            self.assertEqual(path.read_bytes(), first_run)

    def test_unknown_template_fails_without_modifying_it(self):
        contents = (
            PREFIX
            + updater.SCRIPT_TAG
            + "\n      unrelatedCall();\n    </script>\n  </body>\n</html>\n"
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "client.html"
            path.write_text(contents, encoding="utf-8")
            before = path.read_bytes()
            with self.assertRaisesRegex(
                updater.TemplateUpdateError,
                "expected one Webtiles configuration script",
            ):
                updater.update_template(path)
            self.assertEqual(path.read_bytes(), before)

    def test_other_typed_script_is_preserved(self):
        unrelated = (
            '<script type="text/javascript">\n'
            "      unrelatedCall();\n"
            "    </script>\n    "
        )
        result = self.update_fixture(
            PREFIX + unrelated + updater.SCRIPT_TAG + SUFFIX
        ).decode()
        self.assertEqual(
            result,
            PREFIX + unrelated + updater.render_block("\n") + SUFFIX,
        )

    def test_duplicate_dwem_assignment_is_rejected(self):
        duplicate = (
            PREFIX
            + legacy_block(updater.DWEM_MODULES)
            + SUFFIX
            + '<script type="text/javascript">\n'
            + "localStorage.DWEM_MODULES = 'custom';\n</script>\n"
        )
        with self.assertRaisesRegex(
            updater.TemplateUpdateError, "outside the known block"
        ):
            updater.updated_contents(duplicate)

    def test_setup_script_propagates_an_unknown_template_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config_home = root / "config"
            webdir = root / "web"
            source_webserver = config_home / "server" / "etc" / "webserver"
            source_webserver.mkdir(parents=True)
            (source_webserver / "placeholder").write_text(
                "fixture", encoding="utf-8"
            )
            webdir.mkdir()
            (webdir / "templates").mkdir()
            (webdir / "templates" / "client.html").write_text(
                PREFIX + updater.SCRIPT_TAG + "\n</script>\n",
                encoding="utf-8",
            )
            (config_home / "config.py").write_text(
                "# CONFIG_MORGUE_URL\n# CONFIG_SERVER_ID\n",
                encoding="utf-8",
            )
            (config_home / "dgl-manage.conf").write_text(
                f"# CONFIG_DGL_SERVER\n# CONFIG_WEB_SAVEDUMP_URL\nWEBDIR={webdir}\n",
                encoding="utf-8",
            )
            environment = os.environ.copy()
            environment["DGL_CONF_HOME"] = str(config_home)
            setup_script = Path(__file__).with_name("setup-cnc-config.sh")

            result = subprocess.run(
                ["bash", str(setup_script)],
                env=environment,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 1)
            self.assertIn("expected one Webtiles configuration script", result.stderr)


if __name__ == "__main__":
    unittest.main()
