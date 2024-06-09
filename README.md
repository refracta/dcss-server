# dcss-server

This script is designed to simplify the deployment and management of a Dungeon Crawl Stone Soup server. It includes as many fork versions (DCSS CA, HellCrawl, GnollCrawl, BloatCrawl2, GoonCrawl, X-Crawl, StoatSoup, KimchiCrawl, BcadrenCrawl) and official release versions (0.11 ~ 0.31) as possible on the latest Linux environment.

### First Run Guide:

#### Prerequisites

* Docker (with Docker Compose)

#### Fast Deploy

```bash
git clone https://github.com/refracta/dcss-server
cd dcss-server/server

# Download pre-built game binaries and settings
./release.sh download -p data -n game-data
# Run with random ports
docker compose up -d && docker compose logs -f
# Run with specified ports
docker compose up -f docker-compose.yml -f docker-compose.ports.yml -d && docker compose logs -f
```

#### Deploy with Build

```bash
git clone https://github.com/refracta/dcss-server
cd dcss-server/server

# This command is optional. You can download ccache files to speed up the compilation process.
# Without it, the full build takes over 6 hours based on the GitHub Action Runner's ubuntu-24.04 image, but with it, it speeds up to about 45 minutes.
./release.sh ccache -p data/ccache -n ccache

# USE_DWEM: Applies https://github.com/refracta/dcss-webtiles-extension-module.
# USE_REVERSE_PROXY: Applies a patch to log the X-Forwarded-For IP.
# COMMAND: "build-all"=builds all versions, "build-trunk"=builds only the trunk version.
USE_DWEM=true USE_REVERSE_PROXY=true COMMAND=build-all docker compose up -d && docker compose logs -f

# If you need to build without downloading images from Docker Hub, you can use the following command.
COMMAND=build-all docker compose up -f docker-compose.yml -f docker-compose.build.yml -d && docker compose logs -f
```

#### Server Data
All server data is stored in `server/{versionsdb,crawl-master,dgldir,games}`.

### Repository Management
* This repository is used for operating crawl.nemelex.cards.
* If you need to add a new fork or version, you can request it via a Pull-Request.

### Upstream Projects
* https://github.com/crawl/dgamelaunch-config
* This script is necessary for operating a Dungeon Crawl Stone Soup server. The `utils/testing-container` includes a container environment configuration created for CI/CD verification tasks of Crawl.

* https://github.com/Rytisgit/dgamelaunch-dcss-forks-server
* This project is based on dgamelaunch-config and is designed to easily configure multiple forks in a containerized environment. This project started based on that project.

### Thanks to

Thanks to the many developers in the DCSS IRC `#crawl-dev` channel, the implementation goals of this project were successfully achieved. 
Special thanks to gammafunk for extensive help with server setup, and to rytisgit, the developer of [DCSSReplay](https://github.com/rytisgit/dcssreplay) and maintainer of dgamelaunch-dcss-forks-server, for monitoring the server setup process and providing invaluable advice and issue resolution.