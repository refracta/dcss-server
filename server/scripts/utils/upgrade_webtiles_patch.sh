#!/bin/bash

set -u

if [ "$#" -ne 3 ]; then
    echo "usage: $0 WEBDIR CURRENT_PATCH LEGACY_PATCH_DIR" >&2
    exit 2
fi

webdir="$1"
current_patch="$2"
legacy_patch_dir="$3"

if [ ! -d "$webdir" ] || [ ! -f "$current_patch" ]; then
    echo "Housing WebTiles patch inputs are missing" >&2
    exit 1
fi

patch_check() {
    local direction="$1"
    local patch_file="$2"
    patch --batch --fuzz=0 -d "$webdir" --dry-run "$direction" -p0 \
        < "$patch_file" >/dev/null 2>&1
}

patch_apply() {
    local direction="$1"
    local patch_file="$2"
    patch --batch --fuzz=0 -d "$webdir" "$direction" -p0 \
        < "$patch_file"
}

if patch_check --forward "$current_patch"; then
    patch_apply --forward "$current_patch"
    exit $?
fi

if patch_check --reverse "$current_patch"; then
    echo "WebTiles patch already applied: $(basename "$current_patch")"
    exit 0
fi

# A running test server can already contain an older Housing overlay.  Strictly
# identify that complete legacy state, remove it, then install the current
# overlay.  Unknown or partial states remain fail-closed.
shopt -s nullglob
legacy_patches=("$legacy_patch_dir"/housing-session-*.patch)
shopt -u nullglob
for legacy_patch in "${legacy_patches[@]}"; do
    patch_check --reverse "$legacy_patch" || continue

    if ! patch_apply --reverse "$legacy_patch"; then
        echo "Could not remove legacy WebTiles patch: $legacy_patch" >&2
        exit 1
    fi

    if ! patch_check --forward "$current_patch"; then
        echo "Current WebTiles patch does not apply after legacy removal" >&2
        if patch_check --forward "$legacy_patch"; then
            patch_apply --forward "$legacy_patch" >/dev/null 2>&1 || true
        fi
        exit 1
    fi

    if patch_apply --forward "$current_patch"; then
        echo "Upgraded WebTiles patch from $(basename "$legacy_patch")"
        exit 0
    fi

    # This should only be reachable for an I/O failure after the successful
    # dry-run.  Make a best effort to restore the recognized legacy overlay.
    if patch_check --reverse "$current_patch"; then
        patch_apply --reverse "$current_patch" >/dev/null 2>&1 || true
    fi
    if patch_check --forward "$legacy_patch"; then
        patch_apply --forward "$legacy_patch" >/dev/null 2>&1 || true
    fi
    echo "Could not install current Housing WebTiles patch" >&2
    exit 1
done

echo "Housing WebTiles patch state is unknown or partially applied" >&2
exit 1
