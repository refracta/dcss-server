#!/bin/bash

source "$DGL_CONF_HOME/dgl-manage.conf"
sed -i 's|CONFIG_MORGUE_URL|https://archive.nemelex.cards/morgue/%n/|g' "$DGL_CONF_HOME/config.py"
sed -i 's|CONFIG_SERVER_ID|crawl.nemelex.cards|g' "$DGL_CONF_HOME/config.py"
sed -i 's|CONFIG_DGL_SERVER|crawl.nemelex.cards|g' "$DGL_CONF_HOME/dgl-manage.conf"
sed -i 's|CONFIG_WEB_SAVEDUMP_URL|https://archive.nemelex.cards/saves|g' "$DGL_CONF_HOME/dgl-manage.conf"
cp -r $DGL_CONF_HOME/server/etc/webserver/* $WEBDIR
# TODO: delete localStorage.removeItem("DWEM"); should be removed (temporal setting)
if ! python3 "$(dirname "${BASH_SOURCE[0]}")/update_cnc_dwem_modules.py" "$WEBDIR/templates/client.html"; then
    exit 1
fi
grep -qxF '# CRAWL.NEMELEX.CARDS' /dgldir/data/crawl-git-settings/init.txt || sed -i '1i# CRAWL.NEMELEX.CARDS' /dgldir/data/crawl-git-settings/init.txt
dgl publish --confirm > /dev/null 2>&1
echo
