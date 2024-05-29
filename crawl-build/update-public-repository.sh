#!/bin/bash

set -e

source $DGL_CONF_HOME/sh-utils
source $DGL_CONF_HOME/crawl-git.conf

REPO_DIR=$PWD/$CRAWL_REPOSITORY_DIR

clone-crawl-ref() {
    if [[ -d "$CRAWL_REPOSITORY_DIR" && -d "$CRAWL_REPOSITORY_DIR/.git" ]]; then
        return 0
    fi
    CMDLINE="git clone $CRAWL_GIT_URL $CRAWL_REPOSITORY_DIR"
    say "$CMDLINE"
    $CMDLINE
    say "Add Fork Remotes"
    say "Crawl-forks" && git --git-dir="./$CRAWL_REPOSITORY_DIR/.git" remote add crawl-forks https://github.com/Rytisgit/crawl-forks.git
    say "GoonCrawl" && git --git-dir="./$CRAWL_REPOSITORY_DIR/.git" remote add gooncrawl https://github.com/Floodkiller/crawl.git
    say "BloatCrawl 2" && git --git-dir="./$CRAWL_REPOSITORY_DIR/.git" remote add bloatcrawl2 https://github.com/Hellmonk/bloatcrawl2.git
    say "Stoat Soup" && git --git-dir="./$CRAWL_REPOSITORY_DIR/.git" remote add stoatsoup https://github.com/damerell/crawl.git
    say "BcadrenCrawl" && git --git-dir="./$CRAWL_REPOSITORY_DIR/.git" remote add bcadrencrawl https://github.com/Bcadren/crawl.git
    say "Update branches for all forks"
    git --git-dir="./$CRAWL_REPOSITORY_DIR/.git" submodule update --init
    git --git-dir="./$CRAWL_REPOSITORY_DIR/.git" fetch --all
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

BRANCH=$1
REVISION="$2"
[[ -n "$BRANCH" ]] || abort-saying "$0: Checkout branch not specified!"
clone-crawl-ref
update-crawl-ref
update-submodules
