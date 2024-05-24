#! /bin/sh

NAME=$1

VERSIONS="git $(seq 25 25 | sed 's/^/0./')"

for v in $VERSIONS; do
    cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-$v-settings/init.txt" "%%CHROOT_RCFILESDIR%%/crawl-$v/$NAME.rc"
    cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-git.macro" "%%CHROOT_RCFILESDIR%%/crawl-$v/$NAME.macro"
done

cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-dcssca-settings/init.txt" "%%CHROOT_RCFILESDIR%%/crawl-dcssca/$NAME.rc"
cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-git.macro" "%%CHROOT_RCFILESDIR%%/crawl-dcssca/$NAME.macro"

cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-hellcrawl-settings/init.txt" "%%CHROOT_RCFILESDIR%%/crawl-hellcrawl/$NAME.rc"
cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-git.macro" "%%CHROOT_RCFILESDIR%%/crawl-hellcrawl/$NAME.macro"

cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-gnollcrawl-settings/init.txt" "%%CHROOT_RCFILESDIR%%/crawl-gnollcrawl/$NAME.rc"
cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-git.macro" "%%CHROOT_RCFILESDIR%%/crawl-gnollcrawl/$NAME.macro"

cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-bloatcrawl2-settings/init.txt" "%%CHROOT_RCFILESDIR%%/crawl-bloatcrawl2/$NAME.rc"
cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-git.macro" "%%CHROOT_RCFILESDIR%%/crawl-bloatcrawl2/$NAME.macro"

cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-gooncrawl-settings/init.txt" "%%CHROOT_RCFILESDIR%%/crawl-gooncrawl/$NAME.rc"
cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-git.macro" "%%CHROOT_RCFILESDIR%%/crawl-gooncrawl/$NAME.macro"

cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-xcrawl-settings/init.txt" "%%CHROOT_RCFILESDIR%%/crawl-xcrawl/$NAME.rc"
cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-git.macro" "%%CHROOT_RCFILESDIR%%/crawl-xcrawl/$NAME.macro"

cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-stoatsoup-settings/init.txt" "%%CHROOT_RCFILESDIR%%/crawl-stoatsoup/$NAME.rc"
cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-git.macro" "%%CHROOT_RCFILESDIR%%/crawl-stoatsoup/$NAME.macro"

cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-kimchicrawl-settings/init.txt" "%%CHROOT_RCFILESDIR%%/crawl-kimchicrawl/$NAME.rc"
cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-git.macro" "%%CHROOT_RCFILESDIR%%/crawl-kimchicrawl/$NAME.macro"

cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-bcadrencrawl-settings/init.txt" "%%CHROOT_RCFILESDIR%%/crawl-bcadrencrawl/$NAME.rc"
cp --no-clobber "%%CHROOT_DGLDIR%%/data/crawl-git.macro" "%%CHROOT_RCFILESDIR%%/crawl-bcadrencrawl/$NAME.macro"

mkdir -p "%%CHROOT_MORGUEDIR%%/$NAME"
mkdir -p "%%CHROOT_TTYRECDIR%%/$NAME"
