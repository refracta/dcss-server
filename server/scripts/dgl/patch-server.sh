#!/bin/bash

source "$DGL_CONF_HOME/dgl-manage.conf"
sed -i "s/config.get('chroot')/False/g" "$WEBDIR/webtiles/server.py"
