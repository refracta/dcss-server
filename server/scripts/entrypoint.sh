#!/bin/bash

if [ -z "$CMD" ]; then
    "$SCRIPTS"/dgl/generate-conf.sh
    dgl create-versions-db
    dgl create-crawl-gamedir
    dgl publish --confirm
else
    "$SCRIPTS"/dgl/generate-conf.sh > /dev/null 2>&1
    dgl create-versions-db > /dev/null 2>&1
    dgl create-crawl-gamedir > /dev/null 2>&1
    dgl publish --confirm > /dev/null 2>&1
    eval "$CMD"
    exit 0
fi

INIT_FLAG_FILE="/var/run/dcss-server-init"
if [ ! -f "$INIT_FLAG_FILE" ]; then
  "$SCRIPTS"/init.sh
  touch "$INIT_FLAG_FILE"
fi

"$SCRIPTS"/run.sh

tail -f "$DGL_CHROOT/crawl-master/webserver/run/webtiles.log"
