#!/bin/bash

REPO="refracta/dcss-server"
SPLIT_SIZE="1GiB"
KEEP_FILES=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        download)
            ACTION="download"
            ;;
        upload)
            ACTION="upload"
            ;;
        delete)
            ACTION="delete"
            ;;
        -r|--repo)
            REPO="$2"
            shift
            ;;
        -n|--name)
            NAME="$2"
            shift
            ;;
        -v|--version)
            VERSION="$2"
            shift
            ;;
        -p|--path)
            PATH_DIR="$2"
            shift
            ;;
        -t|--tag)
            TAG="$2"
            shift
            ;;
        -T|--title)
            TITLE="$2"
            shift
            ;;
        -s|--split-size)
            SPLIT_SIZE="$2"
            shift
            ;;
        -b|--branch)
            BRANCH="$2"
            shift
            ;;
        -k|--keep)
            KEEP_FILES=true
            ;;
        -l|--last)
            LAST="$2"
            shift
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
    shift
done

get_latest_tag() {
    local name=$1
    curl -s "https://api.github.com/repos/$REPO/tags" | jq -r ".[].name" | grep "^${name}-" | sort -rV | head -n 1
}

download_files() {
    mkdir -p "$PATH_DIR"

    if [ -n "$TAG" ]; then
        release_info=$(curl -s "https://api.github.com/repos/$REPO/releases/tags/$TAG")
    elif [ -n "$NAME" ] && [ -n "$VERSION" ]; then
        release_info=$(curl -s "https://api.github.com/repos/$REPO/releases/tags/${NAME}-${VERSION}")
    elif [ -n "$NAME" ]; then
        latest_tag=$(get_latest_tag "$NAME")
        if (("$latest_tag")); then
            release_info=$(curl -s "https://api.github.com/repos/$REPO/releases/tags/$latest_tag")
        else
            echo "No releases found for name prefix: $NAME"
            exit 1
        fi
    else
        echo "Either tag (-t) or name (-n) must be specified."
        exit 1
    fi

    release_tag=$(echo $release_info | jq -r '.tag_name')
    release_title=$(echo $release_info | jq -r '.name')

    echo "Release: $release_title ($release_tag)"

    assets=$(echo $release_info | jq -r '.assets[] | select(.name | test("^binary_")) | .browser_download_url')

    for url in $assets; do
        echo "Downloading $url"
        curl -L -o "$PATH_DIR/$(basename $url)" $url
    done

    cat "$PATH_DIR/binary_"* > "$PATH_DIR/binary.tar.gz"
    if [ "$KEEP_FILES" = false ]; then
        rm "$PATH_DIR/binary_"*
    fi

    tar -xvzf "$PATH_DIR/binary.tar.gz" -C "$PATH_DIR"
    if [ "$KEEP_FILES" = false ]; then
        rm "$PATH_DIR/binary.tar.gz"
    fi

    echo "Download and extraction completed!"
}

upload_files() {
    PARENT_DIR=$(dirname "$PATH_DIR")

    tar -cvzf - -C "$PATH_DIR" . | split --verbose -b "$SPLIT_SIZE" - "$PARENT_DIR/binary_"

    if [ -z "$TAG" ]; then
        if [ -n "$NAME" ] && [ -n "$VERSION" ]; then
            tag="${NAME}-${VERSION}"
        else
            tag="${NAME}-$(date -u +%Y%m%d%H%M)"
        fi
    else
        tag="$TAG"
    fi

    title=${TITLE:-$tag}

    if [ -n "$BRANCH" ]; then
        gh release create "$tag" -R "$REPO" --title "$title" --target "$BRANCH" -n ""
    else
        gh release create "$tag" -R "$REPO" --title "$title" -n ""
    fi

    gh release upload "$tag" "$PARENT_DIR/binary_"* -R "$REPO"

    if [ "$KEEP_FILES" = false ]; then
        rm "$PARENT_DIR/binary_"*
    fi

    echo "Compression and upload completed!"
}

delete_releases() {
    if [ -z "$NAME" ]; then
        echo "Name (-n) is required for delete action."
        exit 1
    fi

    releases=$(curl -s "https://api.github.com/repos/$REPO/releases" | jq -r ".[] | select(.tag_name | startswith(\"$NAME\")) | .tag_name")
    tags=($(echo "$releases" | sort -rV))
    if [ -n "$LAST" ]; then
        tags=(${tags[@]:$LAST})
    fi

    for tag in "${tags[@]}"; do
        echo "Deleting release and tag: $tag"
        gh release delete "$tag" -R "$REPO" -y
        gh api -X DELETE "repos/$REPO/git/refs/tags/$tag"
    done

    echo "Deletion completed!"
}

if [ "$ACTION" == "download" ]; then
    if [ -z "$PATH_DIR" ] || [ -z "$NAME" ]; then
        echo "Path (-p) and name (-n) are required for download action."
        exit 1
    fi
    download_files
elif [ "$ACTION" == "upload" ]; then
    if [ -z "$PATH_DIR" ] || [ -z "$NAME" ]; then
        echo "Path (-p) and name (-n) are required for upload action."
        exit 1
    fi
    upload_files
elif [ "$ACTION" == "delete" ]; then
    delete_releases
else
    echo "Action (download/upload/delete) is required."
    exit 1
fi
