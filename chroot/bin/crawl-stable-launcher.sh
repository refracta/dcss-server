#! /bin/bash
#
# Must be called as crawl-git -name <playername> [...]; character name
# must always be the second argument.
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

# The webtiles binary requires a UTF-8 locale.
export LC_ALL=en_US.UTF-8

set -o nounset

VERSION=$1
shift

CRAWL_GIT_DIR="%%CHROOT_CRAWL_BASEDIR%%"
USER_DB="%%CHROOT_LOGIN_DB%%"
CRAWL_BINARY_PATH="%%CHROOT_CRAWL_BINARY_PATH%%"
BINARY_BASE_NAME="crawl-$VERSION"
USER_ID="%%DGL_UID%%"

export HOME="%%CHROOT_COREDIR%%"

# Word boundary regex; bash's =~ is funny about that.
wb='\b'

JUST_RUN_CRAWL_ALREADY=
# If set, this script will not event report the existence of newer versions.
[[ "$@" =~ -print-charset$wb ]] && JUST_RUN_CRAWL_ALREADY=1
[[ "$@" =~ -print-webtiles-options$wb ]] && JUST_RUN_CRAWL_ALREADY=1
[[ "$@" =~ -gametypes-json$wb ]] && JUST_RUN_CRAWL_ALREADY=1
[[ "$@" =~ -save-json$wb ]] && JUST_RUN_CRAWL_ALREADY=1

WEBTILES=
[[ "$@" =~ -await-connection$wb ]] && WEBTILES=1

cecho() {
    [[ -z "$WEBTILES" ]] && echo "$@"
}
wecho() {
    [[ -n "$WEBTILES" ]] && echo "$@"
}

TRANSFER_ENABLED="1"
CHAR_NAME="$2"

# Clear screen
[[ -z "$JUST_RUN_CRAWL_ALREADY" && -z "$WEBTILES" ]] && printf "\e[2J\e[H"

export LANG="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"

if [[ $# == 0 || -z "$CHAR_NAME" ]]; then
    if [[ -z "$JUST_RUN_CRAWL_ALREADY" ]]; then
        echo "Parameters missing. Aborting..."
        read -n 1 -s -p "--- any key to continue ---"
        echo
    fi;
    exit 1
fi

ulimit -S -c 1536000 2>/dev/null
ulimit -S -v 1024000 2>/dev/null

first-real-file() {
    for file in "$@"; do
        if [[ -f "$file" ]]; then
            printf "%s\n" "$file"
            return 0
        fi
    done
}

user-is-admin() {
    if [ ! -f "$USER_DB" ]; then
        return 1
    fi
    local found="$(echo "SELECT username FROM dglusers
                         WHERE username='$CHAR_NAME' AND (flags & 1) = 1;" |
                   sqlite3 "$USER_DB")"
    [[ -n "$found" ]]
}

BINARY_NAME="$CRAWL_BINARY_PATH/$BINARY_BASE_NAME"
GAME_FOLDER="$CRAWL_GIT_DIR/$BINARY_BASE_NAME"

if user-is-admin; then
    set -- "$@" -wizard
fi

if test -x "${BINARY_NAME}" -a -d "${GAME_FOLDER}"
then
    cd ${HOME}
    exec ${BINARY_NAME} "$@"
fi

cecho "Failed starting: ${BINARY_NAME} not found!"
read -n 1 -s -p "--- any key to continue ---"
cecho
exit 1
