#!/bin/sh

docker compose down && docker rmi refracta/dcss-server || true && \
curl -o docker-compose.yml https://refracta.github.io/dcss-server/server/docker-compose.yml && \
curl -o docker-compose.override.yml https://refracta.github.io/dcss-server/server/docker-compose.ports.yml && \
docker compose run --rm -T -e CMD='$SCRIPTS/utils/release.sh download -o -p /data -n game-data' dcss-server && \
docker compose up -d && docker compose logs -f
