#!/bin/sh

curl -o docker-compose.yml https://raw.githubusercontent.com/refracta/dcss-server/stable/server/docker-compose.yml && \
curl -o docker-compose.ports.yml https://raw.githubusercontent.com/refracta/dcss-server/develop/server/docker-compose.ports.yml && \
curl -o docker-compose.stable.yml https://raw.githubusercontent.com/refracta/dcss-server/develop/server/docker-compose.stable.yml && \
docker compose -f docker-compose.yml -f docker-compose.ports.yml -f docker-compose.stable.yml config > docker-compose.combine.yml && \
mv docker-compose.combine.yml docker-compose.yml && \
rm docker-compose.ports.yml docker-compose.stable.yml && \
docker compose down && docker rmi refracta/dcss-server:stable || true && \
docker compose run --rm -T -e CMD='$SCRIPTS/utils/release.sh download -o -p /data -n stable-game-data' dcss-server && \
docker compose up -d && docker compose logs -f
