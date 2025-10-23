#! /bin/bash

# shellcheck source=crawl-git.conf
source "$DGL_CONF_HOME/crawl-git.conf"

if [[ -f "$VERSIONS_DB" ]]; then
    echo -e "Crawl version db $VERSIONS_DB already exists, aborting."
    exit 1
fi

set -e
if [[ -f "$VERSIONS_DB" ]]; then
    abort-saying "Versions DB file $VERSIONS_DB already exists"
fi

echo "Creating $VERSIONS_DB"
if [[ "$UID" != "0" ]]; then
    echo -e "This script must be run as root"
    exit 1
fi

VERSIONS_DB_DIR="$(dirname "$VERSIONS_DB")"
if [[ ! -d "$VERSIONS_DB_DIR" ]]; then
    say "Version DB directory $VERSIONS_DB_DIR doesn't exist, creating it."
    mkdir -p "$VERSIONS_DB_DIR"
fi

sqlite3 "$VERSIONS_DB" < "$CRAWL_BUILD_DIR/version-db-schema.sql"
