#!/bin/bash

sed -i 's/self.request.remote_ip/self.request.headers.get("X-Forwarded-For", self.request.remote_ip).split(",")[0].strip()/g' "$CHROOT_CRAWL_BASEDIR/webserver/webtiles/ws_handler.py"
