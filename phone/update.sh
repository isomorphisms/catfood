#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
[ "$branch" = phone ] || {
    echo "phone Cat Food update requires the phone branch; current branch: ${branch:-detached}" >&2
    exit 1
}

origin=$(git remote get-url origin)
case "$origin" in
    https://github.com/isomorphisms/catfood.git|git@github.com:isomorphisms/catfood.git) ;;
    *)
        echo "unexpected Cat Food origin: $origin" >&2
        exit 1
        ;;
esac

[ -z "$(git status --porcelain)" ] || {
    echo 'phone Cat Food checkout is dirty; refusing to move it' >&2
    exit 1
}

git fetch --depth 1 origin phone
git merge --ff-only FETCH_HEAD
sh phone/build.sh
