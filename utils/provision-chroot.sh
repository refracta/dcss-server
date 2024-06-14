#!/bin/bash

# automate setting up a fresh chroot for a dgamelaunch-config setup. This will
# work as-is on a clean ubuntu system for a default setup, but you may want to
# examine the values carefully or even manually run it step by step.

# This script mainly deals with the steps that require `chroot` to be
# runnable, and aside from the bind mount step, only deals with chroot-internal
# setup that is not dgl-config-specific.

# TODO: would this script be better as a script that is run from dgl? It would
# at least allow getting the chroot location & dgl-config automatically.

[[ "$UID" != "0" ]] && echo "This script must be run as root" && exit 1

# needs to match the location and value in dgamelaunch.conf obviously
DGL_CONF_HOME=/home/crawl-dev/dgamelaunch-config
DGL_CHROOT=/home/crawl/DGL
LANG=en_US.UTF-8

CRAWL_USER=$(id -u crawl)
if [ $? -ne 0 ]; then echo "No 'crawl' user!"; exit 1; fi
CRAWL_GROUP=$(id -g crawl)
CDEV_USER=$(id -u crawl-dev)
if [ $? -ne 0 ]; then echo "No 'crawl-dev' user!"; exit 1; fi
CDEV_GROUP=$(id -g crawl-dev)

# version here must match the outer distribution. `jammy` = ubuntu 22.04
# note, this command is not really rerunnable without resetting the chroot
# directory...
debootstrap jammy $DGL_CHROOT
if [ $? -ne 0 ]; then
    echo "Provisioning failed in debootstrap."
    exit 1
fi
cp /etc/resolv.conf $DGL_CHROOT/etc/resolv.conf
cp /etc/apt/sources.list $DGL_CHROOT/etc/apt/

# these bind mounts would need to be manually added to the fstab in some setups
if [ ! -e $DGL_CHROOT/proc/ ]; then
    mount --bind /proc/ $DGL_CHROOT/proc
fi
if [ ! -e $DGL_CHROOT/dev/pts ]; then
    mount --bind /dev/pts/ $DGL_CHROOT/dev/pts/
fi

cat << EOF | chroot $DGL_CHROOT/
# minimal package list for running crawl and doing some basic maintenance; you
# may want to curate this further.
apt-get update && \
apt-get -y install locales locales-all && \
sed -i -e "s/# $LANG.*/$LANG.UTF-8 UTF-8/" /etc/locale.gen && \
dpkg-reconfigure --frontend=noninteractive locales && \
update-locale LANG=$LANG && \
apt-get -y install bzip2 python3-minimal ncurses-term sqlite3 libpcre3 liblua5.1-0 autoconf build-essential lsof bison libncursesw5-dev libsqlite3-dev flex sudo libbot-basicbot-perl vim && \
# match the uids to the containing system
groupadd crawl -g $CRAWL_GROUP && \
groupadd crawl-dev -g $CDEV_GROUP && \
useradd crawl -u $CRAWL_USER -g $CRAWL_GROUP && \
useradd crawl-dev -u $CDEV_USER -g $CDEV_GROUP
EOF

if [ $? -ne 0 ]; then
    echo "Provisioning failed while installing packages."
    exit 1
fi

# In order for the webtiles server to work when chrooted, it needs access to
# any packages that are dynamically imported. In general this is very few, but
# Tornado versions >3 rely heavily on dynamic imports. So we copy it into the
# chroot from outside.
# An alternative would be to install a full python setup into the chroot,
# including this package, but this is extremely heavy. Another alternative might
# be to simply copy the outer python library in (though note the python-minimal
# install above). However, we do want tornado to exactly match...
#
# I'm not sure if this is a reliable recipe for finding package locations in
# general, but it seems to work for tornado.
TORNADO_PATH=$(python3 -c "import tornado; print(tornado.__path__[0])")
if [ $? -ne 0 ]; then
    echo "Cannot find path to tornado; please rerun or manually copy the package into the chroot."
    exit 1
fi

# n.b. --parents here is GNU-specific
cp -R --parents "${TORNADO_PATH}" "$DGL_CHROOT/"
