#!/bin/sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
workspace=${CATFOOD_ROOT:-/opt}
manifest=${CATFOOD_MANIFEST:-$script_directory/repositories.tsv}
tab=$(printf '\t')

while IFS="$tab" read -r name repository branch submodules || [ -n "${name:-}" ]; do
    case ${name:-} in
        ''|'#'*) continue ;;
    esac

    destination=$workspace/$name
    if [ ! -e "$destination/.git" ]; then
        printf '%-22s missing\n' "$name"
        continue
    fi

    revision=$(git -C "$destination" rev-parse --short HEAD)
    current_branch=$(git -C "$destination" symbolic-ref --quiet --short HEAD || printf 'detached')
    dirty=''
    if [ -n "$(git -C "$destination" status --porcelain)" ]; then
        dirty=' dirty'
    fi

    printf '%-22s %-20s %s%s\n' "$name" "$current_branch" "$revision" "$dirty"
done < "$manifest"
