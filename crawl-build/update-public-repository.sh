#!/bin/bash

set -e

source $DGL_CONF_HOME/sh-utils
source $DGL_CONF_HOME/crawl-git.conf

REPO_DIR=$PWD/$CRAWL_REPOSITORY_DIR

clone-crawl-ref() {
    if [[ -d "$CRAWL_REPOSITORY_DIR" && -d "$CRAWL_REPOSITORY_DIR/.git" && -z "$FORCE_CLONE" ]]; then
        say "Repository already exists; skipping clone"
    else
        if [[ -n "$FORCE_CLONE" && -d "$CRAWL_REPOSITORY_DIR" ]]; then
            say "Removing existing repository due to FORCE_CLONE"
            rm -rf "$CRAWL_REPOSITORY_DIR"
        fi
        CMDLINE="git clone $CRAWL_GIT_URL $CRAWL_REPOSITORY_DIR"
        say "$CMDLINE"
        $CMDLINE
    fi
    say "Add Fork Remotes"
    ensure-remote crawl-forks https://github.com/refracta/crawl-forks.git
    ensure-remote gooncrawl https://github.com/Floodkiller/crawl.git
    ensure-remote bloatcrawl2 https://github.com/Hellmonk/bloatcrawl2.git
    ensure-remote dcst https://github.com/Hellmonk/dcst.git
    ensure-remote stoatsoup https://github.com/damerell/crawl.git
    ensure-remote bcadrencrawl https://github.com/Bcadren/crawl.git
    ensure-remote bcrawl https://github.com/b-crawl/bcrawl.git
    say "Update branches for all forks"
    git --git-dir="./$CRAWL_REPOSITORY_DIR/.git" submodule update --init
    git --git-dir="./$CRAWL_REPOSITORY_DIR/.git" fetch --all
}

ensure-remote() {
    local name="$1"
    local url="$2"
    if ! git --git-dir="./$CRAWL_REPOSITORY_DIR/.git" remote | grep -q "^$name$"; then
        git --git-dir="./$CRAWL_REPOSITORY_DIR/.git" remote add "$name" "$url"
    fi
}

update-crawl-ref() {
    say "Updating git repository $REPO_DIR"
    ( cd $REPO_DIR && git checkout -f &&
        git reset --hard &&
        git clean -fdx &&
        git fetch --all &&
        git checkout -f -B $BRANCH refs/remotes/$BRANCH &&
        git pull )
    if [[ -n "$REVISION" ]]; then
        say "Checking out requested revision: $REVISION"
        ( cd $REPO_DIR && git checkout -f "$REVISION" && git reset --hard && git clean -fdx )
    fi
}

update-submodules() {
    say "Updating git submodules in $REPO_DIR"
    # Legacy support (VERSION <= 0.15)
    sed -i 's/git:\/\/gitorious.org/https:\/\/github.com/g' $REPO_DIR/.gitmodules
    ( cd $REPO_DIR && git submodule update --init )
}

apply-patch() {
  if [[ -f $REPO_DIR/crawl-ref/source/util/species-gen.py ]]; then
    echo "Patching collections.MutableMapping to collections.abc.MutableMapping in species-gen.py... (VERSION <= 0.24)"
    sed -i 's/collections.MutableMapping/collections.abc.MutableMapping/g' $REPO_DIR/crawl-ref/source/util/species-gen.py
    echo "Patching yaml.load(open(f_path)) to yaml.safe_load(open(f_path)) in species-gen.py... (VERSION <= 0.23)"
    sed -i 's/yaml.load(open(f_path))/yaml.safe_load(open(f_path))/g' $REPO_DIR/crawl-ref/source/util/species-gen.py
  fi
  if [[ -f $REPO_DIR/crawl-ref/source/util/gen-mi-enum ]]; then
    echo "Patching regex in gen-mi-enum... (VERSION <= 0.16)"
    sed -i 's/monster_info_flags\\n{\\n/monster_info_flags\\n\\{\\n/' $REPO_DIR/crawl-ref/source/util/gen-mi-enum
  fi
  if [[ "$BRANCH" == "bcadrencrawl/bCrawl" ]] && [[ -f $REPO_DIR/crawl-ref/source/describe-spells.cc ]]; then
    echo "Patching broken if condition in describe-spells.cc... (BcadrenCrawl)"
    sed -i 's/if (!testbits(get_spell_flags(spell), spflag::MR_check) || spell == SPELL_PAIN))$/if (!testbits(get_spell_flags(spell), spflag::MR_check) || spell == SPELL_PAIN)/' $REPO_DIR/crawl-ref/source/describe-spells.cc
  fi
  if [[ "$BRANCH" == origin* ]]; then
    echo "Patching SRC_BRANCH variable... (DCSS 'master' & 'stone_soup-%' branches)"
    sed -i 's#git rev-parse --abbrev-ref HEAD || echo release#(git rev-parse --abbrev-ref HEAD || echo release) | sed "s|^heads/origin/||"#' $REPO_DIR/crawl-ref/source/Makefile
  else
    echo "Patching SRC_BRANCH variable... (Forks, Disable EXPERIMENTAL_BRANCH options)"
    sed -i 's#git rev-parse --abbrev-ref HEAD || echo release#echo release#' $REPO_DIR/crawl-ref/source/Makefile
  fi
}

BRANCH=$1
REVISION="$2"
clone-crawl-ref
if [[ -n "$FORCE_CLONE" ]]; then
    say "FORCE_CLONE requested; repository cloned. Exiting."
    exit 0
fi
[[ -n "$BRANCH" ]] || abort-saying "$0: Checkout branch not specified!"
update-crawl-ref
update-submodules
apply-patch
