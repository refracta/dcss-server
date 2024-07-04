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

CRAWL_GIT_DIR="%%CHROOT_CRAWL_BASEDIR%%"
USER_DB="%%CHROOT_LOGIN_DB%%"
CRAWL_BINARY_PATH="%%CHROOT_CRAWL_BINARY_PATH%%"
BINARY_BASE_NAME="%%GAME%%"
USER_ID="%%DGL_UID%%"
VERSIONS_DB="%%CHROOT_VERSIONS_DB%%"

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
wcat() {
    if [[ -n "$WEBTILES" ]]; then
        tr '\n' ' ' | sed -e 's/ $//'
        echo
    else
        cat >/dev/null
    fi
}

TRANSFER_ENABLED="1"
CHAR_NAME="$2"

# Clear screen
[[ -z "$JUST_RUN_CRAWL_ALREADY" && -z "$WEBTILES" ]] && printf "\e[2J\e[H"

export LANG="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"

SAVES="saves"

[[ "$@" =~ -sprint$wb ]] && SAVES="$SAVES/sprint"
[[ "$@" =~ -descent$wb ]] && SAVES="$SAVES/descent"
[[ "$@" =~ -tutorial$wb ]] && SAVES="$SAVES/tutorial"
[[ "$@" =~ -zotdef$wb ]] && SAVES="$SAVES/zotdef"

if [[ $# == 0 || -z "$CHAR_NAME" ]]; then
    if [[ -z "$JUST_RUN_CRAWL_ALREADY" ]]; then
        echo "Parameters missing. Aborting..."
        read -n 1 -s -p "--- any key to continue ---"
        echo
    fi
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

query() {
    sqlite3 "$VERSIONS_DB"
}

hash-description() {
    local hash=$1
    query <<EOF
SELECT description FROM versions WHERE hash='$hash' LIMIT 1;
EOF
}

latest-game-hash() {
    query <<EOF
SELECT hash FROM versions ORDER BY time DESC LIMIT 1;
EOF
}

major-version-for-game() {
    local game=$1
    query <<EOF
SELECT major FROM versions WHERE hash='$game' LIMIT 1;
EOF
}

newest-version-with-major-version() {
    local major_version=$1
    query <<EOF
SELECT hash FROM versions WHERE major=$major_version
ORDER BY time DESC
LIMIT 1;
EOF
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

transfer-save() {
    local save=$1
    local game_hash=$2
    local target="$CRAWL_GIT_DIR/$BINARY_BASE_NAME-$game_hash/$SAVES"
    local src_save_dir=$(dirname $save)

    wecho -n '{"msg":"show_dialog", "html":"'

    if [[ -d "$target" ]]; then
        # It's okay if moving the .prf fails (it might not exist one day).
        mv "$src_save_dir/start-$CHAR_NAME-ns.prf" "$target" 2>/dev/null || true
        mv -n "$src_save_dir/$CHAR_NAME".cs "$target"

        if test $? -eq 0
        then
            wcat <<EOF
<p>Transferring successful!</p>
<input type='button' class='button' data-key=' ' value='Continue' style='float:right;'>
"}
EOF
            cecho ": successful!"
            cecho
            OUR_GAME_HASH="${game_hash}"
            cecho -n "--- any key to continue ---"
            read -n 1 -t 5 -s
            cecho
        else
            wcat <<EOF
<p>Transferring failed!</p>
<p>Transferring your save failed! Continuing with former version.</p>
<input type='button' class='button' data-key=' ' value='Continue' style='float:right;'>
"}
EOF
            cecho ": failed!"
            cecho
            cecho "Transferring your save failed! Continuing with former version."
            cecho -n "--- any key to continue ---"
            read -n 1 -s
            cecho
        fi
    else
        wcat <<EOF
<p>Transferring failed!</p>
<p>Target version is corrupt! Continuing with former version.</p>
<input type='button' class='button' data-key=' ' value='Continue' style='float:right;'>
"}
EOF
        cecho ": failed!"
        cecho
        cecho "Target version is corrupt! Continuing with former version."
        cecho -n "--- any key to continue ---"
        read -n 1 -s
        cecho
    fi
    wecho '{"msg":"hide_dialog"}'
}

SAVEGLOB="$CRAWL_GIT_DIR/$BINARY_BASE_NAME-*/$SAVES"

declare -a SAVE_CANDIDATES
SAVE_CANDIDATES=($SAVEGLOB/$CHAR_NAME.cs \
    $SAVEGLOB/$CHAR_NAME-$USER_ID.sav \
    $SAVEGLOB/$CHAR_NAME-$USER_ID.chr)

SAVE="$(first-real-file "${SAVE_CANDIDATES[@]}")"
LATEST_GAME_HASH="$(latest-game-hash)"

if [[ -n "$SAVE" ]]; then
    OUR_GAME_HASH=${SAVE#$CRAWL_GIT_DIR/$BINARY_BASE_NAME-}
    OUR_GAME_HASH=${OUR_GAME_HASH%%/*}

    if [[ -z "$JUST_RUN_CRAWL_ALREADY" && \
        "$OUR_GAME_HASH" != "$LATEST_GAME_HASH" ]]
    then
        current_ver="$(hash-description $OUR_GAME_HASH)"
        cecho "Hi, you have a $current_ver save game:"
        cecho

        OUR_SGV_MAJOR="$(major-version-for-game $OUR_GAME_HASH)"
        NEW_GAME_HASH="$(newest-version-with-major-version $OUR_SGV_MAJOR)"
        new_ver="$(hash-description $NEW_GAME_HASH)"

        if [[ "$OUR_GAME_HASH" != "$NEW_GAME_HASH" &&
                    "$TRANSFER_ENABLED" == "1" ]]; then
            wecho '{"msg":"layer", "layer":"crt"}'
            wecho -n '{"msg":"show_dialog", "html":"'

            if [[ "${NEW_GAME_HASH}" != "${LATEST_GAME_HASH}" ]]; then
                cecho "There's a newer version ($new_ver) that can load your save."
                cecho -n "[T]ransfer your save to this version?"
                wcat <<EOF
<p>There's a newer version ($new_ver) that can load your save.</p>
<p>[T]ransfer your save to this version?</p>
<input type='button' class='button' data-key='N' value='No' style='float:right;'>
<input type='button' class='button' data-key='T' value='Yes' style='float:right;'>
"}
EOF
                read -n 1 -s REPLY
                cecho
            else
                cecho -n "[T]ransfer your save to the latest version ($new_ver)?"
                wcat <<EOF
<p>[T]ransfer your save to the latest version ($new_ver)?</p>
<input type='button' class='button' data-key='N' value='No' style='float:right;'>
<input type='button' class='button' data-key='T' value='Yes' style='float:right;'>
"}
EOF
                read -n 1 -s REPLY
                cecho
            fi
            wecho '{"msg":"hide_dialog"}'

            if test "$REPLY" = "t" -o "$REPLY" = "T" -o "$REPLY" = "y" -o "$REPLY" = "Y"
            then
                cecho -n "Transferring..."
                transfer-save "$SAVE" "$NEW_GAME_HASH"
            fi
        else
            if test "${TRANSFER_ENABLED}" != "1"
            then
                cecho "Transfering of saves is currently disabled."
                cecho "Finish your game or end your character to play in latest version."
            else
                cecho "Your save cannot be tranferred though because of incompatibility."
                cecho "Finish your game or end your character to play in latest version."
            fi

            cecho -n "--- any key to continue ---"
            [[ -z "$WEBTILES" ]] && read -n 1 -t 5 -s
            cecho
        fi
    fi
else
    OUR_GAME_HASH="${LATEST_GAME_HASH}"
fi

if test ${#OUR_GAME_HASH} -eq 0
then
    cecho "Could not figure out the right game version. Aborting..."
    cecho -n "--- any key to continue ---"
    [[ -z "$WEBTILES" ]] && read -n 1 -s -p
    cecho
    exit 1
fi

BINARY_NAME="$CRAWL_BINARY_PATH/$BINARY_BASE_NAME-$OUR_GAME_HASH"
GAME_FOLDER="$CRAWL_GIT_DIR/$BINARY_BASE_NAME-$OUR_GAME_HASH"

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
