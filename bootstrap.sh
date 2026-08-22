#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
workspace=${CATFOOD_ROOT:-/opt}
history_depth=${CATFOOD_DEPTH:-12}
manifest=${CATFOOD_MANIFEST:-$root/tools.tsv}
grease=$workspace/grease
grease_url=https://github.com/isomorphisms/grease.git
grease_branch=main

need() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'cat food needs %s\n' "$1" >&2
        exit 127
    }
}

update_grease() {
    if [ -e "$grease/.git" ]; then
        origin=$(git -C "$grease" remote get-url origin 2>/dev/null || true)
        if [ "$origin" != "$grease_url" ]; then
            printf 'grease origin is %s, expected %s; leaving it alone\n' "${origin:-<missing>}" "$grease_url" >&2
            return 1
        fi

        git -C "$grease" fetch --prune origin "$grease_branch"

        if [ -n "$(git -C "$grease" status --porcelain)" ]; then
            printf 'grease has local changes; fetched but did not move it\n'
        else
            if git -C "$grease" show-ref --verify --quiet "refs/heads/$grease_branch"; then
                git -C "$grease" checkout "$grease_branch"
            else
                git -C "$grease" checkout -b "$grease_branch" --track "origin/$grease_branch"
            fi
            git -C "$grease" merge --ff-only "origin/$grease_branch"
        fi
    elif [ -e "$grease" ]; then
        printf '%s exists but is not a git checkout; leaving it alone\n' "$grease" >&2
        return 1
    else
        git clone --depth "$history_depth" --single-branch --branch "$grease_branch" \
            --recurse-submodules --shallow-submodules "$grease_url" "$grease"
    fi

    git -C "$grease" submodule sync --recursive
    git -C "$grease" submodule update --init --recursive --depth "$history_depth"
}

runnable_ysh() {
    candidate=$1
    [ -x "$candidate" ] && "$candidate" -c ':' >/dev/null 2>&1
}

choose_shell() {
    if [ -n "${CATFOOD_YSH:-}" ]; then
        if runnable_ysh "$CATFOOD_YSH"; then
            printf '%s\n' "$CATFOOD_YSH"
            return 0
        fi
        printf 'CATFOOD_YSH=%s is not runnable\n' "$CATFOOD_YSH" >&2
        return 1
    fi

    if runnable_ysh "$workspace/bin/ysh"; then
        printf '%s\n' "$workspace/bin/ysh"
        return 0
    fi

    system_ysh=$(command -v ysh 2>/dev/null || true)
    if [ -n "$system_ysh" ] && runnable_ysh "$system_ysh"; then
        printf '%s\n' "$system_ysh"
        return 0
    fi

    if runnable_ysh "$grease/source/bin/ysh"; then
        printf '%s\n' "$grease/source/bin/ysh"
        return 0
    fi

    printf '%s\n' sh
}

need git
mkdir -p "$workspace"
update_grease

shell=$(choose_shell)
if [ "$shell" = sh ]; then
    printf '%s\n' 'no runnable YSH yet; finishing the first feed with POSIX sh'
else
    printf 'feeding remaining tools with %s\n' "$shell"
fi

CATFOOD_ROOT=$workspace CATFOOD_DEPTH=$history_depth CATFOOD_MANIFEST=$manifest \
    exec "$shell" "$root/update-tools.ysh"
