#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
manifest=${CATFOOD_MANIFEST:-$root/tools.tsv}

awk '
    /^[[:space:]]*($|#)/ { next }

    NF != 4 {
        printf "%s:%d: expected four fields, found %d\n", FILENAME, NR, NF > "/dev/stderr"
        failed = 1
        next
    }

    $1 == "." || $1 == ".." || $1 !~ /^[[:alnum:]_.-]+$/ {
        printf "%s:%d: unsafe checkout name: %s\n", FILENAME, NR, $1 > "/dev/stderr"
        failed = 1
    }

    $2 !~ /^https:\/\/github[.]com\/[^/]+\/[^/]+[.]git$/ {
        printf "%s:%d: repository must be an explicit GitHub HTTPS .git URL: %s\n", FILENAME, NR, $2 > "/dev/stderr"
        failed = 1
    }

    $3 !~ /^[[:alnum:]_.\/-]+$/ {
        printf "%s:%d: unsafe branch name: %s\n", FILENAME, NR, $3 > "/dev/stderr"
        failed = 1
    }

    $4 != "none" && $4 != "recursive" {
        printf "%s:%d: submodules must be none or recursive: %s\n", FILENAME, NR, $4 > "/dev/stderr"
        failed = 1
    }

    seen_name[$1]++ {
        printf "%s:%d: duplicate checkout name: %s\n", FILENAME, NR, $1 > "/dev/stderr"
        failed = 1
    }

    seen_repository[$2]++ {
        printf "%s:%d: duplicate repository: %s\n", FILENAME, NR, $2 > "/dev/stderr"
        failed = 1
    }

    END { exit failed }
' "$manifest"

case ${1:-} in
    '')
        ;;
    --remote)
        command -v git >/dev/null 2>&1 || {
            printf '%s\n' 'remote manifest checking needs git' >&2
            exit 127
        }

        failures=0
        while read -r name repository branch submodules || [ -n "${name:-}" ]; do
            case ${name:-} in
                ''|'#'*) continue ;;
            esac

            if git ls-remote --exit-code --heads "$repository" "refs/heads/$branch" >/dev/null 2>&1; then
                printf '%-32s %s\n' "$name" "$branch"
            else
                printf '%-32s missing remote branch %s\n' "$name" "$branch" >&2
                failures=1
            fi
        done < "$manifest"
        [ "$failures" -eq 0 ]
        ;;
    *)
        printf 'usage: %s [--remote]\n' "$0" >&2
        exit 2
        ;;
esac

printf '%s\n' 'cat food manifest is valid'
