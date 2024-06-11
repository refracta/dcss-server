FROM ubuntu:22.04

# See README.md for what this does and why

# This Dockerfile will fail if the repository is not used as the build context.
# do an early COPY step to ensure that build is being invoked correctly.

COPY utils/testing-container/healthcheck.sh /

ENV DGL_CHROOT=/home/crawl/DGL
ARG DEBIAN_FRONTEND=noninteractive
ARG TERM=dumb

# basic prerequisites
RUN apt-get update
RUN apt-get install -y locales locales-all
ENV LANG=en_US.UTF-8
RUN sed -i -e "s/# $LANG.*/$LANG.UTF-8 UTF-8/" /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG=$LANG

# TODO: actually set up ccache, this just installs it
RUN apt-get install -y sudo git build-essential autoconf automake bison libncursesw5-dev flex liblua5.1-0-dev libsqlite3-dev libz-dev vim pkg-config python3 python3-pip python3-yaml ccache libpng-dev sqlite3 libpcre3 libpcre3-dev apache2 advancecomp pngcrush debootstrap openssh-server curl

RUN pip3 install tornado \
    && ln -s /usr/bin/python3 /usr/bin/python \
    && useradd -m crawl \
    && useradd -m crawl-dev \
    && usermod -G root -a crawl \
    && usermod -G root -a crawl-dev \
    && usermod -G www-data -a crawl \
    && usermod -G www-data -a crawl-dev \
    && usermod -G crawl -a root \
    && usermod -G crawl -a www-data \
    && usermod -G crawl-dev -a root \
    && usermod -G crawl-dev -a www-data


# allow crawl-dev to run various things with sudo without a password. These
# permissions may be too open for a production server.
COPY utils/testing-container/dgl_sudoers /etc/sudoers.d/

WORKDIR /home/crawl-dev

# set up dgamelaunch

# TODO: what are these directories in ~crawl-dev used for? `run` doesn't exist
# on CAO?
RUN git config --global url.https://github.com/.insteadOf git://github.com/
# The unauthenticated git protocol on port 9418 is no longer supported.
USER crawl-dev
RUN mkdir logs \
    && mkdir run \
    && mkdir dgamelaunch-config dgamelaunch-config/utils/ \
    && git clone https://github.com/crawl/dgamelaunch.git \
    && cd dgamelaunch && ./autogen.sh --enable-debugfile --enable-sqlite --enable-shmem && make

USER root
COPY utils/testing-container/crawler_sshdconfig /tmp
RUN cd dgamelaunch \
    && mkdir -p $DGL_CHROOT/bin \
    && make install && cp ee virus $DGL_CHROOT/bin \
    && useradd crawler --shell /usr/local/sbin/dgamelaunch \
    && echo crawler:crawler | chpasswd \
    && cat /tmp/crawler_sshdconfig >> /etc/ssh/sshd_config && rm /tmp/crawler_sshdconfig


# dgamelaunch-config initialization

# these COPYs are a bit messy. When setting up a system for non-testing
# purposes, normally you would want to instead do (as user crawl-dev):
#     git clone https://github.com/crawl/dgamelaunch-config.git
# note that after this point, changing any file in the copied material will
# invalidate the build cache (annoying!). For that reason, we manually select
# everything but utils to copy at this point.
COPY --chown=crawl-dev:crawl-dev ./bin /home/crawl-dev/dgamelaunch-config/bin/
COPY --chown=crawl-dev:crawl-dev ./chroot /home/crawl-dev/dgamelaunch-config/chroot/
COPY --chown=crawl-dev:crawl-dev ./crawl-build /home/crawl-dev/dgamelaunch-config/crawl-build/
COPY --chown=crawl-dev:crawl-dev ./help /home/crawl-dev/dgamelaunch-config/help/
COPY --chown=crawl-dev:crawl-dev ./lib /home/crawl-dev/dgamelaunch-config/lib/
COPY --chown=crawl-dev:crawl-dev ./games.d /home/crawl-dev/dgamelaunch-config/games.d/
COPY --chown=crawl-dev:crawl-dev ./config.py ./crawl-git.conf ./dgamelaunch.conf ./dgl-manage.conf sh-utils /home/crawl-dev/dgamelaunch-config/
COPY --chown=crawl-dev:crawl-dev ./utils/webtiles ./utils/trigger-rebuild.pl ./utils/auth-save-downloader.pl /home/crawl-dev/dgamelaunch-config/utils/

RUN ls dgamelaunch-config/bin -al && sed -i -e 's/"127.0.0.1"/"0.0.0.0"/' dgamelaunch-config/config.py \
    && dgamelaunch-config/bin/dgl create-versions-db \
    && dgamelaunch-config/bin/dgl create-crawl-gamedir \
    && dgamelaunch-config/bin/dgl publish --confirm

# set up trunk and one stable version
# TODO: a bit more flexibility here
RUN cp -a $DGL_CHROOT/crawl-master/crawl-git $DGL_CHROOT/crawl-master/crawl-0.25 \
    && dgamelaunch-config/bin/dgl update-trunk \
    && dgamelaunch-config/bin/dgl update-stable 0.25

# TODO: could add apache setup here

# at this point, the chroot still needs to be provisioned. You can trigger this
# by calling the entrypoint script with --provision-chroot in a privileged
# container, then committing the output.

# set up entry point -- this script starts webtiles and sshd, and sets up the
# bind mounts.
COPY utils/testing-container/docker-entrypoint.sh /

# finally copy in utils, which will be often invalidated while working on the
# docker setup itself.
COPY utils/* /home/crawl-dev/dgamelaunch-config/utils/

ENTRYPOINT ["/docker-entrypoint.sh"]
HEALTHCHECK CMD /healthcheck.sh
