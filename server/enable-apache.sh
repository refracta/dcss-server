#!/bin/bash
source "$DGL_CONF_HOME/dgl-manage.conf"

sudo mkdir /var/www/crawl
cd /var/www/crawl
sudo ln -s $DGL_CHROOT/dgldir/morgue/
sudo ln -s $DGL_CHROOT/dgldir/rcfiles/
sudo ln -s $DGL_CHROOT/dgldir/ttyrec/
sudo service apache2 start
sudo a2enmod rewrite
sudo a2dissite 000-default #remove apache default site because it interferes with port 80
sudo a2ensite httpd #use the simplified crawl config for serving files on port 80 inside the container

VERSIONS="git $(seq 11 31 | sed 's/^/0./')"
VERSIONS+=" dcssca hellcrawl gnollcrawl bloatcrawl2 gooncrawl xcrawl stoatsoup kimchicrawl bcadrencrawl"
BASE_DIR="/var/www/crawl/meta"

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

sudo service apache2 reload

