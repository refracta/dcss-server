#! /bin/bash
#
# Publish only the dgamelaunch config file.
#

# assert-chroot-exists
set -- "--confirm" "--match" "dgamelaunch.conf" "$@"
source "$DGL_CONF_HOME/bin/publish.sh"
