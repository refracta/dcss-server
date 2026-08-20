#!/bin/bash

set -eu

housing_git_ref="${HOUSING_GIT_REF:-housing/housing}"

case "$housing_git_ref" in
    housing/housing|housing/housing-staging)
        ;;
    *)
        echo "HOUSING_GIT_REF must be housing/housing or housing/housing-staging." >&2
        exit 2
        ;;
esac

printf '%s\n' "$housing_git_ref"
