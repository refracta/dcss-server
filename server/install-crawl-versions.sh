#!/bin/bash
source "$DGL_CONF_HOME/dgl-manage.conf"

cp -a --no-clobber $DGL_CHROOT/crawl-master/crawl-git $DGL_CHROOT/crawl-master/crawl-dcssca
cp -a --no-clobber $DGL_CHROOT/crawl-master/crawl-git $DGL_CHROOT/crawl-master/crawl-hellcrawl
cp -a --no-clobber $DGL_CHROOT/crawl-master/crawl-git $DGL_CHROOT/crawl-master/crawl-gnollcrawl
cp -a --no-clobber $DGL_CHROOT/crawl-master/crawl-git $DGL_CHROOT/crawl-master/crawl-bloatcrawl2
cp -a --no-clobber $DGL_CHROOT/crawl-master/crawl-git $DGL_CHROOT/crawl-master/crawl-gooncrawl
cp -a --no-clobber $DGL_CHROOT/crawl-master/crawl-git $DGL_CHROOT/crawl-master/crawl-xcrawl
cp -a --no-clobber $DGL_CHROOT/crawl-master/crawl-git $DGL_CHROOT/crawl-master/crawl-stoatsoup
cp -a --no-clobber $DGL_CHROOT/crawl-master/crawl-git $DGL_CHROOT/crawl-master/crawl-kimchicrawl
cp -a --no-clobber $DGL_CHROOT/crawl-master/crawl-git $DGL_CHROOT/crawl-master/crawl-bcadrencrawl
/home/crawl-dev/dgamelaunch-config/bin/dgl update-trunk
# /home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.31
# /home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.30
# /home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.29
# /home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.28
# /home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.27
# /home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.26
# /home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.25
# /home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.24
# /home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.23
/home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.22
/home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.21
/home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.20
/home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.19
/home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.18
/home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.17
/home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.16
/home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.15
/home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.14
/home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.13
/home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.12
/home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.11
#/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc6 dcssca crawl-forks/dcssca/bugfix
#/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc6 hellcrawl crawl-forks/hellcrawl/bugfix
#/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc6 gnollcrawl crawl-forks/gnollcrawl/bugfix
#/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc7 bloatcrawl2 bloatcrawl2/master
#/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc stoatsoup stoatsoup/master
#/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc7 gooncrawl gooncrawl/gooncrawl_stable
#/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc7 xcrawl crawl-forks/xcrawl/bugfix
#/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc7 kimchicrawl crawl-forks/kimchicrawl/bugfix
# /home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc bcadrencrawl bcadrencrawl/bCrawl #Currently bcadren crawl main branch `bCrawl` is simply not compiling due to a programming error. I've left a message to bcadren, no need to try compiling until it's fixed
