#!/bin/bash

# set -u

# shellcheck source=crawl-git.conf
source "$DGL_CONF_HOME/crawl-git.conf"

LATEST_GAME_HASH="$(latest-game-hash)"
CRAWL_GIT_DIR="${CRAWL_GIT_DIR:-$CHROOT_CRAWL_BASEDIR}"
BINARY_BASE_NAME="${BINARY_BASE_NAME:-$GAME}"
PREFIX="$DGL_CHROOT$CRAWL_GIT_DIR"

shopt -s nullglob
SAVEFILES=(
    "$PREFIX"/"$BINARY_BASE_NAME"-*/saves/*-"${DGL_UID}".sav
    "$PREFIX"/"$BINARY_BASE_NAME"-*/saves/*-"${DGL_UID}".chr
    "$PREFIX"/"$BINARY_BASE_NAME"-*/saves/*.cs
    "$PREFIX"/"$BINARY_BASE_NAME"-*/saves/sprint/*-"${DGL_UID}".chr
    "$PREFIX"/"$BINARY_BASE_NAME"-*/saves/sprint/*.cs
    "$PREFIX"/"$BINARY_BASE_NAME"-*/saves/zotdef/*.cs
)

if ((${#SAVEFILES[@]})); then
    ALL_CHARS="$(ls -1rt "${SAVEFILES[@]}" 2>/dev/null | \
                 grep -v "/${BINARY_BASE_NAME}-${LATEST_GAME_HASH}/" | \
                 sed "s|${PREFIX}/${BINARY_BASE_NAME}-.*/saves/\(.*\)\..*|\1|;s|-${DGL_UID}||" | \
                 sort -f)"
else
    ALL_CHARS=""
fi

echo "Trying to transfer these chars to a newer version:"
echo "${ALL_CHARS}"
echo

echo "-- Press RETURN to start transfer --"
read -r

for char in ${ALL_CHARS}
do
    dgl savegame-transfer "${char}"
done
