#!/bin/bash

source "$DGL_CONF_HOME/dgl-manage.conf"
sed -i 's|CONFIG_MORGUE_URL|https://archive.nemelex.cards/morgue/%n/|g' "$DGL_CONF_HOME/config.py"
sed -i 's|CONFIG_SERVER_ID|crawl.nemelex.cards|g' "$DGL_CONF_HOME/config.py"
sed -i 's|CONFIG_DGL_SERVER|crawl.nemelex.cards|g' "$DGL_CONF_HOME/dgl-manage.conf"
sed -i 's|CONFIG_WEB_SAVEDUMP_URL|https://archive.nemelex.cards/saves|g' "$DGL_CONF_HOME/dgl-manage.conf"
cp -r $DGL_CONF_HOME/server/etc/webserver/* $WEBDIR
# TODO: delete localStorage.removeItem("DWEM"); should be removed (temporal setting)
sed -i 's|<script type="text/javascript">|<script  type="text/javascript">\
      localStorage.removeItem("DWEM");\
      localStorage.DWEM_MODULES = JSON.stringify(\
        ["io-hook", "site-information", "websocket-factory", "rc-manager", "module-manager", "cnc-banner", "cnc-userinfo", "sound-support", "cnc-chat", "cnc-public-chat", "convenience-module", "cnc-splash-screen", "wtrec", "advanced-rc-editor"].map(m => "../modules/" + m + "/index.js")\
      );|g' "$WEBDIR/templates/client.html"
grep -qxF '# CRAWL.NEMELEX.CARDS' /dgldir/data/crawl-git-settings/init.txt || sed -i '1i# CRAWL.NEMELEX.CARDS' /dgldir/data/crawl-git-settings/init.txt
dgl publish --confirm > /dev/null 2>&1
