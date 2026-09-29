#!/bin/sh
set -eu

usage() {
    printf '%s\n' 'usage: sdf/install-grease.sh /path/to/grease-netbsd-9.3-amd64.tar.gz' >&2
    exit 2
}

[ "$#" -eq 1 ] || usage
archive=$1
[ -f "$archive" ] || {
    printf 'Grease package not found: %s\n' "$archive" >&2
    exit 1
}

root_script=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
. "$root_script/platform.sh"
. "$root_script/grease-package.conf"
CATFOOD_SDF_EXPECT_RELEASE=$GREASE_TARGET_RELEASE
export CATFOOD_SDF_EXPECT_RELEASE
catfood_sdf_require_platform

root=${CATFOOD_ROOT:-"$HOME/opt"}
packages=$root/packages
bin=$root/bin
dest=$packages/grease-netbsd-9.3-amd64-$GREASE_REPOSITORY_REVISION
stage=$packages/.grease-netbsd-9.3-amd64-$GREASE_REPOSITORY_REVISION.$

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
[ -x "$stage/greasecpp" ] || {
    printf '%s\n' 'Grease package is missing executable greasecpp' >&2
    exit 1
}
[ -x "$stage/grease" ] || {
    printf '%s\n' 'Grease package is missing executable grease default' >&2
    exit 1
}

"$stage/greasecpp" -c 'echo greasecpp-sdf-install-ready' >/dev/null
"$stage/grease" -c 'echo grease-sdf-install-ready' >/dev/null

rm -rf "$dest"
mv "$stage" "$dest"
trap - EXIT HUP INT TERM

for name in greasecpp oils-for-unix grease; do
    link_tmp=$bin/.$name.$
    rm -f "$link_tmp"
    ln -s "$dest/$name" "$link_tmp"
    mv -f "$link_tmp" "$bin/$name"
done

"$bin/greasecpp" -c 'echo greasecpp-sdf-ready'
"$bin/grease" -c 'echo grease-sdf-ready'
printf 'installed=%s\n' "$dest"
printf 'implementation=%s\n' "$bin/greasecpp"
printf 'command=%s\n' "$bin/grease"
