#!/bin/bash
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

set -u

ARGUMENTS=($@)
CHAR_NAME="$(echo ${ARGUMENTS[0]} | sed 's/[$*\/();.|+-]//g')"
BINARY_MAIN_NAME=${ARGUMENTS[1]}
BINARY_SAVE_NAME=$BINARY_MAIN_NAME
PREFIX="${ARGUMENTS[2]}"

trap "read -n 1 -s -p '-- Hit a key to exit --'; exit 0" EXIT

clear

TODAY="$(date +%y%m%d-%H%M)"

TARGET_DIR="%%CHROOT_SAVE_DUMPDIR%%"
HTTP_LINK="%%WEB_SAVEDUMP_URL%%"

USER_ID="%%DGL_UID%%"

existing-files() {
    for file in "$@"; do
        if [[ -f "$file" ]]; then
            printf "%s " "$file"
        fi
    done
}

first-existing-file() {
    for file in "$@"; do
        if [[ -f "$file" ]]; then
            echo "$file"
        fi
    done
}

savedir-containing() {
    local char="$1"
    local -a saves
    saves=($PREFIX/$BINARY_SAVE_NAME{,-*}/saves/$char{,-$USER_ID}.{cs,chr,sav})
    local savefile
    savefile="$(first-existing-file "${saves[@]}")"
    [[ -n "$savefile" ]] && dirname "$savefile"
    return 0
}

SAVES="$(savedir-containing "$CHAR_NAME")"
SPRINT_SAVES="$(savedir-containing sprint/"$CHAR_NAME")"
HOUSING_SAVES="$(savedir-containing housing/"$CHAR_NAME")"
ZOTDEF_SAVES="$(savedir-containing zotdef/"$CHAR_NAME")"

if [[ -z "$SAVES" && -z "$SPRINT_SAVES" && -z "$HOUSING_SAVES" && -z "$ZOTDEF_SAVES" ]]; then
    echo "No saves to backup for $CHAR_NAME"
fi

SAVE_QUALIFIER=""

CHAR=Character

C_NORMAL="\033[0m"
C_GREEN="\033[1;32m"
C_RED="\033[1;31m"

PROMPT="Backup"
[[ -n "$SAVES" ]] && PROMPT="$PROMPT [n]ormal save"
[[ -n "$SPRINT_SAVES" ]] && PROMPT="$PROMPT [s]print"
[[ -n "$HOUSING_SAVES" ]] && PROMPT="$PROMPT [h]ousing"
[[ -n "$ZOTDEF_SAVES" ]] && PROMPT="$PROMPT [z]otdef"
PROMPT="$PROMPT character?"

read -r -n 1 -s -p "$PROMPT" REPLY
echo

REPLY="$(echo "$REPLY" | sed 's/\([A-Z]\)/\L\1/g')"

if [[ -n "$SPRINT_SAVES" && ( "$REPLY" = "s" ) ]]; then
    SAVE_QUALIFIER="-sprint"
    SAVES="$SPRINT_SAVES"
    CHAR="Sprint character"
elif [[ -n "$HOUSING_SAVES" && ( "$REPLY" = "h" ) ]]; then
    SAVE_QUALIFIER="-housing"
    SAVES="$HOUSING_SAVES"
    CHAR="Housing character"
elif [[ -n "$ZOTDEF_SAVES" && ( "$REPLY" = "z" ) ]]; then
    SAVE_QUALIFIER="-zotdef"
    SAVES="$ZOTDEF_SAVES"
    CHAR="Zot Defense character"
elif [[ "$REPLY" != "n" ]]; then
    echo -e "Bad choice, aborting."
    exit 1
fi

declare -a SAVE_MATCHES
SAVE_MATCHES=(${SAVES}/${CHAR_NAME}{,-${USER_ID}}.{sav,cs,chr}*)

# Get rid of glob patterns that failed to match anything:
SAVE_MATCHES=(${SAVE_MATCHES[@]##*\*})

# And the first remaining entry is the matched save.
SAVE_FOUND=${SAVE_MATCHES[0]}

if [[ -n "$SAVE_FOUND" && -f "$SAVE_FOUND" ]]; then
    GAME_NAME="${SAVES%/zotdef}"
    GAME_NAME="${GAME_NAME%/sprint}"
    GAME_NAME="${GAME_NAME%/housing}"
    GAME_NAME="$(dirname "$GAME_NAME")"
    GAME_NAME="${GAME_NAME##*/}"

    echo
    echo "$CHAR \"${CHAR_NAME}\" in $GAME_NAME. "

    echo -n "Backing up:"
    cd "$SAVES"

    TARNAME=${CHAR_NAME}${SAVE_QUALIFIER}-$GAME_NAME-${TODAY}.tar.bz2
    tar -cjf "${TARGET_DIR}/$TARNAME" \
        $(existing-files "${CHAR_NAME}"{,-"${USER_ID}"}.*)

    if test $? -ne 0
    then
        echo -e " ${C_RED}failed!${C_NORMAL}"
    else
        echo -e " ${C_GREEN}successful.${C_NORMAL}"
        echo "- ${HTTP_LINK}/$TARNAME"
        echo
        echo "Please provide this link in your bug-report or give it to a developer."
    fi
else
    echo "Your character ($CHAR_NAME) was not found in $SAVES."
fi
