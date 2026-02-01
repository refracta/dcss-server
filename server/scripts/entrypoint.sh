#!/bin/bash

git config --global --add safe.directory '*'
if [ -z "$CMD" ]; then
    "$SCRIPTS"/dgl/generate-conf.sh
    dgl create-versions-db
    dgl create-crawl-gamedir
    dgl publish --confirm
else
    "$SCRIPTS"/dgl/generate-conf.sh 
    dgl create-versions-db 
    dgl create-crawl-gamedir
    dgl publish --confirm
    echo
    eval "$CMD"
    exit 0
fi

INIT_FLAG_FILE="/var/run/dcss-server-init"
if [ ! -f "$INIT_FLAG_FILE" ]; then
  "$SCRIPTS"/init.sh
  touch "$INIT_FLAG_FILE"
fi

function safe-exit {
    echo "Removing crawl-update.lock..."
    rm -rf /home/crawl-dev/dgamelaunch-config/locks/crawl-update.lock
    echo "Stopping SSH service..."
    service ssh stop
    echo "Stopping webtiles service..."
    /etc/init.d/webtiles stop
    rm -rf "$DGL_CHROOT/crawl-master/webserver/run/webtiles.pid"
    echo "Waiting for 5 seconds..."
    sleep 5
    echo "Exiting script."
    exit 0
}
trap 'safe-exit' EXIT

"$SCRIPTS"/run.sh

tail -f "$DGL_CHROOT/crawl-master/webserver/run/webtiles.log"
