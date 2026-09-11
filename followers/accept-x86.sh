#!/bin/sh
set -eu

mode=${1:-container}
controller_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
root=${2:-$controller_root}
root=$(CDPATH='' cd -- "$root" && pwd)

case $mode in
    github|container|cloud) ;;
    *) printf 'usage: %s github|container|cloud [SOURCE_ROOT]\n' "$0" >&2; exit 2 ;;
esac

# These checks validate portable control-plane/runtime contracts. They do not
# claim physical Android or persistent-Hetzner acceptance.
sh "$root/tests/entrypoint.sh"
sh "$root/tests/targets.sh"
sh "$root/tests/android-delivery.sh"
if [ -f "$root/tests/github-normalization.sh" ]; then
    sh "$root/tests/github-normalization.sh"
fi

case $mode in
    github|container) CATFOOD_TARGET=container "$root/catfood" --target | grep '^container$' >/dev/null ;;
    cloud) CATFOOD_TARGET=cloud "$root/catfood" --target | grep '^cloud$' >/dev/null ;;
esac

printf 'x86 follower acceptance passed: %s at %s\n' "$mode" "$root"
