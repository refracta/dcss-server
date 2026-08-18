#!/bin/bash
source "$DGL_CONF_HOME/dgl-manage.conf"
source "$DGL_CONF_HOME/versions.conf"

for v in $VERSIONS; do
    if [ "$v" == "git" ]; then
        continue
    fi
    cp -a --update=none "$DGL_CHROOT/crawl-master/crawl-init" "$DGL_CHROOT/crawl-master/crawl-$v"
done

dgl update-trunk | tee -a /home/crawl-dev/logs/trunk.log 
for version in {34..11}; do
  dgl update-stable 0.$version | tee -a /home/crawl-dev/logs/stable.log 
done
dgl update-gcc nostalgia crawl-forks/nostalgia/bugfix 6 2>&1 | tee -a /home/crawl-dev/logs/forks.log 
dgl update-gcc yiufcrawl crawl-forks/yiufcrawl/bugfix 6 2>&1 | tee -a /home/crawl-dev/logs/forks.log 
dgl update-gcc oofcrawl crawl-forks/oofcrawl/bugfix 6 2>&1 | tee -a /home/crawl-dev/logs/forks.log 
dgl update-gcc boggartcrawl crawl-forks/boggartcrawl/bugfix 6 2>&1 tee -a /home/crawl-dev/logs/forks.log
dgl update-gcc dcssca crawl-forks/dcssca/bugfix 6 2>&1 | tee -a /home/crawl-dev/logs/forks.log 
dgl update-gcc hellcrawl crawl-forks/hellcrawl/bugfix 6 2>&1 | tee -a /home/crawl-dev/logs/forks.log 
dgl update-gcc housing refracta/housing 2>&1 | tee -a /home/crawl-dev/logs/forks.log
dgl update-gcc gnollcrawl crawl-forks/gnollcrawl/bugfix 6 2>&1 | tee -a /home/crawl-dev/logs/forks.log 
dgl update-gcc bcrawl bcrawl/master 2>&1 | tee -a /home/crawl-dev/logs/forks.log 
dgl update-gcc bloatcrawl2 bloatcrawl2/master 7 2>&1 | tee -a /home/crawl-dev/logs/forks.log 
dgl update-gcc stoatsoup stoatsoup/master 2>&1 | tee -a /home/crawl-dev/logs/forks.log 
dgl update-gcc gooncrawl gooncrawl/gooncrawl_stable 7 2>&1 | tee -a /home/crawl-dev/logs/forks.log 
dgl update-gcc xcrawl crawl-forks/xcrawl/bugfix 7 2>&1 | tee -a /home/crawl-dev/logs/forks.log 
dgl update-gcc bcadrencrawl bcadrencrawl/bCrawl 2>&1 | tee -a /home/crawl-dev/logs/forks.log 
dgl update-gcc kimchicrawl crawl-forks/kimchicrawl/bugfix 7 2>&1 | tee -a /home/crawl-dev/logs/forks.log 
dgl update-gcc addedcrawl crawl-forks/addedcrawl/bugfix 7 2>&1 | tee -a /home/crawl-dev/logs/forks.log 
dgl update-gcc dcst dcst/test 2>&1 | tee -a /home/crawl-dev/logs/forks.log
