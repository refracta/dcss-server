#!/bin/bash

mkdir -p data

latest_release=$(curl -s https://api.github.com/repos/refracta/dcss-webtiles-server/releases/latest)

release_tag=$(echo $latest_release | jq -r '.tag_name')
release_title=$(echo $latest_release | jq -r '.name')

echo "Latest release: $release_title ($release_tag)"

assets=$(echo $latest_release | jq -r '.assets[] | select(.name | test("^ccache_part_")) | .browser_download_url')

for url in $assets; do
    echo "Downloading $url"
    curl -L -o data/$(basename $url) $url
done

cat data/ccache_part_* > data/ccache.tar.gz

mkdir -p data/ccache
tar -xzf data/ccache.tar.gz -C data

rm data/ccache_part_*
rm data/ccache.tar.gz

echo "Download and extraction completed!"
