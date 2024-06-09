#!/bin/bash
#
# This script needs a sudo entry for user crawl to run as root:
# For obvious reasons, this script should not source any other scripts that
# are not owned by root.
#
# ===========================================================================
# Copyright (C) 2008, 2009, 2010, 2011 Marc H. Thoben
# Copyright (C) 2011 Darshan Shaligram
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
# ===========================================================================
#

set -e
set -u

# These are not overrideable:
CHROOT="%%DGL_CHROOT%%"
CHROOT_BINARIES="%%CHROOT_CRAWL_BINARY_PATH%%"
CHROOT_CRAWL_BASEDIR="%%CHROOT_CRAWL_BASEDIR%%"
DESTDIR="%%CRAWL_BASEDIR%%"
VERSIONS_DB="%%VERSIONS_DB%%"
CRAWL_UGRP="%%CRAWL_UGRP%%"
DGL_SETTINGS_DIR="%%DGL_SETTINGS_DIR%%"

VERSION="$1"

GAME="crawl-$VERSION"

# Safe path:
PATH=/bin:/sbin:/usr/bin:/usr/sbin

if [[ "$UID" != "0" ]]; then
    echo "$0 must be run as root"
    exit 1
fi

copy-game-binary() {
    echo "Installing game binary ($GAME_BINARY) in $BINARIES_DIR"
    mkdir -p $BINARIES_DIR
    if [[ -f $BINARIES_DIR/$GAME_BINARY ]]; then
        mv $BINARIES_DIR/$GAME_BINARY $BINARIES_DIR/$GAME_BINARY.old
    fi
    if cp source/$GAME_BINARY $BINARIES_DIR; then
        rm $BINARIES_DIR/$GAME_BINARY.old || true
    else
        local ERR=$?
        mv $BINARIES_DIR/$GAME_BINARY.old $BINARIES_DIR/$GAME_BINARY || true
        return $ERR
    fi
}

copy-data-files() {
    echo "Copying game data files to $DATADIR"
    cp -r source/dat docs settings $DATADIR
    # Only one of these exists, don't error for the other.
    cp -r README.txt README.md $DATADIR 2>/dev/null || true
    cp -r settings/. $DGL_SETTINGS_DIR/$GAME-settings
    cp -r source/webserver/game_data/. $DATADIR/web

    mkdir -p "$ABS_COMMON_DIR/data/docs"
    cp docs/crawl_changelog.txt "$ABS_COMMON_DIR/data/docs"
}

create-dgl-directories() {
    mkdir -p "$CHROOT/dgldir/inprogress/crawl-$VERSION-sprint/"
    mkdir -p "$CHROOT/dgldir/inprogress/crawl-$VERSION-tutorial/"
    mkdir -p "$CHROOT/dgldir/inprogress/crawl-$VERSION-descent/"
    mkdir -p "$CHROOT/dgldir/inprogress/crawl-$VERSION-zotdef/"
    mkdir -p "$CHROOT/dgldir/inprogress/crawl-$VERSION-seed/"
    mkdir -p "$CHROOT/dgldir/inprogress/crawl-$VERSION/"
    mkdir -p "$CHROOT/dgldir/rcfiles/crawl-$VERSION/"
    mkdir -p "$CHROOT/dgldir/data/crawl-$VERSION-settings/"
}

fix-chroot-directory-permissions() {
    chown -R crawl:crawl "$CHROOT/crawl-master"
    chown -R crawl:crawl "$CHROOT/dgldir"
}

install-game() {
    mkdir -p $SAVEDIR/{,sprint,zotdef,descent}
    mkdir -p $DATADIR

    create-dgl-directories
    fix-chroot-directory-permissions
    copy-game-binary
    copy-data-files

    chown -R $CRAWL_UGRP $SAVEDIR
}

assert-not-evil() {
    local file=$1
    if [[ "$file" != "$(echo "$file" |
                        perl -lpe 's{[.]{2}|[^.a-zA-Z0-9_/-]+}{}g')" ]]
    then
        echo -e "Path $file contains characters I don't like, aborting."
        exit 1
    fi
}

if [[ -z "$VERSION" ]]; then
    echo -e "Missing version argument"
    exit 1
fi

assert-not-evil "$VERSION"

if [[ ! ( "$CRAWL_UGRP" =~ ^[a-z0-9]+:[a-z0-9]+$ ) ]]; then
    echo -e "Expected CRAWL_UGRP to be user:group, but got $CRAWL_UGRP"
    exit 1
fi

# COMMON_DIR is the absolute path *inside* the chroot jail of the
# directory holding common data for all game versions, viz: saves.
COMMON_DIR=$CHROOT_CRAWL_BASEDIR/$GAME
assert-not-evil "$COMMON_DIR"

# ABS_COMMON_DIR is the absolute path from outside the chroot
# corresponding to COMMON_DIR
ABS_COMMON_DIR=$CHROOT$COMMON_DIR

if [[ ! -d "$ABS_COMMON_DIR" ]]; then
    mkdir -p "$ABS_COMMON_DIR"
fi

GAME_BINARY=$GAME
BINARIES_DIR=$CHROOT$CHROOT_BINARIES

GAMEDIR=$CHROOT$CHROOT_CRAWL_BASEDIR/$GAME
# Absolute path to save game directory
SAVEDIR=$GAMEDIR/saves
DATADIR=$GAMEDIR/data
assert-not-evil "$SAVEDIR"
assert-not-evil "$DATADIR"

echo "Installing game"
install-game
