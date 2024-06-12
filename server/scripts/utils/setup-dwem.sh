#!/bin/bash

sed -i 's|<script src="/static/scripts/contrib/require.js" data-main="/static/scripts/app"></script>|<script src="https://cdn.jsdelivr.net/gh/refracta/dcss-webtiles-extension-module/loader/dwem-base-loader.js"></script>|g' "$CHROOT_CRAWL_BASEDIR/webserver/templates/client.html"
sed -i 's/self.request.remote_ip/self.request.headers.get("X-Forwarded-For", self.request.remote_ip).split(",")[0].strip()/g' "$CHROOT_CRAWL_BASEDIR/webserver/webtiles/ws_handler.py"
