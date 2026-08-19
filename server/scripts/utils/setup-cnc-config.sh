#!/bin/bash

source "$DGL_CONF_HOME/dgl-manage.conf"
sed -i 's|CONFIG_MORGUE_URL|https://archive.nemelex.cards/morgue/%n/|g' "$DGL_CONF_HOME/config.py"
sed -i 's|CONFIG_SERVER_ID|crawl.nemelex.cards|g' "$DGL_CONF_HOME/config.py"
sed -i 's|CONFIG_DGL_SERVER|crawl.nemelex.cards|g' "$DGL_CONF_HOME/dgl-manage.conf"
sed -i 's|CONFIG_WEB_SAVEDUMP_URL|https://archive.nemelex.cards/saves|g' "$DGL_CONF_HOME/dgl-manage.conf"
cp -r $DGL_CONF_HOME/server/etc/webserver/* $WEBDIR

# Housing is kept as a small overlay on upstream WebTiles.  Applying every
# patch strictly makes upstream drift fail the update instead of silently
# deploying only part of the isolation boundary.  A reverse dry-run is the
# idempotent "already applied" case used by repeated update runs.
if ! command -v patch >/dev/null 2>&1; then
    echo "patch is required to install WebTiles overlays" >&2
    exit 1
fi

apply_webtiles_patch() {
    local patch_file="$1"
    if patch --batch --fuzz=0 -d "$WEBDIR" --dry-run --forward -p0 < "$patch_file" >/dev/null 2>&1; then
        patch --batch --fuzz=0 -d "$WEBDIR" --forward -p0 < "$patch_file" || exit 1
    elif patch --force --fuzz=0 -d "$WEBDIR" --dry-run --reverse -p0 < "$patch_file" >/dev/null 2>&1; then
        echo "WebTiles patch already applied: $(basename "$patch_file")"
    else
        echo "WebTiles patch does not apply cleanly: $patch_file" >&2
        exit 1
    fi
}

housing_patch="$DGL_CONF_HOME/server/etc/webserver-patches/housing-session.patch"
housing_patch_migrations="$DGL_CONF_HOME/server/etc/webserver-patch-migrations"
# Site-local WebTiles patches can touch the same import and lifecycle blocks.
# The installer strictly peels any recognized current/legacy Housing overlay,
# applies or recognizes every site patch, then puts the current Housing
# isolation boundary back on top.  This is idempotent even when a later overlay
# has changed an earlier patch's reverse context.
site_webtiles_patches=()
for patch_file in "$DGL_CONF_HOME"/server/etc/webserver-patches/*.patch; do
    [ -f "$patch_file" ] || continue
    [ "$patch_file" = "$housing_patch" ] && continue
    site_webtiles_patches+=("$patch_file")
done
if [ -f "$housing_patch" ]; then
    if ! bash "$(dirname "${BASH_SOURCE[0]}")/upgrade_webtiles_patch.sh" \
        "$WEBDIR" "$housing_patch" "$housing_patch_migrations" \
        "${site_webtiles_patches[@]}"; then
        exit 1
    fi
else
    for patch_file in "${site_webtiles_patches[@]}"; do
        apply_webtiles_patch "$patch_file"
    done
fi
# TODO: delete localStorage.removeItem("DWEM"); should be removed (temporal setting)
if ! python3 "$(dirname "${BASH_SOURCE[0]}")/update_cnc_dwem_modules.py" "$WEBDIR/templates/client.html"; then
    exit 1
fi

# Pre-binding old numeric-only Housing snapshots is an installation migration,
# not a WebTiles request-side operation.  Run it as Crawl's filesystem owner so
# its 0600 immutable bindings remain readable by the game process.  The utility
# opens the live account database read-only and is safe to repeat on updates.
housing_maps_dir="${DGL_CHROOT%/}${CHROOT_CRAWL_BASEDIR}/crawl-housing/saves/housing-maps"
housing_backfill_script="$(dirname "${BASH_SOURCE[0]}")/backfill_housing_bindings.py"
if ! sudo -u "$DGL_USER" -- python3 \
    - --database "$LOGIN_DB" --maps-dir "$housing_maps_dir" \
    < "$housing_backfill_script"; then
    exit 1
fi

grep -qxF '# CRAWL.NEMELEX.CARDS' /dgldir/data/crawl-git-settings/init.txt || sed -i '1i# CRAWL.NEMELEX.CARDS' /dgldir/data/crawl-git-settings/init.txt
dgl publish --confirm > /dev/null 2>&1
echo
