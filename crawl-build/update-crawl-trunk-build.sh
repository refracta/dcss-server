#!/bin/bash

set -e
lock-or-die crawl-update "someone is already updating the crawl build"

source $DGL_CONF_HOME/crawl-git.conf
source ~/.bashrc
check-versions-db-exists

export DESTDIR=$CRAWL_BASEDIR

check-crawl-basedir-exists
enable-prompts $*

TODAY="$(dgl-today)"

# First argument can be a revision (SHA) to build
REVISION="$1"
./update-public-repository.sh $BRANCH "$REVISION"

REVISION="$(git-do rev-parse HEAD | cut -c 1-10)"
REVISION_FULL="$(git-do describe --long HEAD)"
REVISION_OLD="$(echo "select hash from versions order by time desc limit 1;" | sqlite3 ${VERSIONS_DB})"

[[ "$REVISION" == "$REVISION_OLD" ]] && \
    abort-saying "Nothing new to install at the moment: you asked for $REVISION_FULL and it's already installed"

prompt "start update build"

cd $CRAWL_REPOSITORY_DIR/crawl-ref

echo "Copying CREDITS to docs/crawl_credits.txt..."
cp CREDITS.txt docs/crawl_credits.txt

dgl-git-log() {
    git-do log --pretty=tformat:"--------------------------------------------------------------------------------%n%h | %an | %ci%n%n%s%n%b" "$@" | grep -v "git-svn-id" | awk 1 RS= ORS="\n\n" | fold -s
}

echo "Creating changelog in docs/crawl_changelog.txt..."
dgl-git-log $BRANCH > docs/crawl_changelog.txt

if prompts-enabled; then
    echo "Changes to $BRANCH from $REVISION_OLD .. $REVISION"
    dgl-git-log ${REVISION_OLD}..${REVISION} | less
fi

prompt "compile ${GAME}-${REVISION}"

# REMEMBER to adjust /var/lib/dgamelaunch/sbin/install-trunk.sh as well if make parameters change!
##################################################################################################
export CCACHE_IGNOREOPTIONS="-DSAVE_DIR_PATH -DSHARED_DIR_PATH -DDATA_DIR_PATH -DWEB_DIR_PATH"
say-do crawl-do nice make CC="ccache gcc" CXX="ccache g++" -C source \
    GAME=${GAME}-${REVISION} \
    GAME_MAIN=${GAME} MCHMOD=0755 MCHMOD_SAVEDIR=755 \
    INSTALL_UGRP=$CRAWL_UGRP \
    WEBTILES=YesPlease USE_DGAMELAUNCH=YesPlease WIZARD=YesPlease \
    STRIP=true DESTDIR=${DESTDIR} prefix= bin_prefix=/bin \
    SAVEDIR=$CHROOT_CRAWL_BASEDIR/${GAME}-${REVISION}/saves \
    DATADIR=$CHROOT_CRAWL_BASEDIR/${GAME}-${REVISION}/data \
    WEBDIR=$CHROOT_CRAWL_BASEDIR/${GAME}-${REVISION}/data/web \
    SHAREDDIR=$CHROOT_CRAWL_BASEDIR/${GAME}/saves \
    USE_PCRE=y \
    EXTERNAL_FLAGS_L="-g"

prompt "install ${GAME}-${REVISION}"

if [[ "$(uname)" != "Darwin" ]] && {
        ps -fC ${GAME}-${REVISION} |
        awk '{ print $1" "$2"\t "$5" "$7"\t "$8" "$9" "$10 }' |
        grep ^"$DGL_USER";
    }
then
    abort-saying "There are already active instances of this version (${REVISION_FULL}) running"
fi

echo "Searching for version tags..."
export SGV_MAJOR=$($CRAWL_BUILD_DIR/crawl-tag-major-version.sh)
[[ -n "$SGV_MAJOR" ]] || abort-saying "Couldn't find save major version"
echo "Save major version: $SGV_MAJOR"
export SGV_MINOR="0"

say-do sudo -H $DGL_CHROOT/sbin/install-trunk.sh "$REVISION" \
    "$REVISION_FULL" "$SGV_MAJOR" "$SGV_MINOR"

announce "Unstable branch on $DGL_SERVER updated to: ${REVISION_FULL} (${SGV_MAJOR})"

echo "All done."
echo
