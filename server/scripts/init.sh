#!/bin/bash

"$SCRIPTS"/dgl/setup-user.sh
"$SCRIPTS"/game/setup-cron.sh

"$SCRIPTS"/web/init.sh
"$SCRIPTS"/web/setup-apache.sh
"$SCRIPTS"/web/setup-nginx.sh

if [ "$USE_REVERSE_PROXY" = 'true' ]; then
  "$SCRIPTS"/util/setup-reverse-proxy.sh
fi
if [ "$USE_DWEM" = 'true' ]; then
  "$SCRIPTS"/util/setup-dwem.sh
fi
