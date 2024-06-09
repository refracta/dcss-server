# dcss-server

This script is designed to simplify the deployment and management of a Dungeon Crawl Stone Soup server. It includes as many fork versions (DCSS CA, HellCrawl, GnollCrawl, BloatCrawl2, GoonCrawl, X-Crawl, StoatSoup, KimchiCrawl, BcadrenCrawl) and official release versions (0.11 ~ 0.31) as possible in the latest Linux environment.

### First Run Guide:

#### Prerequisites

* Docker (with Docker Compose)

#### Fast Deploy
Note: To use the download feature of the release.sh script, `jq` and `curl` must be installed in the environment. (You can install them in a Debian environment using `apt install jq curl -y`.)
```bash
git clone https://github.com/refracta/dcss-server
cd dcss-server/server

# Download pre-built game binaries and configurations
./release.sh download -p data -n game-data
# Run with random ports
docker compose up -d && docker compose logs -f
# Run with specified ports
docker compose -f docker-compose.yml -f docker-compose.ports.yml up -d && docker compose logs -f
```

#### Deploy with Build
```bash
git clone https://github.com/refracta/dcss-server
cd dcss-server/server

# This command is optional; you can download ccache files to speed up the compilation.
# Without it, the full build takes over 6 hours based on the GitHub Action Runner's ubuntu-24.04 image, but with it, it speeds up to about 45 minutes.
./release.sh download -p data/ccache -n ccache

# USE_DWEM: Apply https://github.com/refracta/dcss-webtiles-extension-module.
# USE_REVERSE_PROXY: Apply a patch to log the X-Forwarded-For IP.
# COMMAND: "build-all"=build all versions, "build-trunk"=build only the trunk version.
USE_DWEM=true USE_REVERSE_PROXY=true COMMAND=build-all docker compose up -d && docker compose logs -f

# If you need to build without downloading images from Docker Hub, you can use the following command.
COMMAND=build-all docker compose -f docker-compose.yml -f docker-compose.build.yml up -d && docker compose logs -f
```

#### Server Data
All server data is stored in `server/{versionsdb,crawl-master,dgldir,games}`.

### Repository Management
* This repository is used for operating crawl.nemelex.cards.
* If you need to add a new fork or version, you can request it via a Pull-Request.

### Upstream Projects
* https://github.com/crawl/dgamelaunch-config
* These are scripts necessary for operating a Dungeon Crawl Stone Soup server. `utils/testing-container` contains the container environment configuration created for Crawl's CI/CD verification tasks.

* https://github.com/Rytisgit/dgamelaunch-dcss-forks-server
* This project is based on dgamelaunch-config and is designed to easily configure multiple forks in a containerized environment. This project started based on that project.

### Thanks to

Thanks to the many developers in the DCSS IRC `#crawl-dev` channel, the implementation goals of this project were successfully achieved. 
Special thanks to gammafunk for his extensive help with server setup, and to Rytisgit, the developer of [DCSSReplay](https://github.com/rytisgit/dcssreplay) and maintainer of dgamelaunch-dcss-forks-server, for monitoring the server setup process and providing invaluable advice and issue resolution.