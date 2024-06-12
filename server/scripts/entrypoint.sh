#!/bin/bash

source "$DGL_CONF_HOME/dgl-manage.conf"
if [ -z "$CMD" ]; then
    dgl create-versions-db
    dgl create-crawl-gamedir
    dgl publish --confirm
else
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

#Otherwise just tail the webtiles log
# if you get an error, that's because the trunk version is not installed in the volumes
# this means you should either use docker-entrypoint-build-trunk.sh
# or docker-entrypoint-build-all.sh as entrypoint to build crawl data into volumes
tail -f "$DGL_CHROOT/crawl-master/webserver/run/webtiles.log"
