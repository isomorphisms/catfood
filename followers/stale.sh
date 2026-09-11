#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
latest=$(sh "$root/followers/manage.sh" latest)
found=0

value() {
    awk -F '\t' -v key="$2" '$1 == key { print $2; found=1 } END { if (!found) exit 1 }' "$1"
}

for job in "$root"/followers/jobs/*.tsv; do
    [ -f "$job" ] || continue
    state=$(value "$job" state)
    case $state in pending|blocked|unsupported) ;; *) continue ;; esac
    trigger=$(value "$job" trigger_commit)
    [ "$trigger" != "$latest" ] || continue
    if git -C "$root" merge-base --is-ancestor "$trigger" "$latest" 2>/dev/null; then
        printf 'stale follower\t%s\t%s\t%s\tlatest=%s\n' \
            "$(value "$job" job_id)" "$trigger" "$state" "$latest"
        found=1
    fi
done

if [ "$found" -ne 0 ]; then
    printf '%s\n' 'Unresolved follower work predates the current source trigger; complete it or record explicit supersession.' >&2
    exit 1
fi

printf 'no unresolved ancestor follower drift behind %s\n' "$latest"
