#!/bin/sh
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)
work=$(mktemp -d)
trap 'rm -rf "$work"' 0
trap 'exit 130' INT
trap 'exit 143' HUP TERM
export HOME="$work/home" CATFOOD_ROOT="$work/workbench"
export CATFOOD_TARGET=phone CATFOOD_CHECKOUTS="$work/state/checkouts.tsv"
export CATFOOD_MANIFEST="$work/tools.tsv" GIT_CONFIG_NOSYSTEM=1
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
mkdir -p "$HOME" "$work/outside"
printf '%s\n' 'ib https://github.com/isomorphisms/ib.git main recursive' > "$CATFOOD_MANIFEST"
count=0
passed() { count=$((count + 1)); printf 'ok %s - %s\n' "$count" "$1"; }
run() { (cd "$work/outside" && sh "$root/catfood" "$@"); }
if run where ib > "$work/output" 2> "$work/error"; then exit 1; fi
test ! -s "$work/output"
test ! -e "$CATFOOD_ROOT"
test ! -e "$CATFOOD_CHECKOUTS"
passed 'phone without a source checkout is not provisioned or cloned'
repo="$work/acceptance checkout"
git init -q "$repo"
git -C "$repo" remote add origin https://github.com/isomorphisms/ib.git
run register ib acceptance "$repo" > "$work/first"
cp "$CATFOOD_CHECKOUTS" "$work/first-inventory"
run register ib acceptance "$repo" > "$work/second"
cmp "$work/first" "$work/second"
cmp "$work/first-inventory" "$CATFOOD_CHECKOUTS"
passed 'repeated registration is idempotent'
run where ib > "$work/located"
printf 'ib\tacceptance\t%s\n' "$repo" > "$work/expected"
cmp "$work/expected" "$work/located"
passed 'registered path with spaces resolves outside Git'
printf 'preserve me\n' > "$repo/untracked"
run where ib > /dev/null
test "$(cat "$repo/untracked")" = 'preserve me'
passed 'lookup preserves existing files'
git -C "$repo" remote set-url origin https://github.com/unrelated/ib.git
if run where ib > "$work/output" 2> "$work/error"; then exit 1; fi
test ! -s "$work/output"
if run register ib acceptance "$repo" > "$work/output" 2> "$work/error"; then exit 1; fi
cmp "$work/first-inventory" "$CATFOOD_CHECKOUTS"
passed 'wrong origin is neither reported nor registered'
git -C "$repo" remote set-url origin https://github.com/isomorphisms/ib.git
mv "$repo" "$work/moved-checkout"
if run where ib > "$work/output" 2> "$work/error"; then exit 1; fi
test ! -e "$repo"
passed 'stale registry entry is not recreated'
mv "$work/moved-checkout" "$repo"
git init -q "$work/second-checkout"
git -C "$work/second-checkout" remote add origin git@github.com:isomorphisms/ib.git
run register ib test "$work/second-checkout" > /dev/null
run where ib > "$work/located"
test "$(wc -l < "$work/located" | tr -d ' ')" = 2
passed 'multiple checkouts remain explicit, not silently selected'
run help ib > "$work/help"
cmp "$root/docs/help/ib.md" "$work/help"
grep -F 'e2=NOT_RUN' "$work/help" > /dev/null
passed 'actual Cat Food help exposes the bounded Kitchen handoff'
report=$root/docs/observations/miro-a1-ib-baseline-2026-10-04.tsv
awk -F '\t' '$1 == "evidence_kind" && $2 == "user-pasted-terminal-transcript" { a=1 } $1 == "baseline" && $2 == "PASS_REPORTED" { b=1 } $1 == "e2_acceptance" && $2 == "BLOCKED" { c=1 } $1 == "new_kitchen_runner_on_phone" && $2 == "NOT_RUN" { d=1 } END { exit !(a && b && c && d) }' "$report"
passed 'reported baseline cannot masquerade as repair or new phone acceptance'
printf 'catfood IB handoff cases: %s passed\n' "$count"
