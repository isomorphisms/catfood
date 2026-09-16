#!/bin/sh
set -eu

mode=${1:-container}
controller_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
root=${2:-$controller_root}
root=$(CDPATH='' cd -- "$root" && pwd)

case $mode in
    github|container|cloud|void) ;;
    *) printf 'usage: %s github|container|cloud|void [SOURCE_ROOT]\n' "$0" >&2; exit 2 ;;
esac

# First keep the portable control-plane contracts explicit. These checks are
# necessary but are not the runtime receipt by themselves.
sh "$root/tests/entrypoint.sh"
sh "$root/tests/targets.sh"
sh "$root/tests/android-delivery.sh"
if [ -f "$root/tests/github-normalization.sh" ]; then
    sh "$root/tests/github-normalization.sh"
fi

case $mode in
    github|container) target=container ;;
    cloud) target=cloud ;;
    void) target=void ;;
esac

case $mode in
    github|container)
        default_workspace=${RUNNER_TEMP:-${TMPDIR:-/tmp}}/catfood-follower-$mode
        ;;
    cloud|void)
        default_workspace=/opt
        ;;
esac
workspace=${CATFOOD_FOLLOWER_ROOT:-$default_workspace}
prefix=${CATFOOD_FOLLOWER_PREFIX:-}
cache=${CATFOOD_FOLLOWER_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/catfood-follower-$mode}

rm_workspace=0
case $mode in
    github|container)
        rm -rf "$workspace"
        rm_workspace=1
        ;;
esac

cleanup() {
    if [ "$rm_workspace" -eq 1 ] && [ "${CATFOOD_FOLLOWER_KEEP:-0}" != 1 ]; then
        rm -rf "$workspace"
    fi
}
trap cleanup EXIT HUP INT TERM

if [ -n "$prefix" ]; then
    CATFOOD_TARGET=$target \
    CATFOOD_ROOT=$workspace \
    CATFOOD_PREFIX=$prefix \
    CATFOOD_CACHE=$cache \
    CATFOOD_NO_PROFILE=1 \
        "$root/catfood"
else
    CATFOOD_TARGET=$target \
    CATFOOD_ROOT=$workspace \
    CATFOOD_CACHE=$cache \
    CATFOOD_NO_PROFILE=1 \
        "$root/catfood"
fi

# A runtime follower must execute the delivered command. `--help` deliberately
# avoids requiring user OAuth credentials while still crossing the installed
# YSH/Grease command boundary on this exact target.
test -x "$workspace/bin/google-drive-unzip"
"$workspace/bin/google-drive-unzip" --help >/dev/null

printf 'x86 follower runtime acceptance passed: %s (%s) at %s\n' \
    "$mode" "$target" "$root"
