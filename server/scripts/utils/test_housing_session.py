#!/usr/bin/env python3

import collections
import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import types
import unittest
from unittest import mock


HERE = pathlib.Path(__file__).resolve()
REPO_ROOT = HERE.parents[3]
HELPER = REPO_ROOT / "server/etc/webserver/webtiles/housing_session.py"
PATCH = REPO_ROOT / "server/etc/webserver-patches/housing-session.patch"
LAUNCHER = REPO_ROOT / "chroot/bin/crawl-stable-launcher.sh"
SETUP = REPO_ROOT / "server/scripts/utils/setup-cnc-config.sh"
UPGRADE_PATCH = REPO_ROOT / "server/scripts/utils/upgrade_webtiles_patch.sh"
LEGACY_PATCH = (REPO_ROOT
                / "server/etc/webserver-patch-migrations"
                / "housing-session-a21765d.patch")

UserInfo = collections.namedtuple("UserInfo", "id username email flags")


class FakeConfig(object):
    def __init__(self, values):
        self.values = values

    def get(self, name):
        return self.values.get(name)


class FakeUserDB(object):
    def __init__(self):
        self.users = {
            "alice": UserInfo(1, "Alice", None, 0),
            "bob": UserInfo(2, "Bob", None, 0),
            "carol": UserInfo(3, "Carol", None, 0),
        }

    def get_user_info(self, username):
        if not isinstance(username, str):
            return None
        return self.users.get(username.lower())


def load_helper(config, userdb):
    webtiles = types.ModuleType("webtiles")
    webtiles.config = config
    webtiles.userdb = userdb
    old_webtiles = sys.modules.get("webtiles")
    sys.modules["webtiles"] = webtiles
    try:
        spec = importlib.util.spec_from_file_location(
            "housing_session_under_test", str(HELPER))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        if old_webtiles is None:
            del sys.modules["webtiles"]
        else:
            sys.modules["webtiles"] = old_webtiles


def load_added_patch_method(method_name, namespace=None):
    """Compile one self-contained method directly from the overlay patch."""
    marker = "+    def %s(" % method_name
    method_lines = []
    collecting = False
    for line in PATCH.read_text().splitlines():
        if line.startswith(marker):
            collecting = True
        elif (collecting and line.startswith("+    def ")
              and not line.startswith(marker)):
            break
        elif collecting and not line.startswith("+"):
            break
        if collecting:
            method_lines.append(line[1:])
    if not method_lines:
        raise AssertionError("Missing patched method %s" % method_name)
    namespace = dict(namespace or {})
    source = "class PatchedClass(object):\n" + "\n".join(method_lines)
    exec(compile(source, str(PATCH), "exec"), namespace)
    return getattr(namespace["PatchedClass"], method_name)


class HousingSessionTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary.name)
        self.saves = self.root / "housing"
        self.maps = self.root / "housing-maps"
        self.sessions = self.root / "housing-sessions"
        self.saves.mkdir()
        self.maps.mkdir()
        self.sessions.mkdir(mode=0o700)
        values = {
            "housing_save_dir": str(self.saves),
            "housing_maps_dir": str(self.maps),
            "housing_sessions_dir": str(self.sessions),
        }
        self.config = FakeConfig(values)
        self.userdb = FakeUserDB()
        self.housing = load_helper(self.config, self.userdb)

    def tearDown(self):
        self.temporary.cleanup()

    def write_save(self, data=b"canonical-character"):
        (self.saves / "Alice.cs").write_bytes(data)

    def write_map(self, account_id=2, map_id="main", data=b"map-one"):
        directory = self.maps / str(account_id)
        directory.mkdir(exist_ok=True)
        path = directory / (map_id + ".hmap")
        path.write_bytes(data)
        return path

    def visitor(self, target="Bob:main"):
        return self.housing.prepare_launch("alice", 1, target)

    def run_patch_upgrade(self, state, current_text="current\n",
                          current_from="base"):
        fixture_root = pathlib.Path(tempfile.mkdtemp(
            prefix="patch-upgrade-", dir=str(self.root)))
        webdir = fixture_root / "patch-fixture"
        target = webdir / "webtiles/demo.txt"
        target.parent.mkdir(parents=True)
        target.write_text(state)
        current = fixture_root / "housing-session-current.patch"
        current.write_text(
            "--- webtiles/demo.txt\n"
            "+++ webtiles/demo.txt\n"
            "@@ -1 +1 @@\n"
            "-" + current_from + "\n"
            "+" + current_text)
        migrations = fixture_root / "patch-migrations"
        migrations.mkdir()
        (migrations / "housing-session-legacy.patch").write_text(
            "--- webtiles/demo.txt\n"
            "+++ webtiles/demo.txt\n"
            "@@ -1 +1 @@\n"
            "-base\n"
            "+legacy\n")
        result = subprocess.run(
            [str(UPGRADE_PATCH), str(webdir), str(current), str(migrations)],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return result, target.read_text()

    def test_webtiles_patch_upgrade_accepts_pristine_legacy_and_current(self):
        for state in ("base\n", "legacy\n", "current\n"):
            with self.subTest(state=state):
                result, installed = self.run_patch_upgrade(state)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(installed, "current\n")

    def test_webtiles_patch_upgrade_rejects_unknown_partial_state(self):
        result, installed = self.run_patch_upgrade("partial\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(installed, "partial\n")
        self.assertIn("unknown or partially applied", result.stderr)

    def test_webtiles_patch_upgrade_restores_legacy_when_current_is_incompatible(self):
        result, installed = self.run_patch_upgrade(
            "legacy\n", current_from="different-base")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(installed, "legacy\n")
        self.assertIn("does not apply after legacy removal", result.stderr)

    def test_target_syntax_and_query_cardinality(self):
        self.assertEqual(
            self.housing.validate_url_targets(
                ["ASCIIPhilia:this_is_test_MAP07"]),
            ("ASCIIPhilia", "this_is_test_MAP07"))
        invalid = [
            [],
            ["Bob:main", "Carol:main"],
            ["Böb:main"],
            ["Bob:../main"],
            ["Bob:main/other"],
            ["Bob:main:other"],
            ["Bob:"],
            ["_Bob:main"],
            ["Bob:" + "x" * 21],
        ]
        for values in invalid:
            with self.subTest(values=values):
                with self.assertRaises(self.housing.HousingSessionError):
                    self.housing.validate_url_targets(values)

    def test_display_place_prefers_only_a_nonempty_housing_label(self):
        standard = {"place": "D:1"}
        self.assertEqual(self.housing.display_place(standard), "D:1")
        self.assertEqual(standard, {"place": "D:1"})
        self.assertEqual(
            self.housing.display_place({
                "place": "D:1",
                "housing_place": "Bob:gallery",
            }),
            "Bob:gallery")
        self.assertEqual(
            self.housing.display_place({
                "place": "D:1",
                "housing_place": "",
            }),
            "D:1")
        self.assertEqual(
            self.housing.display_place({
                "place": "D:1",
                "housing_place": 17,
            }),
            "D:1")

    def test_self_target_is_canonical_owner_without_a_temp_session(self):
        launch = self.housing.prepare_launch("Alice", 1, "aLiCe:any_map")
        self.assertEqual(launch.role, "owner")
        self.assertIsNone(launch.session)
        self.assertEqual(launch.command_args(), [])
        self.assertEqual(launch.rc_path("/canonical/Alice.rc"),
                         "/canonical/Alice.rc")
        self.assertEqual(launch.macro_path("/canonical/Alice.macro"),
                         "/canonical/Alice.macro")
        self.assertEqual(launch.morgue_path("/canonical/morgue"),
                         "/canonical/morgue")
        environment = launch.environment()
        self.assertEqual(environment["CRAWL_HOUSING_ACCOUNT_ID"], "1")
        self.assertEqual(environment["CRAWL_HOUSING_MAP_ID"], "main")
        self.assertEqual(
            environment["CRAWL_HOUSING_CANONICAL_SAVE"],
            str(self.saves / "Alice.cs"))
        self.assertEqual(
            environment["CRAWL_HOUSING_CANONICAL_RC"],
            "/canonical/Alice.rc")
        self.assertEqual(
            environment["CRAWL_HOUSING_CANONICAL_MACRO"],
            "/canonical/Alice.macro")
        self.assertEqual(
            environment["CRAWL_HOUSING_CANONICAL_MORGUE"],
            "/canonical/morgue")
        self.assertEqual(list(self.sessions.iterdir()), [])

    def test_visit_requires_own_character_and_target_snapshot(self):
        self.write_map()
        with self.assertRaisesRegex(
                self.housing.HousingSessionError,
                "Create a Housing character"):
            self.visitor()

        self.write_save()
        (self.maps / "2" / "main.hmap").unlink()
        with self.assertRaisesRegex(self.housing.HousingSessionError,
                                    "map is unavailable"):
            self.visitor()
        self.assertEqual(list(self.sessions.iterdir()), [])

    def test_snapshot_parent_symlink_is_rejected(self):
        self.write_save()
        outside = self.root / "outside-maps"
        outside.mkdir()
        (outside / "main.hmap").write_bytes(b"not-public")
        (self.maps / "2").symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(self.housing.HousingSessionError,
                                    "map is unavailable"):
            self.visitor()
        self.assertEqual(list(self.sessions.iterdir()), [])

    def test_visitor_uses_new_inodes_and_private_runtime_paths(self):
        self.write_save()
        source_map = self.write_map()
        launch = self.visitor("bOb:main")
        self.addCleanup(launch.cleanup)

        expected_save = pathlib.Path(launch.path) / "saves/housing/Alice.cs"
        self.assertEqual(expected_save.read_bytes(), b"canonical-character")
        self.assertNotEqual(expected_save.stat().st_ino,
                            (self.saves / "Alice.cs").stat().st_ino)
        self.assertEqual(pathlib.Path(launch.snapshot_path).read_bytes(),
                         source_map.read_bytes())
        self.assertNotEqual(pathlib.Path(launch.snapshot_path).stat().st_ino,
                            source_map.stat().st_ino)

        macro = self.root / "Alice.macro"
        macro.write_bytes(b"macro")
        isolated_macro = pathlib.Path(launch.macro_path(str(macro)))
        self.assertEqual(isolated_macro.read_bytes(), b"macro")
        self.assertNotEqual(isolated_macro.stat().st_ino, macro.stat().st_ino)
        canonical_morgue = self.root / "canonical-morgue"
        canonical_morgue.mkdir()
        self.assertEqual(launch.morgue_path(str(canonical_morgue)),
                         launch.morgue_dir)

        canonical_rc_dir = self.root / "canonical-rc"
        canonical_rc_dir.mkdir()
        rc = canonical_rc_dir / "Alice.rc"
        rc.write_bytes(b"include = sibling.rc\n")
        sibling_rc = canonical_rc_dir / "sibling.rc"
        sibling_rc.write_bytes(b"show_more = false\n")
        canonical_persist = pathlib.Path(str(rc) + ".persist")
        canonical_persist.write_bytes(b"canonical persist")
        isolated_rc = pathlib.Path(launch.rc_path(str(rc)))
        self.assertEqual(isolated_rc.read_bytes(), b"include = sibling.rc\n")
        self.assertNotEqual(isolated_rc.stat().st_ino, rc.stat().st_ino)
        self.assertEqual(
            launch.command_args(),
            ["-dir", str(pathlib.Path(launch.path) / "saves"),
             "-rcdir", str(canonical_rc_dir)])
        # Crawl first checks the temp main rc's directory, then each -rcdir.
        # Keeping sibling.rc only in the canonical directory exercises the
        # latter contract without copying arbitrary include files to a session.
        self.assertFalse((isolated_rc.parent / "sibling.rc").exists())
        self.assertEqual(sibling_rc.read_bytes(), b"show_more = false\n")
        isolated_persist = pathlib.Path(str(isolated_rc) + ".persist")
        self.assertFalse(isolated_persist.exists())
        isolated_persist.write_bytes(b"visitor persist")
        self.assertEqual(canonical_persist.read_bytes(), b"canonical persist")
        self.assertTrue(str(isolated_persist).startswith(launch.path + os.sep))

        env = launch.environment()
        self.assertEqual(env["CRAWL_HOUSING_ROLE"], "visitor")
        self.assertEqual(env["CRAWL_HOUSING_TARGET_ACCOUNT_ID"], "2")
        self.assertEqual(env["CRAWL_HOUSING_TARGET_OWNER"], "Bob")
        self.assertEqual(env["CRAWL_HOUSING_TARGET_MAP_ID"], "main")
        self.assertEqual(env["CRAWL_HOUSING_SESSION_DIR"], launch.path)
        self.assertEqual(env["CRAWL_HOUSING_SNAPSHOT"], launch.snapshot_path)
        self.assertEqual(env["CRAWL_HOUSING_CANONICAL_SAVE"],
                         str(self.saves / "Alice.cs"))
        self.assertEqual(env["CRAWL_HOUSING_CANONICAL_RC"], str(rc))
        self.assertEqual(env["CRAWL_HOUSING_CANONICAL_MACRO"], str(macro))
        self.assertEqual(env["CRAWL_HOUSING_CANONICAL_MORGUE"],
                         str(canonical_morgue))

    def test_exclusive_canonical_lock_blocks_clone(self):
        self.write_save()
        self.write_map()
        ready_read, ready_write = os.pipe()
        release_read, release_write = os.pipe()
        pid = os.fork()
        if pid == 0:
            try:
                os.close(ready_read)
                os.close(release_write)
                import fcntl
                with open(self.saves / "Alice.cs", "r+b") as source:
                    fcntl.lockf(source.fileno(), fcntl.LOCK_EX)
                    os.write(ready_write, b"1")
                    os.read(release_read, 1)
            finally:
                os._exit(0)

        os.close(ready_write)
        os.close(release_read)
        try:
            self.assertEqual(os.read(ready_read, 1), b"1")
            with self.assertRaisesRegex(self.housing.HousingSessionError,
                                        "currently in use"):
                self.visitor()
        finally:
            try:
                os.write(release_write, b"1")
            except BrokenPipeError:
                pass
            os.close(ready_read)
            os.close(release_write)
            os.waitpid(pid, 0)

    def test_visitor_transition_keeps_character_and_replaces_only_snapshot(self):
        self.write_save()
        self.write_map(data=b"bob-map")
        self.write_map(account_id=3, map_id="garden", data=b"carol-map")
        session = self.visitor()
        self.addCleanup(session.cleanup)
        save_path = pathlib.Path(session.save_path)
        save_path.write_bytes(b"visitor-progress")
        save_inode = save_path.stat().st_ino
        old_snapshot_inode = pathlib.Path(session.snapshot_path).stat().st_ino
        rc_dir = self.root / "transition-rc"
        rc_dir.mkdir()
        canonical_rc = rc_dir / "Alice.rc"
        canonical_rc.write_bytes(b"include = sibling.rc\n")
        isolated_rc = pathlib.Path(session.rc_path(str(canonical_rc)))
        isolated_persist = pathlib.Path(str(isolated_rc) + ".persist")
        isolated_persist.write_bytes(b"visitor preferences")
        canonical_macro = self.root / "Alice.macro"
        canonical_macro.write_bytes(b"macro")
        isolated_macro = session.macro_path(str(canonical_macro))
        canonical_morgue = self.root / "transition-morgue"
        canonical_morgue.mkdir()
        isolated_morgue = session.morgue_path(str(canonical_morgue))
        original_canonical_environment = {
            key: value for key, value in session.environment().items()
            if key.startswith("CRAWL_HOUSING_CANONICAL_")
        }
        replacement_saves = self.root / "replacement-housing"
        replacement_saves.mkdir()
        self.config.values["housing_save_dir"] = str(replacement_saves)

        reused = self.housing.prepare_launch(
            "Alice", 1, "cArOl:garden", existing_session=session)
        self.assertIs(reused, session)
        self.assertEqual(save_path.read_bytes(), b"visitor-progress")
        self.assertEqual(save_path.stat().st_ino, save_inode)
        self.assertEqual(pathlib.Path(session.snapshot_path).read_bytes(),
                         b"carol-map")
        self.assertNotEqual(pathlib.Path(session.snapshot_path).stat().st_ino,
                            old_snapshot_inode)
        self.assertEqual(session.environment()["CRAWL_HOUSING_TARGET_ACCOUNT_ID"],
                         "3")
        self.assertEqual(session.environment()["CRAWL_HOUSING_TARGET_MAP_ID"],
                         "garden")
        self.assertEqual(reused.rc_path(str(canonical_rc)), str(isolated_rc))
        self.assertEqual(reused.macro_path(str(canonical_macro)),
                         isolated_macro)
        self.assertEqual(reused.morgue_path(str(canonical_morgue)),
                         isolated_morgue)
        self.assertEqual(isolated_persist.read_bytes(), b"visitor preferences")
        self.assertFalse(pathlib.Path(str(canonical_rc) + ".persist").exists())
        self.assertEqual(
            {key: value for key, value in reused.environment().items()
             if key.startswith("CRAWL_HOUSING_CANONICAL_")},
            original_canonical_environment)

    def test_canonical_runtime_paths_are_pinned_and_server_owned(self):
        self.write_save()
        self.write_map()
        session = self.visitor()
        self.addCleanup(session.cleanup)

        for invalid in (
                "relative/Alice.rc",
                str(self.root / "Mallory.rc"),
                str(pathlib.Path(session.path) / "nested/Alice.rc")):
            with self.subTest(invalid=invalid):
                with self.assertRaisesRegex(
                        self.housing.HousingSessionError,
                        "temporarily unavailable"):
                    session.rc_path(invalid)

        canonical_rc = self.root / "Alice.rc"
        canonical_rc.write_bytes(b"")
        session.rc_path(str(canonical_rc))
        other_rc = self.root / "other" / "Alice.rc"
        with self.assertRaisesRegex(self.housing.HousingSessionError,
                                    "temporarily unavailable"):
            session.rc_path(str(other_rc))

        with self.assertRaisesRegex(self.housing.HousingSessionError,
                                    "temporarily unavailable"):
            session.macro_path(str(self.root / "Bob.macro"))
        with self.assertRaisesRegex(self.housing.HousingSessionError,
                                    "temporarily unavailable"):
            session.morgue_path(str(pathlib.Path(session.path) / "morgue"))

        self.assertEqual(session.canonical_save_path,
                         str(self.saves / "Alice.cs"))
        self.assertFalse(session.canonical_save_path.startswith(
            session.path + os.sep))

    def test_return_to_owner_discards_entire_session(self):
        self.write_save()
        self.write_map()
        session = self.visitor()
        session_path = pathlib.Path(session.path)
        owner = self.housing.prepare_launch(
            "Alice", 1, "ALICE:main", existing_session=session)
        self.assertEqual(owner.role, "owner")
        self.assertFalse(session_path.exists())

    def test_owner_launch_waits_for_successful_session_cleanup(self):
        self.write_save()
        self.write_map()
        session = self.visitor()
        session_path = pathlib.Path(session.path)
        real_rmtree = self.housing.shutil.rmtree
        calls = []

        def fail_once(path):
            calls.append(path)
            if len(calls) == 1:
                raise OSError("temporary failure")
            return real_rmtree(path)

        with mock.patch.object(self.housing.shutil, "rmtree",
                               side_effect=fail_once), \
                mock.patch.object(self.housing.logging, "warning"):
            with self.assertRaisesRegex(self.housing.HousingSessionError,
                                        "temporarily unavailable"):
                self.housing.prepare_launch(
                    "Alice", 1, None, existing_session=session)
            self.assertTrue(session_path.exists())
            self.assertFalse(session._cleaned)
            self.assertIs(
                self.housing._cleanup_retry_sessions[session.path], session)

            owner = self.housing.prepare_launch(
                "Alice", 1, None, existing_session=session)

        self.assertEqual(owner.role, "owner")
        self.assertFalse(session_path.exists())
        self.assertTrue(session._cleaned)
        self.assertNotIn(session.path,
                         self.housing._cleanup_retry_sessions)

    def test_failed_create_cleanup_is_retained_for_periodic_retry(self):
        self.write_save()
        real_rmtree = self.housing.shutil.rmtree
        calls = []

        def fail_once(path):
            calls.append(path)
            if len(calls) == 1:
                raise OSError("temporary failure")
            return real_rmtree(path)

        with mock.patch.object(self.housing.shutil, "rmtree",
                               side_effect=fail_once), \
                mock.patch.object(self.housing.logging, "warning"):
            with self.assertRaisesRegex(self.housing.HousingSessionError,
                                        "map is unavailable"):
                self.visitor()
            self.assertEqual(len(self.housing._cleanup_retry_sessions), 1)
            retained = next(iter(
                self.housing._cleanup_retry_sessions.values()))
            self.assertTrue(pathlib.Path(retained.path).exists())
            self.assertEqual(self.housing.retry_failed_cleanups(), 1)

        self.assertFalse(pathlib.Path(retained.path).exists())
        self.assertEqual(self.housing._cleanup_retry_sessions, {})

    def test_pending_launch_without_child_pid_survives_periodic_audit(self):
        self.write_save()
        self.write_map()
        session = self.visitor()
        session_path = pathlib.Path(session.path)
        self.assertIsNone(session.pid)
        self.assertIs(self.housing._live_sessions[session.path], session)

        # Force the periodic callback down its full root-audit path.  A newly
        # prepared launch can legitimately have no child pid yet.
        self.housing._session_root_audit_ok = False
        self.assertEqual(self.housing.retry_failed_cleanups(), 0)
        self.assertTrue(session_path.exists())
        self.assertIs(self.housing._live_sessions[session.path], session)

        # set_pid happens before the child reaches execvpe and receives its
        # Housing environment.  The current-process registry, not /proc, owns
        # this short pre-exec window.
        session.set_pid(os.getpid())
        self.housing._session_root_audit_ok = False
        with mock.patch.object(self.housing, "_pid_owns_session",
                               return_value=False) as owns_session:
            self.assertEqual(self.housing.retry_failed_cleanups(), 0)
            owns_session.assert_not_called()
        self.assertTrue(session_path.exists())

        self.assertTrue(session.cleanup())
        self.assertFalse(session_path.exists())
        self.assertNotIn(session.path, self.housing._live_sessions)

    def test_ws_cleanup_caller_retains_reference_until_retry_succeeds(self):
        self.write_save()
        self.write_map()
        session = self.visitor()
        session_path = pathlib.Path(session.path)
        cleanup_method = load_added_patch_method(
            "_cleanup_housing_session")
        socket = types.SimpleNamespace(housing_session=session)
        real_rmtree = self.housing.shutil.rmtree
        calls = []

        def fail_once(path):
            calls.append(path)
            if len(calls) == 1:
                raise OSError("temporary failure")
            return real_rmtree(path)

        with mock.patch.object(self.housing.shutil, "rmtree",
                               side_effect=fail_once), \
                mock.patch.object(self.housing.logging, "warning"):
            self.assertFalse(cleanup_method(socket))
            self.assertIs(socket.housing_session, session)
            self.assertTrue(session_path.exists())

            self.assertTrue(cleanup_method(socket))
            self.assertIsNone(socket.housing_session)

        self.assertFalse(session_path.exists())

    def test_pending_cleanup_blocks_a_second_socket_for_same_account(self):
        self.write_save()
        self.write_map()
        session = self.visitor()
        session_path = pathlib.Path(session.path)
        with mock.patch.object(
                self.housing.shutil, "rmtree",
                side_effect=OSError("persistent failure")), \
                mock.patch.object(self.housing.logging, "warning"):
            self.assertFalse(session.cleanup())
            for target in (None, "Bob:main"):
                with self.subTest(target=target):
                    with self.assertRaisesRegex(
                            self.housing.HousingSessionError,
                            "temporarily unavailable"):
                        self.housing.prepare_launch("Alice", 1, target)
            self.assertTrue(session_path.exists())
            self.assertIs(
                self.housing._cleanup_retry_sessions[session.path], session)

        owner = self.housing.prepare_launch("Alice", 1, None)
        self.assertEqual(owner.role, "owner")
        self.assertFalse(session_path.exists())
        self.assertNotIn(session.path,
                         self.housing._cleanup_retry_sessions)

    def test_active_visitor_blocks_a_second_socket_for_same_account(self):
        self.write_save()
        self.write_map()
        session = self.visitor()
        self.addCleanup(session.cleanup)
        for target in (None, "Bob:main"):
            with self.subTest(target=target):
                with self.assertRaisesRegex(
                        self.housing.HousingSessionError,
                        "temporarily unavailable"):
                    self.housing.prepare_launch("Alice", 1, target)

    def test_process_revalidates_delayed_owner_context_before_fork(self):
        self.write_save()
        self.write_map()
        delayed_owner = self.housing.prepare_launch("Alice", 1, None)
        active_visitor = self.visitor()
        self.addCleanup(active_visitor.cleanup)

        with self.assertRaisesRegex(self.housing.HousingSessionError,
                                    "temporarily unavailable"):
            self.housing.validate_before_start(delayed_owner)

        validate_method = load_added_patch_method(
            "_validate_housing_launch",
            {"housing_session": self.housing})
        ended = []
        handler = types.SimpleNamespace(
            launch_context=delayed_owner,
            logger=mock.Mock(),
            exit_reason=None,
            exit_message=None,
            exit_dump_url="unchanged",
            handle_process_end=lambda: ended.append(True))
        self.assertFalse(validate_method(handler))
        self.assertEqual(handler.exit_reason, "error")
        self.assertEqual(handler.exit_message,
                         "Housing is temporarily unavailable.")
        self.assertIsNone(handler.exit_dump_url)
        self.assertEqual(ended, [True])

    def test_visitor_prestart_requires_exact_live_session_identity(self):
        self.write_save()
        self.write_map()
        session = self.visitor()
        session_path = pathlib.Path(session.path)
        self.assertTrue(self.housing.validate_before_start(session))

        self.housing._live_sessions.pop(session.path)
        with self.assertRaisesRegex(self.housing.HousingSessionError,
                                    "temporarily unavailable"):
            self.housing.validate_before_start(session)

        self.assertTrue(session.cleanup())
        self.assertFalse(session_path.exists())

    def test_restart_stale_cleanup_failure_blocks_account_until_retry(self):
        self.write_save()
        self.write_map()
        original = self.visitor()
        stale_path = pathlib.Path(original.path)
        reloaded = load_helper(self.config, self.userdb)
        real_rmtree = reloaded.shutil.rmtree
        allow_cleanup = [False]

        def fail_until_allowed(path):
            if not allow_cleanup[0]:
                raise OSError("persistent failure")
            return real_rmtree(path)

        with mock.patch.object(reloaded.shutil, "rmtree",
                               side_effect=fail_until_allowed), \
                mock.patch.object(reloaded.logging, "warning"):
            self.assertEqual(reloaded.cleanup_stale_sessions(), 0)
            self.assertTrue(reloaded._session_root_audit_ok)
            self.assertIn(str(stale_path),
                          reloaded._cleanup_retry_sessions)
            with self.assertRaisesRegex(reloaded.HousingSessionError,
                                        "temporarily unavailable"):
                reloaded.prepare_launch("Alice", 1, None)

            allow_cleanup[0] = True
            self.assertEqual(reloaded.retry_failed_cleanups(), 1)

        owner = reloaded.prepare_launch("Alice", 1, None)
        self.assertEqual(owner.role, "owner")
        self.assertFalse(stale_path.exists())

    def test_corrupt_session_root_entry_blocks_all_housing_launches(self):
        corrupt = self.sessions / "housing-corrupt"
        corrupt.mkdir()
        marker = corrupt / self.housing.MARKER_NAME
        marker.write_text(json.dumps({
            "magic": self.housing.MARKER_MAGIC,
            "path": str(self.root / "outside"),
            "username": "Alice",
            "account_id": 1,
        }))
        with mock.patch.object(self.housing.logging, "warning"):
            self.assertEqual(self.housing.cleanup_stale_sessions(), 0)
            self.assertFalse(self.housing._session_root_audit_ok)
            with self.assertRaisesRegex(self.housing.HousingSessionError,
                                        "temporarily unavailable"):
                self.housing.prepare_launch("Alice", 1, None)

        marker.unlink()
        corrupt.rmdir()
        self.assertEqual(self.housing.cleanup_stale_sessions(), 0)
        self.assertTrue(self.housing._session_root_audit_ok)
        self.assertEqual(
            self.housing.prepare_launch("Alice", 1, None).role, "owner")

    def test_cleanup_is_idempotent_and_refuses_paths_outside_root(self):
        self.write_save()
        self.write_map()
        session = self.visitor()
        path = pathlib.Path(session.path)
        self.assertTrue(session.cleanup())
        self.assertTrue(session.cleanup())
        self.assertFalse(path.exists())

        outside = self.root / "do-not-delete"
        outside.mkdir()
        (outside / "proof").write_text("safe")
        target = self.housing.HousingTarget(2, "Bob", "main")
        forged = self.housing.HousingVisitorSession(
            str(outside), "Alice", 1, target)
        with mock.patch.object(self.housing.logging, "warning"):
            self.assertFalse(forged.cleanup())
        self.assertTrue((outside / "proof").exists())

    def test_failed_cleanup_remains_retryable(self):
        self.write_save()
        self.write_map()
        session = self.visitor()
        path = pathlib.Path(session.path)
        with mock.patch.object(self.housing.shutil, "rmtree",
                               side_effect=OSError("temporary failure")), \
                mock.patch.object(self.housing.logging, "warning"):
            self.assertFalse(session.cleanup())
        self.assertTrue(path.exists())
        self.assertFalse(session._cleaned)
        self.assertIs(self.housing._cleanup_retry_sessions[session.path],
                      session)
        with self.assertRaisesRegex(self.housing.HousingSessionError,
                                    "temporarily unavailable"):
            self.housing.validate_before_start(session)
        self.assertTrue(session.cleanup())
        self.assertFalse(path.exists())
        self.assertNotIn(session.path, self.housing._cleanup_retry_sessions)

    def test_stale_cleanup_uses_exact_live_child_environment(self):
        self.write_save()
        self.write_map()
        session = self.visitor()
        child_env = os.environ.copy()
        child_env["CRAWL_HOUSING_SESSION_DIR"] = session.path
        child = subprocess.Popen(
            [sys.executable, "-c", "import time; time.sleep(30)"],
            env=child_env)
        reloaded = load_helper(self.config, self.userdb)
        try:
            session.set_pid(child.pid)
            # A fresh WebTiles process has no in-memory live registry and must
            # use the exact child environment recorded in the marker.
            self.assertEqual(reloaded.cleanup_stale_sessions(), 0)
            self.assertTrue(pathlib.Path(session.path).exists())
        finally:
            child.terminate()
            child.wait(timeout=5)
        self.assertEqual(reloaded.cleanup_stale_sessions(), 1)
        self.assertFalse(pathlib.Path(session.path).exists())

    def test_overlay_keeps_dynamic_environment_copy_and_server_side_token(self):
        patch = PATCH.read_text()
        self.assertIn("env_vars = dict(game.templated", patch)
        self.assertIn("env_vars.update(self.launch_context.environment())", patch)
        self.assertIn("housing_transition_target", patch)
        self.assertIn("hold_lock_for_transition", patch)
        self.assertIn("ignored_inprogress_lock", patch)
        self.assertIn("self.launch_context.rc_path", patch)
        self.assertIn("Invalid final Crawl socket message", patch)
        self.assertIn("self._cleanup_housing_session()", patch)
        self.assertIn(
            "if self.housing_session and not self._cleanup_housing_session()",
            patch)
        self.assertIn("housing_session.retry_failed_cleanups", patch)
        self.assertIn(
            "housing_session.validate_before_start(self.launch_context)",
            patch)
        self.assertLess(
            patch.index("if not self._validate_housing_launch()"),
            patch.index("self.process = TerminalRecorder"))
        self.assertNotIn("housing_session_id", patch)
        self.assertNotIn("session_token", patch)
        self.assertIn('"housing_place")', patch)
        self.assertIn(
            'game["place"] = housing_session.display_place(where)', patch)
        self.assertIn(
            'set("place", housing_lobby_place(data));', patch)
        setup = SETUP.read_text()
        self.assertEqual(setup.count("patch --batch"), 3)
        self.assertEqual(setup.count("patch --batch --fuzz=0"), 3)
        self.assertIn('[ "$patch_file" = "$housing_patch" ] && continue',
                      setup)
        self.assertLess(setup.index('for patch_file in'),
                        setup.index('upgrade_webtiles_patch.sh'))
        self.assertIn("webserver-patch-migrations", setup)
        self.assertTrue(UPGRADE_PATCH.stat().st_mode & 0o111)
        self.assertTrue(LEGACY_PATCH.is_file())
        self.assertIn("backfill_housing_bindings.py", setup)
        self.assertIn('sudo -u "$DGL_USER"', setup)
        self.assertLess(setup.index('upgrade_webtiles_patch.sh'),
                        setup.index("backfill_housing_bindings.py"))
        self.assertLess(setup.index("update_cnc_dwem_modules.py"),
                        setup.index("backfill_housing_bindings.py"))
        self.assertLess(setup.index("backfill_housing_bindings.py"),
                        setup.index("dgl publish --confirm"))

    def test_housing_metadata_probe_does_not_require_a_real_account(self):
        probe_root = self.root / "launcher-probe"
        binary_dir = probe_root / "bin"
        game_dir = probe_root / "games/crawl-housing"
        home_dir = probe_root / "home"
        binary_dir.mkdir(parents=True)
        game_dir.mkdir(parents=True)
        home_dir.mkdir()

        fake_binary = binary_dir / "crawl-housing"
        fake_binary.write_text("#!/bin/sh\nprintf 'probe:%s\\n' \"$*\"\n")
        fake_binary.chmod(0o755)

        launcher_text = LAUNCHER.read_text()
        replacements = {
            "%%CHROOT_CRAWL_BASEDIR%%": str(probe_root / "games"),
            "%%CHROOT_LOGIN_DB%%": str(probe_root / "missing.db"),
            "%%CHROOT_CRAWL_BINARY_PATH%%": str(binary_dir),
            "%%DGL_UID%%": str(os.getuid()),
            "%%CHROOT_COREDIR%%": str(home_dir),
        }
        for original, replacement in replacements.items():
            launcher_text = launcher_text.replace(original, replacement)
        launcher = probe_root / "launcher.sh"
        launcher.write_text(launcher_text)
        launcher.chmod(0o755)

        result = subprocess.run(
            [str(launcher), "housing", "-gametypes-json", "dummy"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("probe:-gametypes-json dummy", result.stdout)


if __name__ == "__main__":
    unittest.main()
