#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

home=$temporary/home
workspace=$home/opt
state=$temporary/state
mkdir -p "$workspace"

printf '%s\n' '#!/system/bin/sh' 'printf rish-v1\\n' > "$workspace/rish"
printf '%s\n' 'dex-v1' > "$workspace/rish_shizuku.dex"
chmod 0755 "$workspace/rish"
chmod 0400 "$workspace/rish_shizuku.dex"

HOME="$home" CATFOOD_ROOT="$workspace" CATFOOD_STATE_HOME="$state" \
    sh "$root/android/preserve-shizuku.sh" save >/dev/null

test -f "$state/shizuku/current"
snapshot_id=$(cat "$state/shizuku/current")
snapshot=$state/shizuku/snapshots/$snapshot_id
test -f "$snapshot/rish"
test -f "$snapshot/rish_shizuku.dex"
grep -F 'scope	rish-bundle' "$snapshot/receipt.tsv" >/dev/null
grep -F 'manager_package	moe.shizuku.privileged.api' "$snapshot/receipt.tsv" >/dev/null
cmp "$workspace/rish" "$snapshot/rish"
cmp "$workspace/rish_shizuku.dex" "$snapshot/rish_shizuku.dex"

first_count=$(find "$state/shizuku/snapshots" -mindepth 1 -maxdepth 1 -type d | wc -l)
HOME="$home" CATFOOD_ROOT="$workspace" CATFOOD_STATE_HOME="$state" \
    sh "$root/android/preserve-shizuku.sh" save >/dev/null
second_count=$(find "$state/shizuku/snapshots" -mindepth 1 -maxdepth 1 -type d | wc -l)
test "$first_count" -eq 1
test "$second_count" -eq 1

printf '%s\n' '#!/system/bin/sh' 'printf rish-v2\\n' > "$workspace/rish"
HOME="$home" CATFOOD_ROOT="$workspace" CATFOOD_STATE_HOME="$state" \
    sh "$root/android/preserve-shizuku.sh" save >/dev/null
third_count=$(find "$state/shizuku/snapshots" -mindepth 1 -maxdepth 1 -type d | wc -l)
test "$third_count" -eq 2

# A custom Cat Food workspace must not outrank the established ~/opt rish
# location. Issue #93 specifies explicit directory, then ~/opt, then PATH.
other_workspace=$temporary/other-workspace
precedence_state=$temporary/precedence-state
mkdir -p "$other_workspace"
printf '%s\n' '#!/system/bin/sh' 'printf wrong-workspace-rish\\n' > "$other_workspace/rish"
printf '%s\n' 'wrong-workspace-dex' > "$other_workspace/rish_shizuku.dex"
HOME="$home" CATFOOD_ROOT="$other_workspace" CATFOOD_STATE_HOME="$precedence_state" \
    sh "$root/android/preserve-shizuku.sh" save >/dev/null
precedence_id=$(cat "$precedence_state/shizuku/current")
precedence_snapshot=$precedence_state/shizuku/snapshots/$precedence_id
grep -F "source_dir	$workspace" "$precedence_snapshot/receipt.tsv" >/dev/null
cmp "$workspace/rish" "$precedence_snapshot/rish"
cmp "$workspace/rish_shizuku.dex" "$precedence_snapshot/rish_shizuku.dex"

# An explicit source must outrank ~/opt.
explicit=$temporary/explicit
explicit_state=$temporary/explicit-state
mkdir -p "$explicit"
printf '%s\n' '#!/system/bin/sh' 'printf explicit-rish\\n' > "$explicit/rish"
printf '%s\n' 'explicit-dex' > "$explicit/rish_shizuku.dex"
chmod 0755 "$explicit/rish"
chmod 0400 "$explicit/rish_shizuku.dex"
HOME="$home" CATFOOD_ROOT="$other_workspace" CATFOOD_SHIZUKU_RISH_DIR="$explicit" \
    CATFOOD_STATE_HOME="$explicit_state" \
    sh "$root/android/preserve-shizuku.sh" save >/dev/null
explicit_id=$(cat "$explicit_state/shizuku/current")
explicit_snapshot=$explicit_state/shizuku/snapshots/$explicit_id
grep -F "source_dir	$explicit" "$explicit_snapshot/receipt.tsv" >/dev/null
cmp "$explicit/rish" "$explicit_snapshot/rish"
cmp "$explicit/rish_shizuku.dex" "$explicit_snapshot/rish_shizuku.dex"

# PATH is the final discovery tier when ~/opt is absent.
path_home=$temporary/path-home
path_source=$temporary/path-source
path_state=$temporary/path-state
mkdir -p "$path_home" "$path_source"
printf '%s\n' '#!/system/bin/sh' 'printf path-rish\\n' > "$path_source/rish"
printf '%s\n' 'path-dex' > "$path_source/rish_shizuku.dex"
chmod 0755 "$path_source/rish"
chmod 0400 "$path_source/rish_shizuku.dex"
HOME="$path_home" PATH="$path_source:$PATH" CATFOOD_ROOT="$other_workspace" \
    CATFOOD_STATE_HOME="$path_state" \
    sh "$root/android/preserve-shizuku.sh" save >/dev/null
path_id=$(cat "$path_state/shizuku/current")
path_snapshot=$path_state/shizuku/snapshots/$path_id
grep -F "source_dir	$path_source" "$path_snapshot/receipt.tsv" >/dev/null
cmp "$path_source/rish" "$path_snapshot/rish"
cmp "$path_source/rish_shizuku.dex" "$path_snapshot/rish_shizuku.dex"

restore=$temporary/restore
HOME="$home" CATFOOD_ROOT="$workspace" CATFOOD_STATE_HOME="$state" \
    sh "$root/android/preserve-shizuku.sh" restore "$restore" >/dev/null
cmp "$workspace/rish" "$restore/rish"
cmp "$workspace/rish_shizuku.dex" "$restore/rish_shizuku.dex"
test "$(stat -c '%a' "$restore/rish_shizuku.dex")" = 400

empty=$temporary/empty
empty_home=$temporary/empty-home
mkdir -p "$empty" "$empty_home"
HOME="$empty_home" CATFOOD_ROOT="$empty" CATFOOD_STATE_HOME="$temporary/empty-state" \
    sh "$root/android/preserve-shizuku.sh" save > "$temporary/skip.out"
grep -F 'no rish bundle found' "$temporary/skip.out" >/dev/null

partial=$temporary/partial
partial_home=$temporary/partial-home
mkdir -p "$partial" "$partial_home"
printf '%s\n' '#!/system/bin/sh' > "$partial/rish"
if HOME="$partial_home" CATFOOD_ROOT="$empty" CATFOOD_SHIZUKU_RISH_DIR="$partial" \
    CATFOOD_STATE_HOME="$temporary/partial-state" \
    sh "$root/android/preserve-shizuku.sh" save >/dev/null 2>&1; then
    printf '%s\n' 'incomplete Shizuku bundle unexpectedly passed' >&2
    exit 1
fi

printf '%s\n' 'cat food Shizuku state preservation passes'
