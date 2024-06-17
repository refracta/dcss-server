#!/bin/bash

source "$DGL_CONF_HOME/dgl-manage.conf"
sed -i 's|CONFIG_MORGUE_URL|https://archive.nemelex.cards/morgue/%n/|g' "$DGL_CONF_HOME/config.py"
sed -i 's|CONFIG_DGL_SERVER|crawl.nemelex.cards|g' "$DGL_CONF_HOME/dgl-manage.conf"
sed -i 's|CONFIG_WEB_SAVEDUMP_URL|https://archive.nemelex.cards/saves|g' "$DGL_CONF_HOME/dgl-manage.conf"
cp -r $DGL_CONF_HOME/server/etc/webserver/* $WEBDIR
dgl publish --confirm > /dev/null 2>&1