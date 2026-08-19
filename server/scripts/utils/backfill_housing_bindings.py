#!/usr/bin/env python3
"""Backfill immutable Housing display-name to account-id bindings.

Old Housing publishers wrote only ``<account-id>/<map>.hmap``.  Current Crawl
processes deliberately do not scan that directory when resolving a portal, so
an administrator must derive the stable name index from dgamelaunch's account
database once.  This utility opens that database read-only and only considers
numeric account directories containing a regular ``*.hmap`` payload.

The utility is intentionally fail-closed.  It never replaces an existing
binding, follows no filesystem symlinks, and installs a complete binding with
the hard-link no-replace primitive used by the Housing core.
"""

import argparse
import os
from pathlib import Path
import re
import secrets
import sqlite3
import stat
import sys


ACCOUNT_RE = re.compile(r"\A[A-Za-z0-9]{3,20}\Z")
MAP_FILE_RE = re.compile(r"\A[_0-9A-Za-z]{1,20}\.hmap\Z")
BINDING_NAME = ".account-id"
BY_NAME_DIR = "by-name"
MAX_ACCOUNT_ID_LENGTH = 20
SQLITE_CHUNK_SIZE = 500


class BackfillError(RuntimeError):
    """A condition which must stop the binding migration."""


def _directory_flags():
    if not hasattr(os, "O_DIRECTORY") or not hasattr(os, "O_NOFOLLOW"):
        raise BackfillError("Housing binding backfill requires Unix openat safety")
    return os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW


def _lstat_at(directory_fd, name):
    try:
        return os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise BackfillError("could not inspect %s: %s" % (name, exc)) from exc


def _open_directory_at(directory_fd, name):
    try:
        fd = os.open(name, _directory_flags(), dir_fd=directory_fd)
    except OSError as exc:
        raise BackfillError("unsafe or inaccessible directory %s: %s"
                            % (name, exc)) from exc
    if not stat.S_ISDIR(os.fstat(fd).st_mode):
        os.close(fd)
        raise BackfillError("Housing path is not a directory: %s" % name)
    return fd


def _open_root(maps_dir):
    try:
        info = os.lstat(maps_dir)
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise BackfillError("could not inspect Housing maps directory: %s"
                            % exc) from exc
    if not stat.S_ISDIR(info.st_mode):
        raise BackfillError("Housing maps path is not a real directory")
    try:
        fd = os.open(maps_dir, _directory_flags())
    except OSError as exc:
        raise BackfillError("could not safely open Housing maps directory: %s"
                            % exc) from exc
    if not stat.S_ISDIR(os.fstat(fd).st_mode):
        os.close(fd)
        raise BackfillError("Housing maps path changed during inspection")
    return fd


def _canonical_account_id(name):
    if (not name or len(name) > MAX_ACCOUNT_ID_LENGTH
            or not name.isascii() or not name.isdigit()):
        return False
    try:
        value = int(name)
    except ValueError:
        return False
    return value > 0 and str(value) == name


def _discover_snapshot_accounts(root_fd):
    account_ids = []
    try:
        entries = list(os.scandir(root_fd))
    except OSError as exc:
        raise BackfillError("could not enumerate Housing maps: %s" % exc) from exc

    for entry in entries:
        name = entry.name
        if not name.isascii() or not name.isdigit():
            continue
        if not _canonical_account_id(name):
            raise BackfillError("non-canonical numeric Housing account path: %s"
                                % name)

        info = _lstat_at(root_fd, name)
        if info is None or not stat.S_ISDIR(info.st_mode):
            raise BackfillError("numeric Housing account path is not a real directory: %s"
                                % name)

        account_fd = _open_directory_at(root_fd, name)
        try:
            has_snapshot = False
            try:
                map_entries = list(os.scandir(account_fd))
            except OSError as exc:
                raise BackfillError("could not enumerate Housing account %s: %s"
                                    % (name, exc)) from exc
            for map_entry in map_entries:
                if not MAP_FILE_RE.match(map_entry.name):
                    continue
                try:
                    map_info = map_entry.stat(follow_symlinks=False)
                except OSError as exc:
                    raise BackfillError("could not inspect Housing snapshot %s/%s: %s"
                                        % (name, map_entry.name, exc)) from exc
                if not stat.S_ISREG(map_info.st_mode) or map_info.st_size <= 0:
                    raise BackfillError("Housing snapshot is not a non-empty regular file: %s/%s"
                                        % (name, map_entry.name))
                has_snapshot = True
            if has_snapshot:
                account_ids.append(name)
        finally:
            os.close(account_fd)

    return sorted(account_ids, key=int)


def _read_accounts_read_only(database, account_ids):
    if not account_ids:
        return []
    try:
        database_info = os.lstat(database)
    except OSError as exc:
        raise BackfillError("could not inspect account database: %s" % exc) from exc
    if not stat.S_ISREG(database_info.st_mode):
        raise BackfillError("account database is not a regular file")

    uri = Path(os.path.abspath(database)).as_uri() + "?mode=ro"
    connection = None
    try:
        connection = sqlite3.connect(uri, uri=True)
        connection.execute("PRAGMA query_only = ON")
    except sqlite3.Error as exc:
        if connection is not None:
            connection.close()
        raise BackfillError("could not open account database read-only: %s"
                            % exc) from exc

    found = {}
    try:
        for offset in range(0, len(account_ids), SQLITE_CHUNK_SIZE):
            chunk = account_ids[offset:offset + SQLITE_CHUNK_SIZE]
            placeholders = ",".join("?" for _ in chunk)
            query = ("SELECT id, username FROM dglusers WHERE id IN ("
                     + placeholders + ")")
            try:
                rows = connection.execute(query, tuple(int(item) for item in chunk))
                for account_id, username in rows:
                    canonical_id = str(account_id)
                    if canonical_id not in chunk:
                        raise BackfillError("account database returned an unexpected id")
                    if canonical_id in found:
                        raise BackfillError("account database returned duplicate id %s"
                                            % canonical_id)
                    if not isinstance(username, str) or not ACCOUNT_RE.match(username):
                        raise BackfillError("account %s has an invalid canonical username"
                                            % canonical_id)
                    found[canonical_id] = username
            except sqlite3.Error as exc:
                raise BackfillError("could not query account database read-only: %s"
                                    % exc) from exc

        missing = [account_id for account_id in account_ids
                   if account_id not in found]
        if missing:
            shown = ", ".join(missing[:10])
            if len(missing) > 10:
                shown += ", ..."
            raise BackfillError("numeric Housing snapshots have no account DB row: %s"
                                % shown)

        names = {}
        accounts = []
        for account_id in account_ids:
            username = found[account_id]
            lowered = username.lower()
            prior = names.get(lowered)
            if prior is not None and prior != account_id:
                raise BackfillError("canonical Housing username is reused by accounts %s and %s"
                                    % (prior, account_id))

            # Very old dgl databases can lack the case-insensitive unique index.
            # Refuse to choose an arbitrary row if such a database contains a
            # reused name, even when only one of those ids currently has maps.
            try:
                matching = list(connection.execute(
                    "SELECT id FROM dglusers "
                    "WHERE username=? COLLATE NOCASE", (username,)))
            except sqlite3.Error as exc:
                raise BackfillError("could not verify canonical account name: %s"
                                    % exc) from exc
            if (len(matching) != 1
                    or str(matching[0][0]) != account_id):
                raise BackfillError("canonical Housing username %s is ambiguous"
                                    % lowered)

            names[lowered] = account_id
            accounts.append((account_id, username, lowered))
        return accounts
    finally:
        connection.close()


def _read_binding(owner_fd):
    flags = os.O_RDONLY | os.O_NOFOLLOW
    try:
        fd = os.open(BINDING_NAME, flags, dir_fd=owner_fd)
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise BackfillError("unsafe or inaccessible Housing account binding: %s"
                            % exc) from exc
    try:
        info = os.fstat(fd)
        if (not stat.S_ISREG(info.st_mode) or info.st_size < 1
                or info.st_size > MAX_ACCOUNT_ID_LENGTH):
            raise BackfillError("Housing account binding is malformed")
        remaining = info.st_size
        pieces = []
        while remaining:
            piece = os.read(fd, remaining)
            if not piece:
                raise BackfillError("Housing account binding was truncated")
            pieces.append(piece)
            remaining -= len(piece)
        if os.read(fd, 1):
            raise BackfillError("Housing account binding changed while reading")
        try:
            value = b"".join(pieces).decode("ascii")
        except UnicodeDecodeError as exc:
            raise BackfillError("Housing account binding is not ASCII") from exc
        if not _canonical_account_id(value):
            raise BackfillError("Housing account binding has an invalid id")
        return value
    finally:
        os.close(fd)


def _preflight_existing_bindings(root_fd, accounts):
    by_name_info = _lstat_at(root_fd, BY_NAME_DIR)
    if by_name_info is None:
        return
    if not stat.S_ISDIR(by_name_info.st_mode):
        raise BackfillError("Housing by-name index is not a real directory")

    by_name_fd = _open_directory_at(root_fd, BY_NAME_DIR)
    try:
        for account_id, _username, lowered in accounts:
            owner_info = _lstat_at(by_name_fd, lowered)
            if owner_info is None:
                continue
            if not stat.S_ISDIR(owner_info.st_mode):
                raise BackfillError("Housing owner index is not a real directory: %s"
                                    % lowered)
            owner_fd = _open_directory_at(by_name_fd, lowered)
            try:
                existing = _read_binding(owner_fd)
            finally:
                os.close(owner_fd)
            if existing is not None and existing != account_id:
                raise BackfillError("Housing owner %s is already bound to account %s"
                                    % (lowered, existing))
    finally:
        os.close(by_name_fd)


def _ensure_directory_at(parent_fd, name, mode=0o755):
    created = False
    try:
        os.mkdir(name, mode=mode, dir_fd=parent_fd)
        created = True
    except FileExistsError:
        pass
    except OSError as exc:
        raise BackfillError("could not create Housing index directory %s: %s"
                            % (name, exc)) from exc

    child_fd = _open_directory_at(parent_fd, name)
    if created:
        try:
            os.fsync(parent_fd)
        except OSError as exc:
            os.close(child_fd)
            raise BackfillError("could not make Housing index directory durable: %s"
                                % exc) from exc
    return child_fd


def _write_all(fd, payload):
    offset = 0
    while offset < len(payload):
        try:
            count = os.write(fd, payload[offset:])
        except OSError as exc:
            raise BackfillError("could not write Housing account binding: %s"
                                % exc) from exc
        if count <= 0:
            raise BackfillError("could not write complete Housing account binding")
        offset += count


def _install_binding(owner_fd, account_id):
    existing = _read_binding(owner_fd)
    if existing is not None:
        if existing != account_id:
            raise BackfillError("Housing owner binding changed to account %s"
                                % existing)
        return False

    temporary = None
    temp_fd = None
    for _attempt in range(100):
        candidate = ".account-id.tmp.%s" % secrets.token_hex(12)
        try:
            temp_fd = os.open(candidate,
                              os.O_WRONLY | os.O_CREAT | os.O_EXCL
                              | os.O_NOFOLLOW,
                              0o600, dir_fd=owner_fd)
            temporary = candidate
            break
        except FileExistsError:
            continue
        except OSError as exc:
            raise BackfillError("could not create temporary Housing binding: %s"
                                % exc) from exc
    if temp_fd is None:
        raise BackfillError("could not allocate a temporary Housing binding")

    installed = False
    try:
        try:
            _write_all(temp_fd, account_id.encode("ascii"))
            os.fsync(temp_fd)
        finally:
            os.close(temp_fd)
            temp_fd = None

        try:
            os.link(temporary, BINDING_NAME,
                    src_dir_fd=owner_fd, dst_dir_fd=owner_fd,
                    follow_symlinks=False)
            installed = True
        except FileExistsError:
            existing = _read_binding(owner_fd)
            if existing != account_id:
                raise BackfillError("Housing owner binding raced with account %s"
                                    % (existing or "<invalid>"))
        except OSError as exc:
            raise BackfillError("could not atomically install Housing binding: %s"
                                % exc) from exc

        if installed:
            try:
                os.fsync(owner_fd)
            except OSError as exc:
                raise BackfillError("could not make Housing binding durable: %s"
                                    % exc) from exc
        return installed
    finally:
        if temp_fd is not None:
            os.close(temp_fd)
        if temporary is not None:
            try:
                os.unlink(temporary, dir_fd=owner_fd)
            except FileNotFoundError:
                pass
            except OSError as exc:
                raise BackfillError("could not remove temporary Housing binding: %s"
                                    % exc) from exc


def backfill_bindings(database, maps_dir):
    """Return ``(eligible, created)`` after an idempotent safe backfill."""
    root_fd = _open_root(maps_dir)
    if root_fd is None:
        return 0, 0
    try:
        account_ids = _discover_snapshot_accounts(root_fd)
        accounts = _read_accounts_read_only(database, account_ids)
        _preflight_existing_bindings(root_fd, accounts)
        if not accounts:
            return 0, 0

        by_name_fd = _ensure_directory_at(root_fd, BY_NAME_DIR)
        created = 0
        try:
            for account_id, _username, lowered in accounts:
                owner_fd = _ensure_directory_at(by_name_fd, lowered)
                try:
                    if _install_binding(owner_fd, account_id):
                        created += 1
                finally:
                    os.close(owner_fd)
        finally:
            os.close(by_name_fd)
        return len(accounts), created
    finally:
        os.close(root_fd)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", required=True,
                        help="dgamelaunch SQLite account database")
    parser.add_argument("--maps-dir", required=True,
                        help="Housing public maps directory")
    args = parser.parse_args(argv)
    try:
        eligible, created = backfill_bindings(args.database, args.maps_dir)
    except (BackfillError, OSError) as exc:
        print("Housing binding backfill failed: %s" % exc, file=sys.stderr)
        return 1
    print("Housing binding backfill: %d eligible account(s), %d created"
          % (eligible, created))
    return 0


if __name__ == "__main__":
    sys.exit(main())
