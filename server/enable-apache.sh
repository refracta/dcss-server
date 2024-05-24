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

sudo mkdir /var/www/crawl/meta/
sudo mkdir /var/www/crawl/meta/git/
cd /var/www/crawl/meta/git/
sudo ln -s $DGL_CHROOT/crawl-master/crawl-git/saves/logfile
sudo ln -s $DGL_CHROOT/crawl-master/crawl-git/saves/logfile-sprint
sudo ln -s $DGL_CHROOT/crawl-master/crawl-git/saves/logfile-descent
sudo ln -s $DGL_CHROOT/crawl-master/crawl-git/saves/logfile-zotdef
sudo ln -s $DGL_CHROOT/crawl-master/crawl-git/saves/milestones
sudo ln -s $DGL_CHROOT/crawl-master/crawl-git/saves/milestones-sprint
sudo ln -s $DGL_CHROOT/crawl-master/crawl-git/saves/milestones-descent
sudo ln -s $DGL_CHROOT/crawl-master/crawl-git/saves/milestones-zotdef
sudo ln -s $DGL_CHROOT/crawl-master/crawl-git/saves/scores
sudo ln -s $DGL_CHROOT/crawl-master/crawl-git/saves/scores-sprint
sudo ln -s $DGL_CHROOT/crawl-master/crawl-git/saves/scores-descent
sudo ln -s $DGL_CHROOT/crawl-master/crawl-git/saves/scores-zotdef

sudo mkdir /var/www/crawl/meta/dcssca/
cd /var/www/crawl/meta/dcssca/
sudo ln -s $DGL_CHROOT/crawl-master/crawl-dcssca/saves/logfile
sudo ln -s $DGL_CHROOT/crawl-master/crawl-dcssca/saves/milestones
sudo ln -s $DGL_CHROOT/crawl-master/crawl-dcssca/saves/scores

sudo mkdir /var/www/crawl/meta/hellcrawl/
cd /var/www/crawl/meta/hellcrawl/
sudo ln -s $DGL_CHROOT/crawl-master/crawl-hellcrawl/saves/logfile
sudo ln -s $DGL_CHROOT/crawl-master/crawl-hellcrawl/saves/milestones
sudo ln -s $DGL_CHROOT/crawl-master/crawl-hellcrawl/saves/scores

sudo mkdir /var/www/crawl/meta/gnollcrawl/
cd /var/www/crawl/meta/gnollcrawl/
sudo ln -s $DGL_CHROOT/crawl-master/crawl-gnollcrawl/saves/logfile
sudo ln -s $DGL_CHROOT/crawl-master/crawl-gnollcrawl/saves/milestones
sudo ln -s $DGL_CHROOT/crawl-master/crawl-gnollcrawl/saves/scores

sudo mkdir /var/www/crawl/meta/bloatcrawl2/
cd /var/www/crawl/meta/bloatcrawl2/
sudo ln -s $DGL_CHROOT/crawl-master/crawl-bloatcrawl2/saves/logfile
sudo ln -s $DGL_CHROOT/crawl-master/crawl-bloatcrawl2/saves/milestones
sudo ln -s $DGL_CHROOT/crawl-master/crawl-bloatcrawl2/saves/scores

sudo mkdir /var/www/crawl/meta/gooncrawl/
cd /var/www/crawl/meta/gooncrawl/
sudo ln -s $DGL_CHROOT/crawl-master/crawl-gooncrawl/saves/logfile
sudo ln -s $DGL_CHROOT/crawl-master/crawl-gooncrawl/saves/milestones
sudo ln -s $DGL_CHROOT/crawl-master/crawl-gooncrawl/saves/scores

sudo mkdir /var/www/crawl/meta/xcrawl/
cd /var/www/crawl/meta/xcrawl/
sudo ln -s $DGL_CHROOT/crawl-master/crawl-xcrawl/saves/logfile
sudo ln -s $DGL_CHROOT/crawl-master/crawl-xcrawl/saves/milestones
sudo ln -s $DGL_CHROOT/crawl-master/crawl-xcrawl/saves/scores

sudo mkdir /var/www/crawl/meta/stoatsoup/
cd /var/www/crawl/meta/stoatsoup/
sudo ln -s $DGL_CHROOT/crawl-master/crawl-stoatsoup/saves/logfile
sudo ln -s $DGL_CHROOT/crawl-master/crawl-stoatsoup/saves/milestones
sudo ln -s $DGL_CHROOT/crawl-master/crawl-stoatsoup/saves/scores

sudo mkdir /var/www/crawl/meta/kimchicrawl/
cd /var/www/crawl/meta/kimchicrawl/
sudo ln -s $DGL_CHROOT/crawl-master/crawl-kimchicrawl/saves/logfile
sudo ln -s $DGL_CHROOT/crawl-master/crawl-kimchicrawl/saves/milestones
sudo ln -s $DGL_CHROOT/crawl-master/crawl-kimchicrawl/saves/scores

sudo mkdir /var/www/crawl/meta/bcadrencrawl/
cd /var/www/crawl/meta/bcadrencrawl/
sudo ln -s $DGL_CHROOT/crawl-master/crawl-bcadrencrawl/saves/logfile
sudo ln -s $DGL_CHROOT/crawl-master/crawl-bcadrencrawl/saves/milestones
sudo ln -s $DGL_CHROOT/crawl-master/crawl-bcadrencrawl/saves/scores

sudo service apache2 reload

