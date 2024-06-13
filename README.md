# dcss-server

> This [README.md](README.md) is based on the automatically translated [README.ko.md](README.ko.md) via ChatGPT.

This script is designed to simplify the deployment and management of a Dungeon Crawl Stone Soup server, including various fork versions (DCSS CA, HellCrawl, GnollCrawl, BloatCrawl2, GoonCrawl, X-Crawl, StoatSoup, KimchiCrawl, BcadrenCrawl) and official release versions (0.11 ~ 0.31) in a modern Ubuntu environment.

### First Run Guide:
#### Prerequisites
* Docker (with Docker Compose)

#### One-Line Deploy
```bash
curl -fsSL https://refracta.github.io/dcss-server/server/scripts/deploy/stable.sh | sudo -E sh -
```
<details>
<summary>develop</summary>
 
```bash
curl -fsSL https://refracta.github.io/dcss-server/server/scripts/deploy/develop.sh | sudo -E sh -
```

</details>

#### Fast Deploy
```bash
git clone https://github.com/refracta/dcss-server -b stable
cd dcss-server/server

# Update to the latest settings (use if you wish to update)
docker compose run --rm -e CMD='cd $DGL_CONF_HOME && git pull' dcss-server
# Download pre-built game binaries and settings
docker compose run --rm -e CMD='$SCRIPTS/utils/release.sh download -o -p /data -n stable-game-data' dcss-server
# Run with random ports
docker compose up -d && docker compose logs -f
# Run on specified ports
docker compose -f docker-compose.yml -f docker-compose.ports.yml up -d && docker compose logs -f
```
<details>
<summary>develop</summary>
 
```bash
git clone https://github.com/refracta/dcss-server -b develop
cd dcss-server/server

docker compose run --rm -e CMD='cd $DGL_CONF_HOME && git pull' dcss-server
docker compose run --rm -e CMD='$SCRIPTS/utils/release.sh download -o -p /data -n game-data' dcss-server
docker compose up -d && docker compose logs -f
docker compose -f docker-compose.yml -f docker-compose.ports.yml up -d && docker compose logs -f
```

</details>

#### Deploy with Build
```bash
git clone https://github.com/refracta/dcss-server -b stable
cd dcss-server/server

# If you need to build without downloading images from Docker Hub, you can use the following command.
docker compose build

# This command is optional; you can download ccache files to speed up compilation.
# Without it, the full build takes over 6 hours on the GitHub Action Runner's ubuntu-24.04 image, and about 45 minutes with it.
docker compose run --rm -e CMD='$SCRIPTS/utils/release.sh download -p /data/ccache -n stable-ccache' dcss-server

# USE_DWEM: Apply https://github.com/refracta/dcss-webtiles-extension-module.
# USE_REVERSE_PROXY: Apply a patch to log the X-Forwarded-For IP.
# CMD: Can be used to run scripts inside the container.
# "$SCRIPTS/game/install-crawl-versions.sh"=Build all Crawl versions, "$SCRIPTS/game/install-trunk.sh"=Build only the trunk version, ""=Run the server without building (if pre-built data exists).
docker compose run --rm -e CMD='$SCRIPTS/game/install-crawl-versions.sh' dcss-server
USE_DWEM=true USE_REVERSE_PROXY=true docker compose up -d && docker compose logs -f
```

<details>
<summary>develop</summary>
 
```bash
git clone https://github.com/refracta/dcss-server -b develop
cd dcss-server/server

docker compose build
docker compose run --rm -e CMD='$SCRIPTS/utils/release.sh download -p /data/ccache -n ccache' dcss-server
docker compose run --rm -e CMD='$SCRIPTS/game/install-crawl-versions.sh' dcss-server
USE_DWEM=true USE_REVERSE_PROXY=true docker compose up -d && docker compose logs -f
```

</details>

#### Notes
 - All server data is stored in `server/data/{config,versionsdb,crawl-master,dgldir,games}`.
 - `config` is created by cloning the contents of this repository at the time of image build. If you set this folder with the contents of this repository (or a forked and modified repository) in advance, the container will use those contents for configuration. You can modify the scripts in [server/scripts](server/scripts) to change the server settings.
 - `versiondb` stores the database file containing the version information of the built games.
 - `crawl-master` stores game settings, Milestones, Morgue, etc.
 - `dgldir` stores data used by `dgamelaunch`.
 - `games` stores the built game binaries.
 - You can access Crawl Webtiles on port `8080`, game logs on ports `8081 (Apache)` and `8082 (Nginx)`, and SSH on port 12222. (You can connect using `nemelex:xobeh` or the [CAO key](https://crawl.develz.org/cao_key))
 - You can use [trigger-rebuild.pl](utils/trigger-rebuild.pl) and [auth-save-downloader.pl](utils/auth-save-downloader.pl). (Refer to: [apache.conf](server/scripts/web/conf/apache.conf), [nginx.conf](server/scripts/web/conf/nginx.conf))
 - Trunk and some fork builds are executed every 15 minutes. (Refer to: [setup-cron.sh](server/scripts/game/setup-cron.sh))
 - You can fork this repository to manage personalized build configurations as releases. (Refer to: [release.sh](server/scripts/utils/release.sh), [upload-data.yml](.github/workflows/upload-data.yml))

### Repository Management
* This repository is used for the operation of [crawl.nemelex.cards](https://crawl.nemelex.cards).
* If you need to add a new fork or version, you can request it via a Pull-Request.

### Upstream Projects
* https://github.com/crawl/dgamelaunch-config
* Scripts necessary for operating a Dungeon Crawl Stone Soup server. `utils/testing-container` contains the container environment configuration created for Crawl's CI/CD verification work.

* https://github.com/Rytisgit/dgamelaunch-dcss-forks-server
* This project is based on dgamelaunch-config and is designed to easily configure multiple forks in a containerized environment. *This project was started based on this project.*

### Thanks to


Thanks to the help of many developers in the `#crawl-dev` IRC channel, the implementation goals of this project were successfully achieved. I would especially like to thank [gammafunk](https://github.com/gammafunk) and [Sentei](https://github.com/Rytisgit), the developer of [DCSSReplay](https://github.com/Rytisgit/dcssreplay) and maintainer of [dgamelaunch-dcss-forks-server](https://github.com/Rytisgit/dgamelaunch-dcss-forks-server), for their invaluable advice and assistance in resolving issues, particularly with server setup.