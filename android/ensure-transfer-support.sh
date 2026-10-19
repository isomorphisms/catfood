#!/bin/sh
# Explicit commodity-runtime acquisition; no compiler or source-build lane.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$root/android/target.sh"
target=$(catfood_detect_android_target)
catfood_android_require_device "$target"
case ${PREFIX:-} in /data/data/com.termux/files/usr) ;; *) exit 2;; esac
for pair in gh:gh curl:curl tar:tar awk:gawk grep:grep sed:sed cmp:diffutils timeout:coreutils sha256sum:coreutils readlink:coreutils mktemp:coreutils od:coreutils xargs:findutils; do
    command_name=${pair%%:*}
    package_name=${pair#*:}
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '\033[33mACTION Cat Food installs declared Termux runtime %s\033[0m\n' "$package_name" >&2
        "$PREFIX/bin/pkg" install -y "$package_name" >&2
        command -v "$command_name" >/dev/null 2>&1 || exit 127
    fi
done
