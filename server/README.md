# Docker testing container

This directory contains infrastructure for building a dgamelaunch-config
docker container. This container is not by default intended for anything like
production, but rather is aimed for testing of dgamelaunch-config setups, both
automated and manual. The setup is a full-blown chroot one based on
instructions here: https://crawl.develz.org/wiki/doku.php?id=dcss:server:setting_up_dgamelaunch_and_webtiles

I can't promise that the container setup is particularly elegant or efficient
(the resulting image is about 4GB), but it works and is very similar to the
setup on most public crawl servers.

The build process has two steps:
* first build an image using the Dockerfile
* then setup the chroot. This is hard to do with `docker build` because it
  requires a container running in --privileged mode, which though technically
  possible during a build, is not easy to get going.

These two steps are packaged in a single script in
`utils/build-testing-container.sh`. By default the container name that this
generates is `dgl-test`, and if you stick with that, the resulting container
should be directly executable, for example interactively via:

    docker run -it -p 127.0.0.1:8080:8080 -p 127.0.0.1:2222:22 --privileged dgl-test /bin/bash

To run it as a service, you can use:

    docker run -d -p 127.0.0.1:8080:8080 -p 127.0.0.1:2222:22 --privileged dgl-test --background

Once the container is up for 30seconds, if everything went well, `docker ps`
should show `(healthy)` in the status column for the relevant container. This
indicates that webtiles is up and running, and that sshd is as well.

Extra notes:
* the ssh username/password is crawler/crawler, running on port 2222.
* the webtiles server is running versions 0.25 and current trunk, running
* on port 8080.
* If you play around with this, don't forget to rune `docker container prune`
  and `docker image prune` every once in a while.
* I suspect that if you were really containerizing crawl, there wouldn't be
  much point in running dgamelaunch in a chroot. Just go with a non-chroot
  setup.
* If you were really containerizing crawl you would want to handle storage a
  bit differently.

Here are some community attempts to containerize crawl for purposes of actually
running a server; these are all dormant projects as far as I know but may be
useful references:
* https://bitbucket.org/TZer0/crawl-docker
* https://bitbucket.org/mattiasjp/crawl-docker
* https://github.com/mattias/ansible_playbook_webtiles
