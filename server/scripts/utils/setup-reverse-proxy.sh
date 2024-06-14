#!/bin/bash

source "$DGL_CONF_HOME/dgl-manage.conf"
sed -i 's/self.request.remote_ip/self.request.headers.get("X-Forwarded-For", self.request.remote_ip).split(",")[0].strip()/g' "$WEBDIR/webtiles/ws_handler.py"
