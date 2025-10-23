#! /bin/bash

help <<EOF

$SCRIPT_NAME: Manages dgamelaunch admin users.

Usage: $SCRIPT_NAME ls           List admin users
       $SCRIPT_NAME add <user>   Make <user> an admin
       $SCRIPT_NAME rm <user>    Make <user> a regular (non-admin) user.

EOF

assert-login-db-exists

SUBCOMMAND=$1
shift
[[ -z "$SUBCOMMAND" ]] && SUBCOMMAND="ls"

admin-ls() {
    echo "Existing admin users:"
    login-query <<EOF
SELECT username, email FROM dglusers
WHERE (flags & 1) = 1
ORDER BY username;
EOF
}


dgl-user-make-admin() {
    local user="$1"
    login-query <<EOF
UPDATE dglusers
SET flags = flags | 1
WHERE username='$user';
EOF
}

dgl-user-unmake-admin() {
    local user="$1"
    login-query <<EOF
UPDATE dglusers
SET flags = flags & ~1
WHERE username='$user';
EOF
}


admin-add() {
    local new_admin="$1"
    dgl-user-exists "$new_admin" || \
        abort-saying "Cannot find user $new_admin in dgl login db"
    if dgl-user-is-admin "$new_admin"; then
        echo -e "User $new_admin is already an admin"
        exit 0
    fi

    assert-running-as-root
    dgl-user-make-admin "$new_admin"

    if dgl-user-is-admin "$new_admin"; then
        printf "%s" "\nDone, $new_admin is now a DGL admin.\n"
        exit 0
    else
        echo -e "Oops, couldn't make $new_admin a DGL admin.\n"
        exit 1
    fi
}

admin-rm() {
    local ex_admin="$1"
    dgl-user-exists "$ex_admin" || \
        abort-saying "Cannot find user $ex_admin in dgl login db"
    if ! dgl-user-is-admin "$ex_admin"; then
        echo -e "User $ex_admin is not an admin, nothing to do"
        exit 0
    fi

    assert-running-as-root
    dgl-user-unmake-admin "$ex_admin"

    if ! dgl-user-is-admin "$ex_admin"; then
        printf "%s" "\nDone, $ex_admin is now a regular DGL non-admin user.\n"
        exit 0
    else
        echo -e "Oops, couldn't make $ex_admin a regular DGL non-admin user."
        exit 1
    fi
}

case $SUBCOMMAND in
    ls) admin-ls "$@" ;;
    add) each-do admin-add "$@" ;;
    rm) each-do admin-rm "$@" ;;
    *) abort-saying "Unknown usage: $SCRIPT_NAME $SUBCOMMAND"
esac
