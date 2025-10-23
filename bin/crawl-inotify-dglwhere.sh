#! /bin/bash

#assert-chroot-exists
cat-error <<EOF
$SCRIPT_NAME: Monitors Crawl .where files and creates .dglwhere files for the
              dgamelaunch menu to display

EOF

if [[ "$UID" != "0" && "$USER" != "$DGL_USER" ]]; then
    abort-saying "This script must be run as root or $DGL_USER"
fi

# SUDO=

# if [[ "$USER" != "$DGL_USER" ]]; then
#     SUDO="sudo -u $DGL_USER"
# fi
$SUDO perl "$DGL_CONF_HOME/bin/crawl-inotify-dglwhere.pl" "$DGLDIR" "$MORGUEDIR" "$@"
