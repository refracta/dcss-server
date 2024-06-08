# dcss-server

This document was translated using ChatGPT from README.ko.md.

This script is designed to easily deploy and manage a Dungeon Crawl Stone Soup server, including as many fork versions (DCSS CA, HellCrawl, GnollCrawl, BloatCrawl2, GoonCrawl, X-Crawl, StoatSoup, KimchiCrawl, BcadrenCrawl) and official release versions (0.11 ~ 0.31) as possible on the latest Linux environment.

### First Run Guide:

#### Prerequisites

* Docker (with Docker Compose)

#### Fast deploy

```bash
git clone https://github.com/refracta/dcss-server
cd dcss-server/server

# Download pre-built game binaries and configurations
./release.sh download -p data -n game-data
# Run with random ports
docker compose up -d && docker compose logs -f
# Run on specified ports
docker compose up -f docker-compose.yml -f docker-compose.ports.yml -d && docker compose logs -f
```

#### Deploy with Build
```bash
git clone https://github.com/refracta/dcss-server
cd dcss-server/server

# This command is optional; you can download ccache files to speed up the compile process.
# Without it, the full build takes over 6 hours based on the GitHub Action Runner's ubuntu-24.04 image, while with it, it accelerates to about 45 minutes.
./release.sh ccache -p data/ccache -n ccache

# USE_DWEM: Applies https://github.com/refracta/dcss-webtiles-extension-module.
# USE_REVERSE_PROXY: Applies a patch to log X-Forwarded-For IPs.
# COMMAND: "build-all"=build all versions, "build-trunk"=build trunk version only.
USE_DWEM=true USE_REVERSE_PROXY=true COMMAND=build-all docker compose up -d && docker compose logs -f

# If you need to build without downloading images stored on Docker Hub, you can use the following command.
COMMAND=build-all docker compose up -f docker-compose.yml -f docker-compose.build.yml -d && docker compose logs -f
```

#### Server Data
All server data is stored in `server/{versionsdb,crawl-master,dgldir,games}`.

### Repository Management 
This repository is used for operating crawl.nemelex.cards.
If you need to add a new fork or version, you can request it through a Pull-Request.

### Upstream projects
* https://github.com/crawl/dgamelaunch-config
* Scripts necessary for operating a Dungeon Crawl Stone Soup server. In utils/testing-container, there is a container environment configuration created for the CI/CD verification work of Crawl.

* https://github.com/Rytisgit/dgamelaunch-dcss-forks-server
* This project is based on dgamelaunch-config, designed to easily configure multiple forks in a containerized environment at once. This project was started based on that project.

### Thanks to
Thanks to the help of many developers on the DCSS IRC `#crawl-dev` channel, the implementation goals of this project could be successfully achieved.
I would especially like to thank gammafunk, who provided significant assistance with server setup and numerous questions, and Rytisgit, the developer of [DCSSReplay](https://github.com/rytisgit/dcssreplay) and the maintainer of dgamelaunch-dcss-forks-server, who monitored the server setup process and provided generous advice and issue resolution.
