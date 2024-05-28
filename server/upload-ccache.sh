#!/bin/bash

title=${1:-build-ccache}

tar -czf data/ccache.tar.gz -C data ccache

split -b 1GiB data/ccache.tar.gz data/ccache_part_

tag=$(date -u +v%y%m%d%H%M)

gh release create $tag -R refracta/dcss-webtiles-server --title "$title" --target ccache -n ""

gh release upload $tag data/ccache_part_* -R refracta/dcss-webtiles-server

echo "Compression and upload completed!"
