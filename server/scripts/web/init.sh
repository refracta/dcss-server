#!/bin/bash
source "$DGL_CONF_HOME/dgl-manage.conf"
source "$DGL_CONF_HOME/versions.conf"
BASE_DIR="/var/www/crawl/meta"

sudo mkdir /var/www/crawl
cd /var/www/crawl
sudo ln -s $DGL_CHROOT/dgldir/morgue/
sudo ln -s $DGL_CHROOT/dgldir/rcfiles/
sudo ln -s $DGL_CHROOT/dgldir/ttyrec/

for v in $VERSIONS; do
    sudo mkdir -p $BASE_DIR/crawl-$v/
    cd $BASE_DIR/crawl-$v/
    sudo ln -s $DGL_CHROOT/crawl-master/crawl-$v/saves/logfile
    sudo ln -s $DGL_CHROOT/crawl-master/crawl-$v/saves/logfile-sprint
    sudo ln -s $DGL_CHROOT/crawl-master/crawl-$v/saves/logfile-descent
    sudo ln -s $DGL_CHROOT/crawl-master/crawl-$v/saves/logfile-zotdef
    sudo ln -s $DGL_CHROOT/crawl-master/crawl-$v/saves/milestones
    sudo ln -s $DGL_CHROOT/crawl-master/crawl-$v/saves/milestones-sprint
    sudo ln -s $DGL_CHROOT/crawl-master/crawl-$v/saves/milestones-descent
    sudo ln -s $DGL_CHROOT/crawl-master/crawl-$v/saves/milestones-zotdef
    sudo ln -s $DGL_CHROOT/crawl-master/crawl-$v/saves/scores
    sudo ln -s $DGL_CHROOT/crawl-master/crawl-$v/saves/scores-sprint
    sudo ln -s $DGL_CHROOT/crawl-master/crawl-$v/saves/scores-descent
    sudo ln -s $DGL_CHROOT/crawl-master/crawl-$v/saves/scores-zotdef
done
