#!/bin/sh
set -eu

root_script=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$root_script/.." && pwd)
. "$root_script/grease-package.conf"

CATFOOD_ROOT=${CATFOOD_ROOT:-"$HOME/opt"}
export CATFOOD_ROOT

executor=$repo_root/vendor/ai-ci/host-context/execute.sh
[ -f "$executor" ] || {
    printf 'missing pinned AICI host-context executor: %s\n' "$executor" >&2
    exit 1
}

serial=0
while :; do
    bootstrap_prefix=$HOME/.catfood-sdf-preflight.$$.$serial
    preflight_request=$bootstrap_prefix.request
    preflight_receipt_bootstrap=$bootstrap_prefix.tsv
    if [ ! -e "$preflight_request" ] && [ ! -e "$preflight_receipt_bootstrap" ]; then
        break
    fi
    serial=$((serial + 1))
    [ "$serial" -lt 100 ] || {
        printf '%s\n' 'unable to allocate a new SDF bootstrap receipt name' >&2
        exit 1
    }
done

fetch_request=
cleanup() {
    rm -f "$preflight_request"
    if [ -n "$fetch_request" ]; then
        rm -f "$fetch_request"
    fi
}
trap cleanup EXIT HUP INT TERM

printf '%s\n%s\n' /bin/sh "$root_script/preflight.sh" > "$preflight_request"

ENV= BASH_ENV= /bin/sh "$executor" \
    --request "$preflight_request" \
    --receipt "$preflight_receipt_bootstrap" \
    --expect-os "$GREASE_TARGET_SYSTEM" \
    --expect-arch "$GREASE_TARGET_MACHINE" \
    --expect-release "$GREASE_TARGET_RELEASE"

receipts=$CATFOOD_ROOT/receipts
[ -d "$receipts" ] && [ -w "$receipts" ] || {
    printf 'SDF preflight did not establish writable receipts directory: %s\n' "$receipts" >&2
    exit 1
}

serial=0
while :; do
    prefix=$receipts/sdf-provision.$$.$serial
    preflight_receipt=$prefix.preflight.tsv
    fetch_receipt=$prefix.fetch.tsv
    fetch_request=$prefix.fetch.request
    if [ ! -e "$preflight_receipt" ] && [ ! -e "$fetch_receipt" ] && [ ! -e "$fetch_request" ]; then
        break
    fi
    serial=$((serial + 1))
    [ "$serial" -lt 100 ] || {
        printf '%s\n' 'unable to allocate a new SDF host-context receipt name' >&2
        exit 1
    }
done

mv "$preflight_receipt_bootstrap" "$preflight_receipt"
printf '%s\n%s\n' /bin/sh "$root_script/fetch-grease.sh" > "$fetch_request"

ENV= BASH_ENV= /bin/sh "$executor" \
    --request "$fetch_request" \
    --receipt "$fetch_receipt" \
    --expect-os "$GREASE_TARGET_SYSTEM" \
    --expect-arch "$GREASE_TARGET_MACHINE" \
    --expect-release "$GREASE_TARGET_RELEASE"

trap - EXIT HUP INT TERM
cleanup

printf 'host_context_preflight_receipt=%s\n' "$preflight_receipt"
printf 'host_context_fetch_receipt=%s\n' "$fetch_receipt"
printf 'cat food sdf runtime is current under %s\n' "$CATFOOD_ROOT"
