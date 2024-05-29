#!/bin/bash

VERSION=${1:-}

# Quoting for =~ changed from bash 3.0 to 3.2; using a variable for the
# regexp works with both.
# VERS_RE='^[0-9]+.[0-9]+$'
# if [[ ! $VERSION =~ $VERS_RE ]]; then
#    echo "Bad crawl version $VERSION"
#    exit 1
# fi

set -e
lock-or-die crawl-update "someone is already updating the crawl build"

source $DGL_CONF_HOME/crawl-git.conf
source ~/.bashrc
GAME=crawl-$VERSION

export DESTDIR=$CRAWL_BASEDIR
BRANCH=origin/stone_soup-$VERSION
if [[ $VERSION != [0-9]* ]]; then
    BRANCH=origin/$VERSION
fi

check-crawl-basedir-exists
enable-prompts $*

TODAY="$(dgl-today)"

# Second argument can be a revision (SHA) to build
REVISION="$2"
./update-public-repository.sh $BRANCH "$REVISION"

REVISION="$(git-do rev-parse HEAD | cut -c 1-7)"
REVISION_FULL="$(git-do describe --long HEAD)"
VER_STR="$(git-do describe HEAD)"
VER_STR_OLD="$(($CRAWL_BINARY_PATH/$GAME -version 2>/dev/null || true) | sed -ne 's/Crawl version //p')"
REVISION_OLD="${VER_STR_OLD##*-g}"

[[ "$REVISION" == "$REVISION_OLD" || "$VER_STR" = "$VER_STR_OLD" ]] && \
    abort-saying "Nothing new to install at the moment: you asked for $REVISION_FULL and it's already installed"

# Legacy version patch & setting
VERSION_INT=$(echo $VERSION | cut -d. -f2)
CC="ccache gcc"
CXX="ccache g++"

if (( VERSION_INT <= 24 )); then
  if [[ -f $CRAWL_REPOSITORY_DIR/crawl-ref/source/util/species-gen.py ]]; then
    echo "Patching collections.MutableMapping to collections.abc.MutableMapping in species-gen.py..."
    sed -i 's/collections.MutableMapping/collections.abc.MutableMapping/g' $SPECIES_GEN_PATH
  fi

  echo "Setting compiler to gcc-6 and g++-6..."
  CC="ccache gcc-6"
  CXX="ccache g++-6"
fi

if (( VERSION_INT <= 23 )); then
  echo "Patching yaml.load(open(f_path)) to yaml.safe_load(open(f_path)) in species-gen.py..."
  sed -i 's/yaml.load(open(f_path))/yaml.safe_load(open(f_path))/g' $CRAWL_REPOSITORY_DIR/crawl-ref/source/util/species-gen.py
fi

if (( VERSION_INT <= 16 )); then
  echo "Patching regex in gen-mi-enum..."
  sed -i 's/monster_info_flags\\n{\\n/monster_info_flags\\n\\{\\n/' $CRAWL_REPOSITORY_DIR/crawl-ref/source/util/gen-mi-enum
fi

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
    dgl-git-log ${REVISION_OLD:+$REVISION_OLD..}${REVISION} | less
fi

prompt "compile ${GAME} (${REVISION})"

# REMEMBER to adjust /var/lib/dgamelaunch/sbin/install-stable.sh as well if make parameters change!
##################################################################################################

say-do crawl-do nice make CC="$CC" CXX="$CXX" -C source \
    GAME=${GAME} \
    GAME_MAIN=${GAME} MCHMOD=0755 MCHMOD_SAVEDIR=755 \
    INSTALL_UGRP=$CRAWL_UGRP \
    WEBTILES=YesPlease USE_DGAMELAUNCH=YesPlease WIZARD=YesPlease \
    STRIP=true DESTDIR=${DESTDIR} prefix= bin_prefix=/bin \
    SAVEDIR=$CHROOT_CRAWL_BASEDIR/${GAME}/saves \
    DATADIR=$CHROOT_CRAWL_BASEDIR/${GAME}/data \
    WEBDIR=$CHROOT_CRAWL_BASEDIR/${GAME}/data/web \
    USE_PCRE=y \
    EXTERNAL_FLAGS_L="-g"

prompt "install ${GAME} (${REVISION})"

say-do sudo -H $DGL_CHROOT/sbin/install-stable.sh "$VERSION"

if [[ $VERSION = [0-9]* ]]; then
    SUPER_VER="Stable"
else
    SUPER_VER="Experimental"
fi

announce "$SUPER_VER ($VERSION) branch on $DGL_SERVER updated to: ${REVISION_FULL}"

echo "All done."
echo
