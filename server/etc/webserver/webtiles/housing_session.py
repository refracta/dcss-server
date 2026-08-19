"""Server-owned lifecycle for disposable DCSS Housing visitor sessions.

The browser is allowed to request only an ``Owner:map_id`` target.  It never
chooses a save path or a session identifier.  A visitor process runs with a
new-inode copy of the logged-in user's canonical Housing save and with a
server-side copy of the selected public map snapshot.
"""

import errno
import fcntl
import json
import logging
import os
import re
import shutil
import stat
import tempfile
import time

from webtiles import config, userdb


TARGET_RE = re.compile(r"\A([A-Za-z0-9]{3,20}):([_0-9A-Za-z]{1,20})\Z")
ACCOUNT_RE = re.compile(r"\A[A-Za-z0-9]{3,20}\Z")
SESSION_PREFIX = "housing-"
MARKER_NAME = ".housing-session.json"
MARKER_MAGIC = "dcss-housing-session-v1"
COPY_BUFSIZE = 1024 * 1024
_cleanup_retry_sessions = {}
_live_sessions = {}
_session_root_audit_ok = None


class HousingSessionError(Exception):
    """An expected, safe-to-report Housing launch failure."""

    def __init__(self, public_message, log_message=None):
        super(HousingSessionError, self).__init__(log_message or public_message)
        self.public_message = public_message


class HousingTarget(object):
    def __init__(self, account_id, owner, map_id):
        self.account_id = _account_id(account_id)
        self.owner = owner
        self.map_id = map_id

    @property
    def spec(self):
        return "%s:%s" % (self.owner, self.map_id)


def _account_id(value):
    try:
        result = int(value)
    except (TypeError, ValueError):
        raise HousingSessionError("Housing is temporarily unavailable.")
    if result <= 0 or len(str(result)) > 20:
        raise HousingSessionError("Housing is temporarily unavailable.")
    return result


def validate_url_targets(values):
    """Validate Tornado's full list of ``map`` query values.

    Requiring exactly one value here prevents ``?map=a&map=b`` from being
    interpreted differently by the HTTP and WebSocket layers.
    """
    if len(values) != 1:
        raise HousingSessionError("Invalid Housing map link.")
    return parse_target(values[0])


def parse_target(value):
    if not isinstance(value, str):
        raise HousingSessionError("Invalid Housing map link.")
    match = TARGET_RE.match(value)
    if not match:
        raise HousingSessionError("Invalid Housing map link.")
    return match.group(1), match.group(2)


def display_place(where):
    """Return the Housing map label without replacing Crawl's place field."""
    housing_place = where.get("housing_place")
    if isinstance(housing_place, str) and housing_place:
        return housing_place
    return where.get("place", "")


def _configured_path(name):
    path = config.get(name)
    if not isinstance(path, str) or not os.path.isabs(path):
        raise HousingSessionError(
            "Housing is temporarily unavailable.",
            "Housing config %s must be an absolute path" % name)
    return os.path.abspath(path)


def _path_is_within(path, directory):
    """Return whether path resolves lexically or physically below directory."""
    path = os.path.abspath(path)
    directory = os.path.abspath(directory)
    try:
        if os.path.commonpath((path, directory)) == directory:
            return True
        return (os.path.commonpath((os.path.realpath(path),
                                    os.path.realpath(directory)))
                == os.path.realpath(directory))
    except ValueError:
        # Different drives on platforms which expose them cannot overlap.
        return False


def _canonical_runtime_path(path, username=None, suffix=None,
                            session_path=None):
    """Validate a server-supplied path before exposing it to Crawl."""
    if not isinstance(path, str) or not os.path.isabs(path):
        raise HousingSessionError("Housing is temporarily unavailable.")
    path = os.path.abspath(path)
    if suffix is not None and os.path.basename(path) != username + suffix:
        raise HousingSessionError("Housing is temporarily unavailable.")
    if session_path is not None and _path_is_within(path, session_path):
        raise HousingSessionError("Housing is temporarily unavailable.")
    return path


def _canonical_save_path(username, session_path=None):
    return _canonical_runtime_path(
        os.path.join(_configured_path("housing_save_dir"), username + ".cs"),
        username, ".cs", session_path)


def _pin_runtime_path(instance, attribute, path, suffix=None):
    canonical = _canonical_runtime_path(
        path, instance.username, suffix, getattr(instance, "path", None))
    pinned = getattr(instance, attribute)
    if pinned is None:
        setattr(instance, attribute, canonical)
    elif pinned != canonical:
        raise HousingSessionError("Housing is temporarily unavailable.")
    return canonical


def _add_canonical_environment(instance, environment):
    environment["CRAWL_HOUSING_CANONICAL_SAVE"] = \
        instance.canonical_save_path
    for attribute, variable in (
            ("canonical_rc_path", "CRAWL_HOUSING_CANONICAL_RC"),
            ("canonical_macro_path", "CRAWL_HOUSING_CANONICAL_MACRO"),
            ("canonical_morgue_path", "CRAWL_HOUSING_CANONICAL_MORGUE")):
        path = getattr(instance, attribute)
        if path is not None:
            environment[variable] = path
    return environment


def _canonical_user(username):
    if not isinstance(username, str) or not ACCOUNT_RE.match(username):
        raise HousingSessionError("Housing is temporarily unavailable.")
    info = userdb.get_user_info(username)
    if not info or not ACCOUNT_RE.match(info.username):
        raise HousingSessionError("Housing is temporarily unavailable.")
    return info


def resolve_target(username, account_id, target_spec):
    """Resolve and canonicalize a target through the server account DB."""
    owner, map_id = parse_target(target_spec)
    own_info = _canonical_user(username)
    if _account_id(own_info.id) != _account_id(account_id):
        raise HousingSessionError("Housing is temporarily unavailable.")

    target_info = userdb.get_user_info(owner)
    if not target_info or not ACCOUNT_RE.match(target_info.username):
        raise HousingSessionError("That Housing map is unavailable.")

    return HousingTarget(target_info.id, target_info.username, map_id)


def _regular_fd(path, flags=os.O_RDONLY):
    nofollow = getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(path, flags | nofollow)
    except OSError as exc:
        if exc.errno in (errno.ENOENT, errno.ENOTDIR, errno.ELOOP):
            raise HousingSessionError("That Housing map is unavailable.")
        raise
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise HousingSessionError("That Housing map is unavailable.")
        return fd
    except Exception:
        os.close(fd)
        raise


def _regular_fd_beneath(root, components):
    """Open a regular file without following any untrusted path component."""
    if (not components
            or any(not part or part in (".", "..")
                   or os.sep in part for part in components)):
        raise HousingSessionError("That Housing map is unavailable.")

    directory_flags = (os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
                       | getattr(os, "O_NOFOLLOW", 0))
    current_fd = None
    try:
        current_fd = os.open(root, directory_flags)
        for component in components[:-1]:
            next_fd = os.open(component, directory_flags, dir_fd=current_fd)
            os.close(current_fd)
            current_fd = next_fd
        file_fd = os.open(components[-1],
                          os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0),
                          dir_fd=current_fd)
        if not stat.S_ISREG(os.fstat(file_fd).st_mode):
            os.close(file_fd)
            raise HousingSessionError("That Housing map is unavailable.")
        return file_fd
    except OSError as exc:
        if exc.errno in (errno.ENOENT, errno.ENOTDIR, errno.ELOOP):
            raise HousingSessionError("That Housing map is unavailable.")
        raise
    finally:
        if current_fd is not None:
            os.close(current_fd)


def _copy_fd_to_new_inode(source_fd, destination, mode=0o600):
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    flags |= getattr(os, "O_NOFOLLOW", 0)
    destination_fd = os.open(destination, flags, mode)
    try:
        with os.fdopen(os.dup(source_fd), "rb") as source:
            with os.fdopen(os.dup(destination_fd), "wb") as output:
                shutil.copyfileobj(source, output, COPY_BUFSIZE)
                output.flush()
                os.fsync(output.fileno())
    except Exception:
        try:
            os.unlink(destination)
        except OSError:
            pass
        raise
    finally:
        os.close(destination_fd)


def _copy_locked_beneath(source_root, source_components, destination,
                         public_message, busy_message=None):
    """Copy a regular source while holding a nonblocking shared POSIX lock."""
    try:
        source_fd = _regular_fd_beneath(source_root, source_components)
    except HousingSessionError:
        raise HousingSessionError(public_message)
    try:
        try:
            fcntl.lockf(source_fd, fcntl.LOCK_SH | fcntl.LOCK_NB)
        except OSError as exc:
            if exc.errno in (errno.EACCES, errno.EAGAIN):
                raise HousingSessionError(busy_message or public_message)
            raise
        _copy_fd_to_new_inode(source_fd, destination)
    finally:
        os.close(source_fd)


def _copy_optional_regular(source, destination):
    try:
        source_fd = _regular_fd(source)
    except HousingSessionError:
        # A missing macro is normal, but symlinks and non-regular files are not.
        try:
            st = os.lstat(source)
        except OSError as exc:
            if exc.errno == errno.ENOENT:
                fd = os.open(destination,
                             os.O_WRONLY | os.O_CREAT | os.O_EXCL
                             | getattr(os, "O_NOFOLLOW", 0), 0o600)
                os.close(fd)
                return
            raise
        if not stat.S_ISREG(st.st_mode):
            raise HousingSessionError("Housing is temporarily unavailable.")
        raise
    try:
        _copy_fd_to_new_inode(source_fd, destination)
    finally:
        os.close(source_fd)


def _fsync_directory(path):
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
    fd = os.open(path, flags)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


class HousingOwnerLaunch(object):
    role = "owner"
    session = None

    def __init__(self, username, account_id):
        info = _canonical_user(username)
        if _account_id(info.id) != _account_id(account_id):
            raise HousingSessionError("Housing is temporarily unavailable.")
        self.username = info.username
        self.account_id = _account_id(info.id)
        self.public_dir = _configured_path("housing_maps_dir")
        self.canonical_save_path = _canonical_save_path(self.username)
        self.canonical_rc_path = None
        self.canonical_macro_path = None
        self.canonical_morgue_path = None

    def command_args(self):
        return []

    def environment(self):
        return _add_canonical_environment(self, {
            "CRAWL_HOUSING_ROLE": "owner",
            "CRAWL_HOUSING_ACCOUNT_ID": str(self.account_id),
            "CRAWL_HOUSING_MAP_ID": "main",
            "CRAWL_HOUSING_PUBLIC_DIR": self.public_dir,
        })

    def macro_path(self, default_path):
        return _pin_runtime_path(
            self, "canonical_macro_path", default_path, ".macro")

    def rc_path(self, default_path):
        return _pin_runtime_path(
            self, "canonical_rc_path", default_path, ".rc")

    def morgue_path(self, default_path):
        return _pin_runtime_path(
            self, "canonical_morgue_path", default_path)

    def set_pid(self, pid):
        pass

    def process_ended(self):
        pass


class HousingVisitorSession(object):
    role = "visitor"

    def __init__(self, path, username, account_id, target, created=None,
                 canonical_save_path=None):
        self.path = path
        self.username = username
        self.account_id = _account_id(account_id)
        self.target = target
        self.created = created if created is not None else time.time()
        self.public_dir = _configured_path("housing_maps_dir")
        self.sessions_root = _configured_path("housing_sessions_dir")
        self.save_path = os.path.join(path, "saves", "housing",
                                      username + ".cs")
        self.snapshot_path = os.path.join(path, "target.hmap")
        self.rc_file = os.path.join(path, "rc", username + ".rc")
        self.macro_file = os.path.join(path, "macro", username + ".macro")
        self.morgue_dir = os.path.join(path, "morgue")
        self.marker_path = os.path.join(path, MARKER_NAME)
        self.pid = None
        if canonical_save_path is None:
            canonical_save_path = _canonical_save_path(username, path)
        self.canonical_save_path = _canonical_runtime_path(
            canonical_save_path, username, ".cs", path)
        self.canonical_rc_path = None
        self.canonical_macro_path = None
        self.canonical_morgue_path = None
        self.canonical_rc_dir = None
        self._cleaned = False

    @classmethod
    def create(cls, username, account_id, target):
        info = _canonical_user(username)
        if _account_id(info.id) != _account_id(account_id):
            raise HousingSessionError("Housing is temporarily unavailable.")
        if _account_id(target.account_id) == _account_id(info.id):
            raise HousingSessionError("Housing is temporarily unavailable.")

        sessions_root = _configured_path("housing_sessions_dir")
        saves_root = _configured_path("housing_save_dir")
        maps_root = _configured_path("housing_maps_dir")
        _ensure_private_root(sessions_root)

        path = tempfile.mkdtemp(prefix=SESSION_PREFIX, dir=sessions_root)
        os.chmod(path, 0o700)
        canonical_save_path = _canonical_runtime_path(
            os.path.join(saves_root, info.username + ".cs"),
            info.username, ".cs", path)
        session = cls(path, info.username, info.id, target,
                      canonical_save_path=canonical_save_path)
        _live_sessions[path] = session
        try:
            os.makedirs(os.path.dirname(session.save_path), mode=0o700)
            os.makedirs(os.path.dirname(session.rc_file), mode=0o700)
            os.makedirs(os.path.dirname(session.macro_file), mode=0o700)
            os.makedirs(session.morgue_dir, mode=0o700)
            # Mark the directory before copying any account data so startup
            # cleanup can recover it even if a later copy/cleanup step fails.
            session._write_marker()

            _copy_locked_beneath(
                saves_root, [info.username + ".cs"], session.save_path,
                "Create a Housing character before visiting another map.",
                "Your Housing character is currently in use.")
            session._stage_target_from(maps_root, target, initial=True)
            return session
        except Exception:
            session.cleanup()
            raise

    def _marker_data(self):
        return {
            "magic": MARKER_MAGIC,
            "version": 1,
            "path": self.path,
            "username": self.username,
            "account_id": self.account_id,
            "created": self.created,
            "pid": self.pid,
        }

    def _write_marker(self):
        if self._cleaned:
            return
        fd, temporary = tempfile.mkstemp(prefix=".marker-", dir=self.path)
        try:
            os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w") as output:
                json.dump(self._marker_data(), output, sort_keys=True)
                output.flush()
                os.fsync(output.fileno())
            fd = None
            os.replace(temporary, self.marker_path)
            _fsync_directory(self.path)
        finally:
            if fd is not None:
                os.close(fd)
            try:
                os.unlink(temporary)
            except OSError:
                pass

    def _stage_target_from(self, maps_root, target, initial=False):
        if initial:
            destination = self.snapshot_path
        else:
            fd, destination = tempfile.mkstemp(prefix=".target-", dir=self.path)
            os.close(fd)
            os.unlink(destination)
        try:
            _copy_locked_beneath(
                maps_root,
                [str(target.account_id), target.map_id + ".hmap"],
                destination, "That Housing map is unavailable.")
            if not initial:
                os.replace(destination, self.snapshot_path)
                _fsync_directory(self.path)
            self.target = target
        except Exception:
            if not initial:
                try:
                    os.unlink(destination)
                except OSError:
                    pass
            raise

    def stage_target(self, target):
        """Replace only the snapshot; the disposable character is retained."""
        if self._cleaned:
            raise HousingSessionError("Housing is temporarily unavailable.")
        if _account_id(target.account_id) == self.account_id:
            raise HousingSessionError("Housing is temporarily unavailable.")
        self._stage_target_from(self.public_dir, target, initial=False)

    def command_args(self):
        # USE_DGAMELAUNCH builds treat -dir as the save-root itself rather
        # than appending "saves", so point it at the agreed session layout.
        # The main rc is disposable, but relative includes should continue to
        # resolve from the server-configured canonical rc directory.  rc_path
        # records that trusted directory before process arguments are built.
        if self.canonical_rc_dir is None:
            raise HousingSessionError("Housing is temporarily unavailable.")
        return ["-dir", os.path.join(self.path, "saves"),
                "-rcdir", self.canonical_rc_dir]

    def environment(self):
        return _add_canonical_environment(self, {
            "CRAWL_HOUSING_ROLE": "visitor",
            "CRAWL_HOUSING_ACCOUNT_ID": str(self.account_id),
            "CRAWL_HOUSING_MAP_ID": "main",
            "CRAWL_HOUSING_PUBLIC_DIR": self.public_dir,
            "CRAWL_HOUSING_TARGET_ACCOUNT_ID": str(self.target.account_id),
            "CRAWL_HOUSING_TARGET_OWNER": self.target.owner,
            "CRAWL_HOUSING_TARGET_MAP_ID": self.target.map_id,
            "CRAWL_HOUSING_SNAPSHOT": self.snapshot_path,
            "CRAWL_HOUSING_SESSION_DIR": self.path,
        })

    def macro_path(self, default_path):
        default_path = _pin_runtime_path(
            self, "canonical_macro_path", default_path, ".macro")
        if not os.path.exists(self.macro_file):
            _copy_optional_regular(default_path, self.macro_file)
        return self.macro_file

    def rc_path(self, default_path):
        default_path = _pin_runtime_path(
            self, "canonical_rc_path", default_path, ".rc")
        canonical_rc_dir = os.path.dirname(default_path)
        if self.canonical_rc_dir is None:
            self.canonical_rc_dir = canonical_rc_dir
        elif self.canonical_rc_dir != canonical_rc_dir:
            raise HousingSessionError("Housing is temporarily unavailable.")
        if not os.path.exists(self.rc_file):
            _copy_optional_regular(default_path, self.rc_file)
        return self.rc_file

    def morgue_path(self, default_path):
        _pin_runtime_path(
            self, "canonical_morgue_path", default_path)
        return self.morgue_dir

    def set_pid(self, pid):
        if not isinstance(pid, int) or pid <= 0:
            raise HousingSessionError("Housing is temporarily unavailable.")
        self.pid = pid
        self._write_marker()

    def process_ended(self):
        if not self._cleaned:
            self.pid = None
            self._write_marker()

    def cleanup(self):
        if self._cleaned:
            _cleanup_retry_sessions.pop(self.path, None)
            _live_sessions.pop(self.path, None)
            return True
        if not _safe_session_directory(self.path, self.sessions_root,
                                       require_marker=False):
            try:
                os.lstat(self.path)
            except OSError as exc:
                if exc.errno == errno.ENOENT:
                    self._cleaned = True
                    _cleanup_retry_sessions.pop(self.path, None)
                    _live_sessions.pop(self.path, None)
                    return True
            _cleanup_retry_sessions[self.path] = self
            logging.warning("Refusing to remove unsafe Housing session %s",
                            self.path)
            return False
        try:
            shutil.rmtree(self.path)
        except OSError as exc:
            if exc.errno == errno.ENOENT:
                self._cleaned = True
                _cleanup_retry_sessions.pop(self.path, None)
                _live_sessions.pop(self.path, None)
                return True
            # Keep both the object and a module-owned reference retryable.  A
            # periodic WebTiles callback handles even construction failures,
            # whose local session object would otherwise be lost.
            _cleanup_retry_sessions[self.path] = self
            logging.warning("Unable to remove Housing session %s",
                            self.path, exc_info=True)
            return False
        else:
            self._cleaned = True
            _cleanup_retry_sessions.pop(self.path, None)
            _live_sessions.pop(self.path, None)
            return True


def retry_failed_cleanups():
    """Retry failed disposable-session removals from the WebTiles loop."""
    removed = 0
    for session in list(_cleanup_retry_sessions.values()):
        if session.cleanup():
            removed += 1
    # A healthy root needs no full rescan on every timer tick.  If an unsafe
    # entry blocked the root audit, periodically re-audit so an operator can
    # remove it without restarting WebTiles.
    if _session_root_audit_ok is False:
        removed += cleanup_stale_sessions()
    return removed


def _require_account_cleanup(username, account_id, existing_session):
    global _session_root_audit_ok
    if _session_root_audit_ok is not True:
        cleanup_stale_sessions()
    if _session_root_audit_ok is not True:
        raise HousingSessionError("Housing is temporarily unavailable.")

    info = _canonical_user(username)
    canonical_id = _account_id(info.id)
    if canonical_id != _account_id(account_id):
        raise HousingSessionError("Housing is temporarily unavailable.")
    for session in list(_cleanup_retry_sessions.values()):
        if session is existing_session:
            if not session.cleanup():
                raise HousingSessionError(
                    "Housing is temporarily unavailable.")
            continue
        if (session.account_id == canonical_id
                and session.username.lower() == info.username.lower()
                and not session.cleanup()):
            raise HousingSessionError("Housing is temporarily unavailable.")
    for session in list(_live_sessions.values()):
        if session is existing_session:
            continue
        if (session.account_id == canonical_id
                and session.username.lower() == info.username.lower()):
            raise HousingSessionError("Housing is temporarily unavailable.")


def validate_before_start(launch_context):
    """Revalidate server-owned Housing state immediately before fork."""
    try:
        if isinstance(launch_context, HousingVisitorSession):
            if (launch_context._cleaned
                    or launch_context.path in _cleanup_retry_sessions
                    or _live_sessions.get(launch_context.path)
                        is not launch_context
                    or not _safe_session_directory(
                        launch_context.path, launch_context.sessions_root,
                        require_marker=True)):
                raise HousingSessionError(
                    "Housing is temporarily unavailable.")
            _require_account_cleanup(
                launch_context.username, launch_context.account_id,
                launch_context)
            if (_live_sessions.get(launch_context.path)
                    is not launch_context):
                raise HousingSessionError(
                    "Housing is temporarily unavailable.")
        elif isinstance(launch_context, HousingOwnerLaunch):
            _require_account_cleanup(
                launch_context.username, launch_context.account_id, None)
        else:
            raise HousingSessionError("Housing is temporarily unavailable.")
        return True
    except HousingSessionError:
        raise
    except OSError:
        logging.warning("Housing pre-start validation failed", exc_info=True)
        raise HousingSessionError("Housing is temporarily unavailable.")


def prepare_launch(username, account_id, target_spec=None, existing_session=None):
    """Build an owner launch or a visitor launch using server-owned state.

    ``existing_session`` is accepted only from the authenticated WebSocket
    object.  It is never represented in the browser protocol.
    """
    try:
        _require_account_cleanup(username, account_id, existing_session)
        return _prepare_launch(username, account_id, target_spec,
                               existing_session)
    except HousingSessionError:
        raise
    except OSError:
        logging.warning("Housing session filesystem operation failed",
                        exc_info=True)
        if existing_session:
            existing_session.cleanup()
        raise HousingSessionError("Housing is temporarily unavailable.")


def _prepare_launch(username, account_id, target_spec, existing_session):
    if target_spec is None:
        if existing_session and not existing_session.cleanup():
            raise HousingSessionError("Housing is temporarily unavailable.")
        return HousingOwnerLaunch(username, account_id)

    target = resolve_target(username, account_id, target_spec)
    if _account_id(target.account_id) == _account_id(account_id):
        if existing_session and not existing_session.cleanup():
            raise HousingSessionError("Housing is temporarily unavailable.")
        return HousingOwnerLaunch(username, account_id)

    if existing_session:
        if (existing_session.username.lower() != username.lower()
                or existing_session.account_id != _account_id(account_id)):
            existing_session.cleanup()
            raise HousingSessionError("Housing is temporarily unavailable.")
        existing_session.stage_target(target)
        return existing_session
    return HousingVisitorSession.create(username, account_id, target)


def _ensure_private_root(root):
    try:
        st = os.lstat(root)
    except OSError as exc:
        if exc.errno != errno.ENOENT:
            raise
        os.makedirs(root, mode=0o700)
        st = os.lstat(root)
    if not stat.S_ISDIR(st.st_mode) or stat.S_ISLNK(st.st_mode):
        raise HousingSessionError("Housing is temporarily unavailable.")


def _safe_session_directory(path, root, require_marker=True):
    root = os.path.abspath(root)
    path = os.path.abspath(path)
    if os.path.dirname(path) != root:
        return False
    if not os.path.basename(path).startswith(SESSION_PREFIX):
        return False
    try:
        st = os.lstat(path)
    except OSError:
        return False
    if not stat.S_ISDIR(st.st_mode) or stat.S_ISLNK(st.st_mode):
        return False
    if require_marker:
        marker = _read_marker(path)
        return bool(marker and marker.get("path") == path)
    return True


def _read_marker(path):
    marker_path = os.path.join(path, MARKER_NAME)
    try:
        fd = _regular_fd(marker_path)
        with os.fdopen(fd, "r") as source:
            marker = json.load(source)
    except (HousingSessionError, OSError, ValueError, TypeError):
        return None
    if not isinstance(marker, dict) or marker.get("magic") != MARKER_MAGIC:
        return None
    return marker


def _pid_owns_session(pid, path):
    if not isinstance(pid, int) or pid <= 0:
        return False
    try:
        with open("/proc/%d/environ" % pid, "rb") as source:
            environ = source.read()
    except OSError:
        return False
    expected = ("CRAWL_HOUSING_SESSION_DIR=" + path).encode("utf-8")
    return expected in environ.split(b"\0")


def cleanup_stale_sessions():
    """Audit the private root and remove sessions without a live child."""
    global _session_root_audit_ok
    root = _configured_path("housing_sessions_dir")
    _ensure_private_root(root)
    removed = 0
    audit_ok = True
    with os.scandir(root) as entries:
        for entry in entries:
            path = os.path.abspath(entry.path)
            if not _safe_session_directory(path, root, require_marker=False):
                audit_ok = False
                logging.warning("Unsafe entry in Housing session root: %s",
                                path)
                continue
            if path in _live_sessions:
                continue
            marker = _read_marker(path)
            if not marker or marker.get("path") != path:
                audit_ok = False
                logging.warning("Invalid Housing session marker: %s", path)
                continue
            try:
                info = _canonical_user(marker.get("username"))
                marker_account_id = _account_id(marker.get("account_id"))
                if _account_id(info.id) != marker_account_id:
                    raise HousingSessionError(
                        "Housing is temporarily unavailable.")
            except HousingSessionError:
                audit_ok = False
                logging.warning("Unresolvable Housing session owner: %s",
                                path)
                continue
            if marker and _pid_owns_session(marker.get("pid"), path):
                continue
            session = _cleanup_retry_sessions.get(path)
            if session is None:
                session = HousingVisitorSession(
                    path, info.username, marker_account_id, None,
                    created=marker.get("created"))
            if session.cleanup():
                removed += 1
    _session_root_audit_ok = audit_ok
    if removed:
        logging.info("Removed %d stale Housing visitor session(s).", removed)
    return removed
