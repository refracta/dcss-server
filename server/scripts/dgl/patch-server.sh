#!/bin/bash

source "$DGL_CONF_HOME/dgl-manage.conf"
sed -i 's/do_chroot()//g' "$WEBDIR/webtiles/server.py"
