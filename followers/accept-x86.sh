#!/bin/sh
set -eu

mode=${1:-container}
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

case $mode in
    github|container|cloud) ;;
    *) printf 'usage: %s github|container|cloud\n' "$0" >&2; exit 2 ;;
esac

# Portable runtime checks are deliberately stronger than syntax-only CI. They
# do not claim physical Android or persistent-Hetzner acceptance.
sh "$root/tests/entrypoint.sh"
sh "$root/tests/targets.sh"
sh "$root/tests/phone-binaries.sh"
if [ -f "$root/tests/github-normalization.sh" ]; then
    sh "$root/tests/github-normalization.sh"
fi

case $mode in
    github|container)
        CATFOOD_TARGET=container "$root/catfood" --target | grep '^container$' >/dev/null
        ;;
    cloud)
        CATFOOD_TARGET=cloud "$root/catfood" --target | grep '^cloud$' >/dev/null
        ;;
esac

printf 'x86 follower acceptance passed: %s\n' "$mode"
