FROM ubuntu:24.04

# See README.md for what this does and why

# This Dockerfile will fail if the repository is not used as the build context.
# do an early COPY step to ensure that build is being invoked correctly.

ENV DGL_CHROOT=""
ENV DGL_CONF_HOME=/home/crawl-dev/dgamelaunch-config/
ARG DEBIAN_FRONTEND=noninteractive
ARG TERM=dumb

# basic prerequisites
RUN apt-get update
RUN apt-get install -y locales locales-all
ENV LANG=en_US.UTF-8
RUN sed -i -e "s/# $LANG.*/$LANG.UTF-8 UTF-8/" /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG=$LANG
RUN apt-get install -y --no-install-recommends sudo git bash build-essential autoconf automake bison libncursesw5-dev flex liblua5.1-0-dev libsqlite3-dev libz-dev locales vim nano locales-all pkg-config python3 python3-pip python3-yaml ccache libpng-dev sqlite3 libpcre3 libpcre3-dev advancecomp pngcrush openssh-server curl libfl-dev cron jq
RUN apt-get install -y apache2 libcgi-pm-perl libdbi-perl libdbd-sqlite3-perl cpanminus && cpanm Linux::Inotify2
RUN apt-get install -y nginx nginx-extras fcgiwrap spawn-fcgi && mkdir -p /var/run/fcgiwrap
RUN echo "deb [trusted=yes] http://archive.ubuntu.com/ubuntu/ bionic main universe" >> /etc/apt/sources.list && \
    echo "deb [trusted=yes] http://archive.ubuntu.com/ubuntu/ focal main universe" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y gcc-6 g++-6 gcc-7 g++-7 && \
    apt-get install -y libsdl1.2-dev libsdl-image1.2-dev

RUN pip3 install tornado jinja2 --break-system-packages \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
&& ln -s /usr/bin/python3 /usr/bin/python

RUN useradd -m crawl \
&& useradd -m crawl-dev \
&& usermod -G root -a crawl \
&& usermod -G root -a crawl-dev \
&& usermod -G www-data -a crawl \
&& usermod -G www-data -a crawl-dev \
&& usermod -G crawl -a root \
&& usermod -G crawl -a www-data \
&& usermod -G crawl-dev -a root \
&& usermod -G crawl-dev -a www-data

# CCache
# Update symlinks
RUN /usr/sbin/update-ccache-symlinks

# Prepend ccache into the PATH
RUN echo 'export PATH="/usr/lib/ccache:$PATH"' | tee -a ~/.bashrc
RUN ccache -F 0
RUN ccache -M 0

WORKDIR /home/crawl-dev

# set up dgamelaunch
# TODO: what are these directories in ~crawl-dev used for? `run` doesn't exist
# TODO: Fix logs, announcements.log, run
USER crawl-dev
RUN mkdir logs \
    && touch announcements.log \
    && mkdir run \
    && mkdir dgamelaunch-config dgamelaunch-config/utils/ \
    && git clone https://github.com/crawl/dgamelaunch.git \
    && cd dgamelaunch && ./autogen.sh --enable-debugfile --enable-sqlite --enable-shmem && make

RUN git config --global url.https://github.com/.insteadOf git://github.com/
RUN git config --global url.https://github.com/.insteadOf git://gitorious.org/
RUN git clone https://github.com/refracta/dcss-server /usr/src/dgamelaunch-config -b test-new-structure
RUN echo 'export PATH="$DGL_CONF_HOME/bin:$DGL_CONF_HOME/server/scripts:$PATH"' | tee -a ~/.bashrc

USER root
RUN cd dgamelaunch \
    && mkdir -p $DGL_CHROOT/bin \
    && make install && cp ee virus $DGL_CHROOT/bin \
    && touch $DGL_CHROOT/dgamelaunch

# this is taken from build-crawl-dirs to here because it's the only directory that's outside of volumes due to not storing state
RUN mkdir -p /cores
# TODO: could add apache setup here
# TODO: Remove?

# Next steps for creating versionsdb/crawl gamedir/publishing dgl files and building crawl is done after starting,
# because volumes need to be mounted to preserve state.
ENTRYPOINT ["/usr/src/dgamelaunch-config/server/scripts/static/entrypoint.sh"]
HEALTHCHECK CMD ["/usr/src/dgamelaunch-config/server/scripts/static/healthcheck.sh"]
