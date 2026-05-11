#!/bin/bash

# set -u

# shellcheck source=crawl-git.conf
source "$DGL_CONF_HOME/crawl-git.conf"

LATEST_GAME_HASH="$(latest-game-hash)"
CRAWL_GIT_DIR="${CRAWL_GIT_DIR:-$CHROOT_CRAWL_BASEDIR}"
PREFIX="$DGL_CHROOT$CRAWL_GIT_DIR"

shopt -s nullglob
SAVEFILES=(
    "$PREFIX"/"$GAME"-*/saves/*-"${DGL_UID}".sav
    "$PREFIX"/"$GAME"-*/saves/*-"${DGL_UID}".chr
    "$PREFIX"/"$GAME"-*/saves/*.cs
    "$PREFIX"/"$GAME"-*/saves/sprint/*-"${DGL_UID}".chr
    "$PREFIX"/"$GAME"-*/saves/sprint/*.cs
    "$PREFIX"/"$GAME"-*/saves/zotdef/*.cs
)

if ((${#SAVEFILES[@]})); then
    ALL_CHARS="$(ls -1rt "${SAVEFILES[@]}" 2>/dev/null | \
                 grep -v "/${GAME}-${LATEST_GAME_HASH}/" | \
                 sed "s|${PREFIX}/${GAME}-.*/saves/\(.*\)\..*|\1|;s|-${DGL_UID}||" | \
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
