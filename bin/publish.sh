#! /bin/bash

# assert-chroot-exists

# shellcheck source=crawl-git.conf
source "$DGL_CONF_HOME/crawl-git.conf"

export DGL_CONF_HOME DGL_CHROOT
exec perl "$DGL_CONF_HOME/bin/publish.pl" "$@"
