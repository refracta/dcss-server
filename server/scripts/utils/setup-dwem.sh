#!/bin/bash

source "$DGL_CONF_HOME/dgl-manage.conf"
TIMESTAMP=$(date +%s%3N)
sed -i 's|<script src="/static/scripts/contrib/require.js" data-main="/static/scripts/app"></script>|<script src="https://cdn.jsdelivr.net/gh/refracta/dcss-webtiles-extension-module/loader/dwem-base-loader.js?t='"$TIMESTAMP"'"></script>|g' "$WEBDIR/templates/client.html"
