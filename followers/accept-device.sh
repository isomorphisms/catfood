#!/bin/sh
set -eu

[ "$#" -eq 1 ] || {
    printf 'usage: %s phone|tablet\n' "$0" >&2
    exit 2
}
target=$1
case $target in
    phone|tablet) ;;
    *) printf 'usage: %s phone|tablet\n' "$0" >&2; exit 2 ;;
esac

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

# Do not let an explicit override turn the wrong physical architecture into a
# passing receipt. Target detection itself is not acceptance, but a mismatch is
# enough to reject the run before installation.
actual=$(CATFOOD_TARGET=auto sh "$root/catfood" --target)
if [ "$actual" != "$target" ]; then
    printf 'physical target mismatch: expected %s, detected %s\n' \
        "$target" "$actual" >&2
    exit 1
fi

CATFOOD_TARGET=$target sh "$root/catfood"
sh "$root/android/check.sh" gaps "$target"

workspace=${CATFOOD_ROOT:-$HOME/opt}
command=$workspace/bin/google-drive-unzip
test -x "$command" || {
    printf 'missing installed command: %s\n' "$command" >&2
    exit 1
}

# This crosses the installed runtime boundary without requiring private Google
# credentials. A live authenticated Drive extraction remains a separate receipt.
"$command" --help >/dev/null

printf 'physical-device delivery acceptance passed: %s at %s\n' \
    "$target" "$root"
