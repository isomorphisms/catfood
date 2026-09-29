#!/bin/sh
set -eu

usage() {
    printf '%s\n' 'usage: sdf/install-grease.sh /path/to/grease-netbsd-11-amd64.tar.gz' >&2
    exit 2
}

[ "$#" -eq 1 ] || usage
archive=$1
[ -f "$archive" ] || {
    printf 'Grease package not found: %s\n' "$archive" >&2
    exit 1
}

root=${CATFOOD_ROOT:-"$HOME/opt"}
packages=$root/packages
bin=$root/bin
dest=$packages/grease-netbsd-11-amd64
stage=$packages/.grease-netbsd-11-amd64.$$

cleanup() {
    rm -rf "$stage"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$packages" "$bin"
rm -rf "$stage"
mkdir -p "$stage"
tar -xzf "$archive" -C "$stage"

[ -x "$stage/oils-for-unix" ] || {
    printf '%s\n' 'Grease package is missing executable oils-for-unix' >&2
    exit 1
}
[ -x "$stage/grease" ] || {
    printf '%s\n' 'Grease package is missing executable grease wrapper' >&2
    exit 1
}

"$stage/grease" -c 'echo grease-sdf-install-ready' >/dev/null

rm -rf "$dest"
mv "$stage" "$dest"
trap - EXIT HUP INT TERM

ln -sf "$dest/grease" "$bin/grease"
ln -sf "$dest/oils-for-unix" "$bin/oils-for-unix"

"$bin/grease" -c 'echo grease-sdf-ready'
printf 'installed=%s\n' "$dest"
printf 'command=%s\n' "$bin/grease"
