#! /bin/bash

NAME=$1

source "$DGL_CONF_HOME/versions.conf"

for v in $VERSIONS; do
    cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-$v-settings/init.txt" "%%CHROOT_RCFILESDIR%%/crawl-$v/$NAME.rc"
    cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-git.macro" "%%CHROOT_RCFILESDIR%%/crawl-$v/$NAME.macro"
done

mkdir -p "%%CHROOT_MORGUEDIR%%/$NAME"
mkdir -p "%%CHROOT_TTYRECDIR%%/$NAME"
