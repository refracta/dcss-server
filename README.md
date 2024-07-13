
# dcss-server

> [README.md](README.md) was created based on [README.ko.md](README.ko.md), which was automatically translated via ChatGPT.

This script is designed to simplify the deployment and management of a Dungeon Crawl Stone Soup server. It includes as many fork versions as possible (DCSS CA, HellCrawl, GnollCrawl, B-Crawl, BloatCrawl2, GoonCrawl, X-Crawl, StoatSoup, BcadrenCrawl, KimchiCrawl, AddedCrawl) and official release versions (0.11 ~ 0.31) in a latest Ubuntu image environment.

### First Run Guide:
#### Prerequisites
* Docker (with Docker Compose)

#### One-Line Deploy
```bash
curl -fsSL https://raw.githubusercontent.com/refracta/dcss-server/stable/server/scripts/deploy/stable.sh | sudo -E sh -
```
<details>
<summary>develop</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/refracta/dcss-server/develop/server/scripts/deploy/develop.sh | sudo -E sh -
```

</details>

#### Fast Deploy
```bash
git clone https://github.com/refracta/dcss-server -b stable
cd dcss-server/server
docker compose -f docker-compose.yml -f docker-compose.stable.yml config > docker-compose.combine.yml && \
mv docker-compose.combine.yml docker-compose.yml

# Update with the latest settings (use if you want to update)
docker compose run --rm -e CMD='cd $DGL_CONF_HOME && git pull' dcss-server
# Download pre-built game binaries and settings
docker compose run --rm -e CMD='$SCRIPTS/utils/release.sh download -o -p /data -n stable-game-data' dcss-server
# Run with random ports
docker compose up -d && docker compose logs -f
# Run with specified ports
docker compose -f docker-compose.yml -f docker-compose.ports.yml up -d && docker compose logs -f
```
<details>
<summary>develop</summary>

```bash
git clone https://github.com/refracta/dcss-server -b develop
cd dcss-server/server

docker compose run --rm -e CMD='cd $DGL_CONF_HOME && git pull' dcss-server
docker compose run --rm -e CMD='$SCRIPTS/utils/release.sh download -o -p /data -n game-data' dcss-server
# Run with random ports
docker compose up -d && docker compose logs -f
# Run with specified ports
docker compose -f docker-compose.yml -f docker-compose.ports.yml up -d && docker compose logs -f
```

</details>

#### Deploy with Build
```bash
git clone https://github.com/refracta/dcss-server -b stable
cd dcss-server/server
docker compose -f docker-compose.yml -f docker-compose.ports.yml -f docker-compose.stable.yml config > docker-compose.combine.yml && \
mv docker-compose.combine.yml docker-compose.yml

# If you need to build without downloading the image stored in Docker Hub, you can use the following command.
docker compose build

# This command can be used optionally to download ccache files to speed up compilation.
# Without it, the full build takes over 6 hours on the ubuntu-24.04 image of the GitHub Action Runner, but with it, it accelerates to about 45 minutes.
docker compose run --rm -e CMD='$SCRIPTS/utils/release.sh download -p /data/ccache -n stable-ccache' dcss-server

# USE_DWEM: apply the https://github.com/refracta/dcss-webtiles-extension-module.
# USE_REVERSE_PROXY: Apply patches to record X-Forwarded-For IPs in logs.
# CMD: Can be used to run scripts inside the container.
# "$SCRIPTS/game/install-crawl-versions.sh"=build all crawl versions, "$SCRIPTS/game/install-trunk.sh"=build only the trunk version, ""=run the server without building. (If pre-built data exists)
docker compose run --rm -e CMD='$SCRIPTS/game/install-crawl-versions.sh' dcss-server
USE_DWEM=true USE_REVERSE_PROXY=true docker compose up -d && docker compose logs -f
```

<details>
<summary>develop</summary>

```bash
git clone https://github.com/refracta/dcss-server -b develop
cd dcss-server/server
docker compose -f docker-compose.yml -f docker-compose.ports.yml config > docker-compose.combine.yml && \
mv docker-compose.combine.yml docker-compose.yml

docker compose build
docker compose run --rm -e CMD='$SCRIPTS/utils/release.sh download -p /data/ccache -n ccache' dcss-server
docker compose run --rm -e CMD='$SCRIPTS/game/install-crawl-versions.sh' dcss-server
USE_DWEM=true USE_REVERSE_PROXY=true docker compose up -d && docker compose logs -f
```

</details>

#### Notes
- All server data is stored in `server/data/{config,versionsdb,crawl-master,dgldir,games}`.
- `config` is created by cloning the contents of this repository at the time of image build. If this folder is pre-configured with the contents of this repository (or a forked and modified repository), the container will use it for the configuration. You can modify the scripts in [server/scripts](server/scripts) to change the server configuration.
- `versionsdb` stores the database file containing version information of the built games.
- `crawl-master` stores game settings, Milestone, Morgue, etc.
- `dgldir` stores data used by `dgamelaunch`.
- `games` stores the built game binaries.
- Access Crawl WebTiles on port `8080`, game logs on `8081 (Apache)` and `8082 (Nginx)`. SSH access is available on port `12222`. (You can access using `nemelex:xobeh` or [CAO key](https://crawl.develz.org/cao_key), refer to [setup-user.sh](server/scripts/dgl/setup-user.sh)), You can also connect to a web terminal on port 8022.
- You can use [trigger-rebuild.pl](utils/trigger-rebuild.pl) and [auth-save-downloader.pl](utils/auth-save-downloader.pl). (Refer to: [apache.conf](server/scripts/web/conf/apache.conf), [nginx.conf](server/scripts/web/conf/nginx.conf))
- Build the trunk and some forks every 15 minutes. (Refer to: [setup-cron.sh](server/scripts/game/setup-cron.sh))
- You can fork this repository to manage personalized build configurations as releases. (Refer to: [release.sh](server/scripts/utils/release.sh), [upload-data.yml](.github/workflows/upload-data.yml))

### Repository Management
* This repository is used for the operation of [crawl.nemelex.cards](https://crawl.nemelex.cards).
* If you need to add new forks or versions, you can request it via a Pull-Request.

### Upstream Projects
* https://github.com/crawl/dgamelaunch-config
* Scripts necessary for running the Dungeon Crawl Stone Soup server. In `utils/testing-container`, there is a container environment configuration for CI/CD verification tasks of Crawl.

* https://github.com/Rytisgit/dgamelaunch-dcss-forks-server
* This project is based on dgamelaunch-config, designed to easily configure multiple forks in a containerized environment. *This project was started based on this project.*

### Thanks to

With the help of many developers in the `#crawl-dev` IRC channel, the implementation goals of this project were successfully achieved.
Special thanks to [gammafunk](https://github.com/gammafunk) for their assistance with server settings, and [Sentei](https://github.com/Rytisgit), the developer of [DCSSReplay](https://github.com/Rytisgit/dcssreplay) and maintainer of [dgamelaunch-dcss-forks-server](https://github.com/Rytisgit/dgamelaunch-dcss-forks-server), for monitoring the server setup process and providing invaluable advice and issue resolution.
