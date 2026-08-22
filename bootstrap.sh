#!/bin/sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
workspace=${CATFOOD_ROOT:-/opt}
history_depth=${CATFOOD_DEPTH:-12}
manifest=${CATFOOD_MANIFEST:-$script_directory/repositories.tsv}
tab=$(printf '\t')
failures=0

need() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'cat food needs %s\n' "$1" >&2
        exit 127
    }
}

feed_repository() {
    name=$1
    repository=$2
    branch=$3
    submodules=$4
    destination=$workspace/$name

    printf '%-22s %s\n' "$name" "$destination"

    if [ -e "$destination/.git" ]; then
        origin=$(git -C "$destination" remote get-url origin 2>/dev/null || true)
        if [ "$origin" != "$repository" ]; then
            printf '  origin is %s, expected %s; leaving it alone\n' "${origin:-<missing>}" "$repository" >&2
            return 1
        fi

        if ! git -C "$destination" fetch --depth "$history_depth" origin "$branch"; then
            printf '  fetch failed\n' >&2
            return 1
        fi

        if [ -n "$(git -C "$destination" status --porcelain)" ]; then
            printf '  dirty working tree; fetched but did not move it\n'
            return 0
        fi

        if git -C "$destination" show-ref --verify --quiet "refs/heads/$branch"; then
            if ! git -C "$destination" switch "$branch"; then
                return 1
            fi
        else
            if ! git -C "$destination" switch --create "$branch" --track "origin/$branch"; then
                return 1
            fi
        fi

        if ! git -C "$destination" merge --ff-only "origin/$branch"; then
            printf '  local history diverged; not rewriting it\n' >&2
            return 1
        fi
    elif [ -e "$destination" ]; then
        printf '  path exists but is not a git checkout; leaving it alone\n' >&2
        return 1
    else
        if [ "$submodules" = yes ]; then
            if ! git clone --depth "$history_depth" --single-branch --branch "$branch" \
                --recurse-submodules --shallow-submodules "$repository" "$destination"; then
                return 1
            fi
        else
            if ! git clone --depth "$history_depth" --single-branch --branch "$branch" \
                "$repository" "$destination"; then
                return 1
            fi
        fi
    fi

    if [ "$submodules" = yes ]; then
        if ! git -C "$destination" submodule update --init --recursive --depth "$history_depth"; then
            printf '  submodule update failed\n' >&2
            return 1
        fi
    fi
}

need git
mkdir -p "$workspace"

while IFS="$tab" read -r name repository branch submodules || [ -n "${name:-}" ]; do
    case ${name:-} in
        ''|'#'*) continue ;;
    esac

    if ! feed_repository "$name" "$repository" "$branch" "$submodules"; then
        failures=1
    fi
done < "$manifest"

if [ "$failures" -ne 0 ]; then
    printf 'cat food finished with failures\n' >&2
    exit 1
fi

printf 'cat food is current under %s\n' "$workspace"
