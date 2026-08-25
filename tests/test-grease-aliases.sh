#!/bin/sh
set -eu

repository_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
work_directory=$(mktemp -d)
cleanup() {
    rm -rf "$work_directory"
}
trap cleanup EXIT HUP INT TERM

. "$repository_root/aliases.grease"

target="$work_directory/a directory/inside"
(
    mkcd "$target"
    test "$PWD" = "$target"
)
test -d "$target"

blocker="$work_directory/not-a-directory"
printf '%s\n' blocker > "$blocker"
starting_directory=$PWD
if mkcd "$blocker/inside" 2>/dev/null; then
    printf '%s\n' 'mkcd accepted a failed mkdir' >&2
    exit 1
fi
test "$PWD" = "$starting_directory"

if mkcd 2>/dev/null; then
    printf '%s\n' 'mkcd accepted a missing directory argument' >&2
    exit 1
fi

profile="$work_directory/profile"
workspace="$work_directory/workspace"
prefix="$work_directory/prefix"
home_directory="$work_directory/home"
mkdir -p "$home_directory"

for pass in 1 2; do
    HOME="$home_directory" \
    CATFOOD_ROOT="$workspace" \
    CATFOOD_PREFIX="$prefix" \
    CATFOOD_PROFILE="$profile" \
        sh "$repository_root/activate.sh" >/dev/null
done

test "$(grep -Fc '# catfood grease aliases' "$profile")" = 1
grep -Fx ". \"$repository_root/aliases.grease\"" "$profile" >/dev/null

printf '%s\n' 'Grease alias tests: ok'
