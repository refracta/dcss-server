#! /bin/bash

assert-login-db-exists

(( $# == 1 )) || \
    report-usage <<EOF
<dgl-username / email address>

Gives a password hint for the given username, and (if run as root)
prompts for a new password. You may ^C out at the new password
prompt.
EOF

password-hint() {
    local user=$1
    sqlite3 "$LOGIN_DB" <<EOF
SELECT SUBSTR(password, 1, 2)
FROM dglusers
WHERE username='$user' OR email='$user';
EOF
}

count-users() {
    local user=$1
    sqlite3 "$LOGIN_DB" <<EOF
SELECT COUNT(*)
FROM dglusers
WHERE username='$user' OR email='$user';
EOF
}

assert-password-safe() {
    local password="$1"
    if [[ "$password" =~ \' ]]; then
        echo -e "Sorry, I can't handle passwords containing '"
        exit 1
    fi
}

change-password() {
    local user="$1"
    local password_clear="$2"

    assert-password-safe "$password_clear"
    local password_crypt
    password_crypt="$(perl -le 'print crypt($ARGV[0], substr($ARGV[0], 0, 2))' "$password_clear")"
    sqlite3 "$LOGIN_DB" <<EOF
UPDATE dglusers
SET password='$password_crypt'
WHERE username='$user' OR email='$user';
EOF
}

assert-sane-user-match() {
    local user=$1
    local count
    count=$(count-users "$user")
    if (( count != 1 )); then
        if (( count == 0 )); then
            abort-saying "Can't find user matching '$user'"
        else
            abort-saying "Too many user matches for '$user'"
        fi
    fi
}

USER=$1
assert-sane-user-match "$USER"

echo "Password hint for $USER: '$(password-hint "$USER")'"

if [[ "$UID" == "0" ]]; then
    echo
    read -s -p -r "Enter new password for $USER: " PASSWORD
    echo
    if [[ -z "$PASSWORD" ]]; then
        abort-saying "Empty password"
    fi
    read -s -p -r "Retype password for $USER: " CONFIRM_PASSWORD
    echo

    if [[ "$PASSWORD" != "$CONFIRM_PASSWORD" ]]; then
        abort-saying "Passwords do not match"
    fi

    change-password "$USER" "$PASSWORD"
    echo "Updated password for $USER"
else
    cat <<EOF

If you'd like to change the password for $USER, rerun this command as root:

  $SCRIPT_NAME $@

EOF
fi
