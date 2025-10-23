#! /bin/bash
#
# Publish everything other than the dgamelaunch.conf file.
#

# assert-chroot-exists
set -- "--confirm" "--skip" "dgamelaunch.conf" "$@"
source "$DGL_CONF_HOME/bin/publish.sh"
