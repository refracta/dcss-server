#! /bin/bash

# shellcheck source=crawl-git.conf
source "$DGL_CONF_HOME/crawl-git.conf"

set -e
GAME_DIR=$CRAWL_GAMEDIR
echo "Crawl basedir to create: $GAME_DIR"

[[ -d "$GAME_DIR" ]] && abort-saying "Crawl base directory already exists"
# assert-chroot-exists
[[ "$UID" != "0" ]] && abort-saying "This script must be run as root"

# ensure some basic preconditions.
# TODO: perhaps do these unconditionally? It's not very risky. In fact, one
# could pretty safely just run this entire script unconditionally.

mkdir -p "$DGL_CHROOT/cores"
mkdir -p "$DGL_CHROOT/crawl-master" \
         "$DGL_CHROOT/crawl-master/webserver/" \
         "$DGL_CHROOT/crawl-master/webserver/run/" \
         "$DGL_CHROOT/crawl-master/webserver/sockets/" \
         "$DGL_CHROOT/crawl-master/webserver/templates/" \
         "$DGL_CHROOT/dgldir" \
         "$DGL_CHROOT/dgldir/data/" \
         "$DGL_CHROOT/dgldir/dumps/" \
         "$DGL_CHROOT/dgldir/morgue/" \
         "$DGL_CHROOT/dgldir/rcfiles/" \
         "$DGL_CHROOT/dgldir/ttyrec/" \
         "$DGL_CHROOT/dgldir/data/menus/" \
         "$DGL_CHROOT/dgldir/inprogress/"
touch "$DGL_CHROOT/dgamelaunch" "$DGL_CHROOT/dgldebug.log"
chown -R $CRAWL_UGRP "$DGL_CHROOT/dgldebug.log" "$DGL_CHROOT/dgldir" "$DGL_CHROOT/crawl-master"

mkdir -p "$GAME_DIR"/saves/{sprint,descent,zotdef}
( cd "$GAME_DIR/saves" &&
    touch logfile{,-sprint,-descent,-zotdef} \
        milestones{,-sprint,-descent,-zotdef} \
        scores{,-sprint,-descent,-zotdef} )

# Only the saves dir within GAME_DIR is chowned: data dir is not supposed
# to be writable by CRAWL_UGRP.
chown -R $CRAWL_UGRP "$GAME_DIR/saves"
cp -R $GAME_DIR "$GAME_DIR/../crawl-init"

echo "Created $GAME_DIR"
