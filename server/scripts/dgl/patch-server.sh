#!/bin/bash

sed -i 's/do_chroot()//g' "$CHROOT_CRAWL_BASEDIR/webserver/webtiles/server.py"
