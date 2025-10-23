#! /bin/bash

COMMAND="$1"

if [[ -z "$COMMAND" ]]; then
    help <<EOF
Gives help on how to use a command.

Usage: $SCRIPT_NAME <command>

Where <command> is one of: $(list-all-actions)
EOF
fi

SCRIPT="$(resolve-action "$COMMAND")"
[[ -z "$SCRIPT" ]] && exit 1

HELPFILE="help/$COMMAND.txt"
if [[ ! -f "$HELPFILE" ]]; then
    abort-saying "No help available for \"dgl $COMMAND\""
fi

cat "$HELPFILE"
