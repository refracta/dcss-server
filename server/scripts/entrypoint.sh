#!/bin/bash

git config --global --add safe.directory '*'
if [ -z "$CMD" ]; then
    # The previous container may have stopped in the middle of a Git update.
    # Clean up before starting cron, not on exit while an updater can still
    # own or recreate these locks. One-off CMD containers must leave them alone.
    echo "Removing stale Crawl update locks..."
    rm -f -- "$DGL_CONF_HOME/locks/crawl-update.lock" \
        "$DGL_CONF_HOME/crawl-build/crawl-git-repository/.git/index.lock" \
        "$DGL_CONF_HOME/crawl-build/crawl-git-repository/.git/HEAD.lock" || exit 1
    git_refs="$DGL_CONF_HOME/crawl-build/crawl-git-repository/.git/refs"
    if [ -d "$git_refs" ]; then
        # Reset/checkout also lock the branch that HEAD points to.
        find "$git_refs" -type f -name '*.lock' -delete || exit 1
    fi

    "$SCRIPTS"/dgl/generate-conf.sh
    dgl create-versions-db
    dgl create-crawl-gamedir
    dgl publish --confirm
else
    "$SCRIPTS"/dgl/generate-conf.sh 
    dgl create-versions-db 
    dgl create-crawl-gamedir
    dgl publish --confirm
    echo
    eval "$CMD"
    exit 0
fi

INIT_FLAG_FILE="/var/run/dcss-server-init"
if [ ! -f "$INIT_FLAG_FILE" ]; then
  "$SCRIPTS"/init.sh
  touch "$INIT_FLAG_FILE"
fi

function safe-exit {
    echo "Stopping cron service..."
    service cron stop
    echo "Stopping SSH service..."
    service ssh stop
    echo "Stopping webtiles service..."
    /etc/init.d/webtiles stop
    rm -rf "$DGL_CHROOT/crawl-master/webserver/run/webtiles.pid"
    echo "Waiting for 5 seconds..."
    sleep 5
    echo "Exiting script."
    exit 0
}
trap 'safe-exit' EXIT

"$SCRIPTS"/run.sh

tail -f "$DGL_CHROOT/crawl-master/webserver/run/webtiles.log"
