#! /bin/bash

# shellcheck source=crawl-git.conf
source "$DGL_CONF_HOME/crawl-git.conf"

if [[ $UID != 0 ]]; then
    echo "$0 must be run as root!"
    exit 1
fi

if [[ $1 == -v || $1 == --verbose ]]; then
    verbose=1
else
    verbose=0
fi

verbiate() {
    ((verbose)) && echo "$@" >&2
}

quietly() {
    "$@" >/dev/null 2>&1
}

failures=()
skip=0 succ=0 fail=0
shopt -s nullglob
for ttyrec in "$TTYRECDIR"/*/*.ttyrec; do
    # Not working
    # If anyone has it open, skip it.
    # if quietly lsof "$ttyrec"; then
    #   verbiate -n "."
    #   (( ++skip ))
    #   continue
    # fi

    # It's a little messy, but it works.
    relative_path="${ttyrec#$TTYRECDIR/}"
    found=0
    for subdir in "$INPROGRESSDIR"/*; do
      inprogress_file="$subdir/${relative_path//\//:}"
      if [ -f "$inprogress_file" ]; then
        echo "File $ttyrec exists in progress directory $subdir as ${relative_path//\//:}. Skipping."
        verbiate -n "."
        (( ++skip ))
        found=1
        break
      fi
    done
    [ $found -eq 1 ] && continue

    if bzip2 "$ttyrec"; then
        (( ++succ ))
        verbiate -n "+"
    else
        (( ++fail ))
        verbiate -n "X"
        failures+=( "$ttyrec" )
    fi
done
verbiate

if (( fail || verbose )); then
    printf "%d succeeded\t%d failed\t%d skipped\n" "$succ" "$fail" "$skip"
    if (( fail )); then
        printf "\nFailing files:\n"
        printf "  %s\n" "${failures[@]}"
        exit 1
    fi
fi

exit 0
