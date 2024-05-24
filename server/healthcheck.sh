#!/bin/bash

# this script assumes a default dgamelaunch-config configuration

test -e /crawl-master/webserver/run/webtiles.pid || exit 1
# if the server crashes, there may be a stale pid file.
ps w -u crawl | grep -q server.py || exit 1
# is server up?
curl -fs http://localhost:8080/ > /dev/null || exit 1
# is it serving the correct thing?
# the -N is necessary here because of a weird interaction with grqp -q
curl -Nfs http://localhost:8080/ | grep -q "Dungeon Crawl Stone Soup" || exit 1
# is sshd at least running?
test -e /var/run/sshd.pid || exit 1
# TODO check sshd more fully

echo "Health check: webtiles is up and running!"
