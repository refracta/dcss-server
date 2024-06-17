# dcss-server

> [README.md](README.md)는 ChatGPT를 통해 자동으로 번역된 [README.ko.md](README.ko.md)를 기반으로 작성되었습니다.

이 스크립트는 던전 크롤 스톤 수프의 서버를 한번에 간단히 배포 및 관리할 수 있게 하기 위해 제작되었습니다. 최신 우분투 이미지 환경에서 가능한 많은 포크 버전(DCSS CA, HellCrawl, GnollCrawl, BloatCrawl2, GoonCrawl, X-Crawl, StoatSoup, BcadrenCrawl, KimchiCrawl, AddedCrawl)과 정식 릴리즈 버전(0.11 ~ 0.31)을 포함합니다.

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
docker compose -f docker-compose.yml -f docker-compose.ports.yml -f docker-compose.stable.yml config > docker-compose.combine.yml \ && 
mv docker-compose.combine.yml docker-compose.yml

# 최신 설정으로 업데이트 (업데이트를 희망하는 경우 사용)
docker compose run --rm -e CMD='cd $DGL_CONF_HOME && git pull' dcss-server
# 사전 빌드된 게임 바이너리와 설정 다운로드
docker compose run --rm -e CMD='$SCRIPTS/utils/release.sh download -o -p /data -n stable-game-data' dcss-server
# 랜덤 포트와 함께 실행
docker compose up -d && docker compose logs -f
# 지정된 포트에서 실행
docker compose -f docker-compose.yml -f docker-compose.ports.yml up -d && docker compose logs -f
```
<details>
<summary>develop</summary>
 
```bash
git clone https://github.com/refracta/dcss-server -b develop
cd dcss-server/server
docker compose -f docker-compose.yml -f docker-compose.ports.yml -f docker-compose.stable.yml config > docker-compose.combine.yml \ && 
mv docker-compose.combine.yml docker-compose.yml

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
docker compose -f docker-compose.yml -f docker-compose.ports.yml -f docker-compose.stable.yml config > docker-compose.combine.yml \ && 
mv docker-compose.combine.yml docker-compose.yml

# Docker Hub에 저장된 이미지를 다운로드하지 않고 빌드가 필요한 경우 다음 명령어를 사용할 수 있습니다.
docker compose build

# 이 명령은 선택적으로 사용할 수 있습니다, ccache 파일을 다운로드하여 컴파일 속도를 가속할 수 있습니다. 
# 미적용시 GitHub Action Runner의 ubuntu-24.04 이미지 기준, 전체 빌드에 6시간 이상이 소요되며, 적용시 45분 정도로 가속됩니다.
docker compose run --rm -e CMD='$SCRIPTS/utils/release.sh download -p /data/ccache -n stable-ccache' dcss-server

# USE_DWEM: https://github.com/refracta/dcss-webtiles-extension-module 사용을 적용합니다.
# USE_REVERSE_PROXY: X-Forwarded-For 아이피를 로그에 기록하기 위한 패치를 적용합니다.
# CMD: 컨테이너 내부의 스크립트를 실행시키는데 사용할 수 있습니다.
# "$SCRIPTS/game/install-crawl-versions.sh"=전체 크롤 버전을 빌드합니다, "$SCRIPTS/game/install-trunk.sh"= 트렁크 버전만 빌드합니다, ""=빌드 없이 바로 서버를 실행합니다. (기존에 빌드된 데이터가 존재 시)
docker compose run --rm -e CMD='$SCRIPTS/game/install-crawl-versions.sh' dcss-server
USE_DWEM=true USE_REVERSE_PROXY=true docker compose up -d && docker compose logs -f
```

<details>
<summary>develop</summary>
 
```bash
git clone https://github.com/refracta/dcss-server -b develop
cd dcss-server/server
docker compose -f docker-compose.yml -f docker-compose.ports.yml config > docker-compose.combine.yml \ && 
mv docker-compose.combine.yml docker-compose.yml

docker compose build
docker compose run --rm -e CMD='$SCRIPTS/utils/release.sh download -p /data/ccache -n ccache' dcss-server
docker compose run --rm -e CMD='$SCRIPTS/game/install-crawl-versions.sh' dcss-server
USE_DWEM=true USE_REVERSE_PROXY=true docker compose up -d && docker compose logs -f
```

</details>

#### Notes
 - 모든 서버 데이터는 `server/data/{config,versionsdb,crawl-master,dgldir,games}`에 저장됩니다.
 - `config`에는 이미지 빌드 시점의 본 리포지토리의 내용이 `clone`되어 생성됩니다. 사전에 이 폴더를 이 저장소(또는 포크하여 수정한 리포지토리)의 내용으로 설정한 경우, 컨테이너는 해당 내용을 설정에 사용합니다. [server/scripts](server/scripts)에 있는 스크립트 들을 수정해서, 서버 설정을 바꿀 수 있습니다.
 - `versiondb`에는 빌드된 게임의 버전 정보가 담긴 데이터베이스 파일이 저장됩니다.
 - `crawl-master`에는 게임 설정과 Milestone, Morgue 등이 저장됩니다.
 - `dgldir`에는 `dgamelaunch`가 사용하는 데이터가 저장됩니다.
 - `games`에는 빌드된 게임 바이너리가 저장됩니다.
 - `8080`으로 크롤 웹타일, `8081 (Apache)`과 `8082 (Nginx)`번 포트로 게임 로그에 접근할 수 있습니다. `12222`번 포트로 SSH 접속이 가능합니다. (`nemelex:xobeh` 또는 [CAO 키](https://crawl.develz.org/cao_key)를 이용한 접속이 가능합니다, 참고 [setup-user.sh](server/scripts/dgl/setup-user.sh))
 - [trigger-rebuild.pl](utils/trigger-rebuild.pl), [auth-save-downloader.pl](utils/auth-save-downloader.pl)의 사용이 가능합니다. (참고: [apache.conf](server/scripts/web/conf/apache.conf), [nginx.conf](server/scripts/web/conf/nginx.conf))
 - 15분마다 trunk와 일부 fork의 빌드를 실행합니다. (참고: [setup-cron.sh](server/scripts/game/setup-cron.sh))
 - 이 리포지토리를 포크하여 개인화된 빌드 구성을 릴리즈로 관리할 수 있습니다. (참고: [release.sh](server/scripts/utils/release.sh), [upload-data.yml](.github/workflows/upload-data.yml))

### Repository Management
* 이 리포지토리는 [crawl.nemelex.cards](https://crawl.nemelex.cards) 운영을 위해서 사용됩니다.
* 새로운 포크 또는 버전 추가가 필요하다면, Pull-Request를 통해서 요청할 수 있습니다.

### Upstream Projects
* https://github.com/crawl/dgamelaunch-config
* 던전 크롤 스톤 수프 서버 운영에 필요한 스크립트입니다. `utils/testing-container`에는 크롤의 CI/CD 검증 작업을 위해 제작된 컨테이너 환경 구성이 있습니다.

* https://github.com/Rytisgit/dgamelaunch-dcss-forks-server
* 이 프로젝트는 dgamelaunch-config을 기반으로 하여, 여러 포크를 컨테이너로 구성된 환경에서 한번에 쉽게 구성할 수 있도록 만들어졌습니다. *본 프로젝트는 이 프로젝트를 기반으로 시작되었습니다.*

### Thanks to

`#crawl-dev` IRC 채널의 많은 개발자 분의 도움으로, 본 프로젝트의 구현 목표가 성공적으로 달성될 수 있었습니다. 
특히 서버 세팅과 관련해서 많은 도움을 주신 [gammafunk](https://github.com/gammafunk), [DCSSReplay](https://github.com/Rytisgit/dcssreplay)의 개발자이자 [dgamelaunch-dcss-forks-server](https://github.com/Rytisgit/dgamelaunch-dcss-forks-server)의 메인테이너로서
서버 설정 진행 과정을 모니터링하며 아낌없는 조언과 이슈 해결을 도와준 [Sentei](https://github.com/Rytisgit)에게 감사를 전하고 싶습니다.
