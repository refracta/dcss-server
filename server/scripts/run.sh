#!/bin/bash

service apache2 start

spawn-fcgi -s /var/run/fcgiwrap.socket -U www-data -G www-data /usr/sbin/fcgiwrap
service nginx start

/etc/init.d/ssh start

dgl crawl-inotify-dglwhere

rm "$CHROOT_WEBDIR/run/webtiles.pid" #in case the container was stopped without cleaning up pid file in volume
/etc/init.d/webtiles restart
