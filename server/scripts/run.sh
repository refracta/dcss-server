#!/bin/bash

cron
service apache2 start

spawn-fcgi -s /var/run/fcgiwrap.socket -U www-data -G www-data /usr/sbin/fcgiwrap
service nginx start

"$SCRIPTS"/utils/setup-ssh-keys.sh
/etc/init.d/ssh start
sudo -u crawl nohup ttyd -p 8022 -t 'theme={"background": "#000000"}' -W dgamelaunch &

# Limits CPU usage for builds performed with cron.
nohup cpulimit -e cc1plus -l 20 &

dgl crawl-inotify-dglwhere

rm "$CHROOT_WEBDIR/run/webtiles.pid" #in case the container was stopped without cleaning up pid file in volume
/etc/init.d/webtiles restart
