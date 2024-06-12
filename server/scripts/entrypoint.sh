#!/bin/bash

source "$DGL_CONF_HOME/dgl-manage.conf"
dgl create-versions-db
dgl create-crawl-gamedir
dgl publish --confirm

# convenience: run whatever CL arguments there are if we got to this point.
# probably something like /bin/bash.
if [ "$#" -gt 0 ]; then
    exec "$@"
fi
if [ -n "$CMD" ]; then
    exec "$CMD"
fi

INIT_FLAG_FILE="/var/run/dcss-server-init"
if [ ! -f "$INIT_FLAG_FILE" ]; then
  init.sh
  touch "$INIT_FLAG_FILE"
fi

run.sh

#Otherwise just tail the webtiles log
# if you get an error, that's because the trunk version is not installed in the volumes
# this means you should either use docker-entrypoint-build-trunk.sh
# or docker-entrypoint-build-all.sh as entrypoint to build crawl data into volumes
tail -f "$DGL_CHROOT/crawl-master/webserver/run/webtiles.log"
