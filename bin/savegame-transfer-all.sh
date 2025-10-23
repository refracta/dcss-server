#!/bin/bash

# set -u

# shellcheck source=crawl-git.conf
source "$DGL_CONF_HOME/crawl-git.conf"

LATEST_GAME_HASH="$(latest-game-hash)"
PREFIX="$DGL_CHROOT/$CRAWL_GIT_DIR"

SAVEBASE="${PREFIX}/${BINARY_BASE_NAME}-*/saves"
ALL_CHARS="$(ls -1rt "$SAVEBASE"/*-"${DGL_UID}".sav \
                     "$SAVEBASE"/*-"${DGL_UID}".chr \
                     "$SAVEBASE"/*.cs \
                     "$SAVEBASE"/sprint/*-"${DGL_UID}".chr \
                     "$SAVEBASE"/sprint/*.cs \
                     "$SAVEBASE"/zotdef/*.cs 2>/dev/null | \
             grep -v "$LATEST_GAME_HASH" | \
             sed "s|${PREFIX}/${BINARY_BASE_NAME}-.*/saves/\(.*\)\..*|\1|;s|-${DGL_UID}||" | \
             sort -f)"

echo "Trying to transfer these chars to a newer version:"
echo "${ALL_CHARS}"
echo

echo "-- Press RETURN to start transfer --"
read -r

for char in ${ALL_CHARS}
do
    dgl savegame-transfer "${char}"
done
