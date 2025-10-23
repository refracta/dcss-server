#! /bin/bash

set -e

DGAMELAUNCH="$1"

valid-dgl() {
    [[ -n "$DGAMELAUNCH" && -x "$DGAMELAUNCH" ]]
}

valid-dgl || DGAMELAUNCH="$(command -v dgamelaunch 2>/dev/null || true)"
valid-dgl || DGAMELAUNCH=/usr/local/sbin/dgamelaunch
valid-dgl || abort-saying "Cannot find dgamelaunch binary"

STRACE_OUT=strace.out

if not-running-as-root; then
    cat-error <<EOF
$SCRIPT_NAME: runs dgamelaunch with the current (testing) configuration

Run this command as root to test your dgamelaunch.conf

Options:
    --strace: Run dgamelaunch with strace and dump strace output to $STRACE_OUT

EOF
    exit 1
fi

[[ "$1" == "--strace" ]] && STRACE=1 || STRACE=

TEST_FILE=dgamelaunch.conf
TMP_DIR=.tmp

# shellcheck disable=SC2064
trap "rm $TMP_DIR/$TEST_FILE && rmdir $TMP_DIR" EXIT

mkdir -p $TMP_DIR
dgl-run publish-conf --target "/$PWD/$TMP_DIR"

if [[ -z "$STRACE" ]]; then
    "$DGAMELAUNCH" -f "$TMP_DIR/$TEST_FILE"
else
    strace -f "$DGAMELAUNCH" -f "$TMP_DIR/$TEST_FILE" 2>$STRACE_OUT
fi
