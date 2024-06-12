#!/bin/bash

if [ ! -d "$DGL_CONF_HOME" ] || [ -z "$(ls -A "$DGL_CONF_HOME")" ]; then
    mkdir -p "$DGL_CONF_HOME"
    cp -r "/usr/src/dgamelaunch-config"/* "$DGL_CONF_HOME"
fi

$TARGET_DIR/entrypoint.sh
