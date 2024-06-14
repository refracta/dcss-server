#!/bin/bash
source "$DGL_CONF_HOME/dgl-manage.conf"

VERSIONS="$(seq 11 31 | sed 's/^/0./')"
VERSIONS+=" dcssca hellcrawl gnollcrawl bloatcrawl2 gooncrawl xcrawl stoatsoup bcadrencrawl kimchicrawl addedcrawl"

for v in $VERSIONS; do
    cp -a --no-clobber "$DGL_CHROOT/crawl-master/crawl-init" "$DGL_CHROOT/crawl-master/crawl-$v"
done

dgl update-trunk
for version in {31..11}; do
  dgl update-stable 0.$version
done
dgl update-gcc dcssca crawl-forks/dcssca/bugfix 6
dgl update-gcc hellcrawl crawl-forks/hellcrawl/bugfix 6
dgl update-gcc gnollcrawl crawl-forks/gnollcrawl/bugfix 6
dgl update-gcc bloatcrawl2 bloatcrawl2/master 7
dgl update-gcc stoatsoup stoatsoup/master
dgl update-gcc gooncrawl gooncrawl/gooncrawl_stable 7
dgl update-gcc xcrawl crawl-forks/xcrawl/bugfix 7
dgl update-gcc bcadrencrawl bcadrencrawl/bCrawl
dgl update-gcc kimchicrawl crawl-forks/kimchicrawl/bugfix 7
dgl update-gcc addedcrawl crawl-forks/addedcrawl/bugfix 7
