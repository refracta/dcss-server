#!/bin/bash
source "$DGL_CONF_HOME/dgl-manage.conf"

VERSIONS="git $(seq -s ' ' 0.11 0.31)"
VERSIONS+=" dcssca hellcrawl gnollcrawl bloatcrawl2 gooncrawl xcrawl stoatsoup kimchicrawl bcadrencrawl"

for v in $VERSIONS; do
    if [ ! -d "$DGL_CHROOT/crawl-master/crawl-$v" ]; then
        cp -a "$DGL_CHROOT/crawl-master/crawl-git" "$DGL_CHROOT/crawl-master/crawl-$v"
    fi
done

/home/crawl-dev/dgamelaunch-config/bin/dgl update-trunk
for version in {31..11}; do
  /home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.$version
done
/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc dcssca crawl-forks/dcssca/bugfix 6
/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc hellcrawl crawl-forks/hellcrawl/bugfix 6
/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc gnollcrawl crawl-forks/gnollcrawl/bugfix 6
/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc bloatcrawl2 bloatcrawl2/master 7
/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc stoatsoup stoatsoup/master
/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc gooncrawl gooncrawl/gooncrawl_stable 7
/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc xcrawl crawl-forks/xcrawl/bugfix 7
/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc kimchicrawl crawl-forks/kimchicrawl/bugfix 7
/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc bcadrencrawl bcadrencrawl/bCrawl
