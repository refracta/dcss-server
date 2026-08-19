#!/bin/bash

set -u
set -o pipefail

if [ "$#" -lt 3 ]; then
    echo "usage: $0 WEBDIR CURRENT_PATCH LEGACY_PATCH_DIR [SITE_PATCH ...]" >&2
    exit 2
fi

webdir="$1"
current_patch="$2"
legacy_patch_dir="$3"
shift 3
site_patches=("$@")

if [ ! -d "$webdir" ] || [ ! -f "$current_patch" ]; then
    echo "Housing WebTiles patch inputs are missing" >&2
    exit 1
fi
for site_patch in "${site_patches[@]}"; do
    if [ ! -f "$site_patch" ]; then
        echo "Site WebTiles patch input is missing: $site_patch" >&2
        exit 1
    fi
done

patch_check() {
    local target="$1"
    local direction="$2"
    local patch_file="$3"
    if [ "$direction" = --reverse ]; then
        patch --force --fuzz=0 -d "$target" --dry-run --reverse -p0 \
            < "$patch_file" >/dev/null 2>&1
    else
        patch --batch --fuzz=0 -d "$target" --dry-run --forward -p0 \
            < "$patch_file" >/dev/null 2>&1
    fi
}

patch_apply() {
    local target="$1"
    local direction="$2"
    local patch_file="$3"
    local quiet="$4"
    if [ "$quiet" = true ]; then
        if [ "$direction" = --reverse ]; then
            patch --force --fuzz=0 -d "$target" --reverse -p0 \
                < "$patch_file" >/dev/null 2>&1
        else
            patch --batch --fuzz=0 -d "$target" --forward -p0 \
                < "$patch_file" >/dev/null 2>&1
        fi
    else
        if [ "$direction" = --reverse ]; then
            patch --force --fuzz=0 -d "$target" --reverse -p0 \
                < "$patch_file"
        else
            patch --batch --fuzz=0 -d "$target" --forward -p0 \
                < "$patch_file"
        fi
    fi
}

shopt -s nullglob
housing_overlays=("$current_patch"
                  "$legacy_patch_dir"/housing-session-*.patch)
shopt -u nullglob

installed_overlay=""

install_patch_stack() {
    local target="$1"
    local quiet="$2"
    local index
    local overlay_patch
    local site_patch

    installed_overlay=""
    for overlay_patch in "${housing_overlays[@]}"; do
        if patch_check "$target" --reverse "$overlay_patch"; then
            installed_overlay="$overlay_patch"
            break
        fi
    done

    if [ -n "$installed_overlay" ]; then
        patch_apply "$target" --reverse "$installed_overlay" "$quiet" \
            || return 1
    fi

    # Peel installed site overlays in reverse application order.  This keeps
    # the test exact even when a later site patch changed an earlier patch's
    # reverse context.  Missing site patches are allowed and will be installed
    # during the forward pass below.
    for ((index=${#site_patches[@]} - 1; index >= 0; index--)); do
        site_patch="${site_patches[$index]}"
        if patch_check "$target" --reverse "$site_patch"; then
            patch_apply "$target" --reverse "$site_patch" "$quiet" \
                || return 1
        fi
    done

    for site_patch in "${site_patches[@]}"; do
        patch_check "$target" --forward "$site_patch" || return 1
        patch_apply "$target" --forward "$site_patch" "$quiet" || return 1
    done

    patch_check "$target" --forward "$current_patch" || return 1
    patch_apply "$target" --forward "$current_patch" "$quiet"
}

# Preflight the complete peel/apply/reapply sequence on a private copy.  This
# catches strict-context conflicts before making the first live-tree change.
probe_root=$(mktemp -d "${TMPDIR:-/tmp}/webtiles-patch-upgrade.XXXXXX") \
    || exit 1
trap 'rm -rf "$probe_root"' EXIT HUP INT TERM
if ! tar --dereference -C "$webdir" --exclude='./sockets' \
        --exclude='*.sock' -cf - . \
        | tar -C "$probe_root" -xf -; then
    echo "Could not create private WebTiles patch probe" >&2
    exit 1
fi

if ! install_patch_stack "$probe_root" true; then
    echo "WebTiles patch stack is unknown, partial, or conflicting" >&2
    exit 1
fi

preflight_overlay="$installed_overlay"
if ! install_patch_stack "$webdir" false; then
    echo "Could not install validated WebTiles patch stack" >&2
    exit 1
fi

if [ -z "$preflight_overlay" ]; then
    echo "Installed current Housing WebTiles patch"
elif [ "$preflight_overlay" = "$current_patch" ]; then
    echo "Refreshed current Housing WebTiles patch stack"
else
    echo "Upgraded WebTiles patch from $(basename "$preflight_overlay")"
fi
