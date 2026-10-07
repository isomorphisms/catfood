#!/bin/sh
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
cp "$root/tests/android-properties.sh" "$tmp/getprop"
chmod +x "$tmp/getprop"
export CATFOOD_GETPROP="$tmp/getprop"
export CATFOOD_DEVICE_ID=synthetic-target-cli
for target in phone c67 tablet; do
    export CATFOOD_TARGET="$target"
    test "$(sh "$root/android/target.sh" device-id "$target")" = synthetic-target-cli
    case "$target" in phone) abi=armeabi-v7a ;; *) abi=arm64-v8a ;; esac
    test "$(sh "$root/android/target.sh" expected-abi "$target")" = "$abi"
done
export CATFOOD_TARGET=c67
for other in phone tablet termux cloud container; do
    if sh "$root/android/target.sh" device-id "$other" >/dev/null 2>&1; then
        printf 'identity CLI accepted C67 as %s\n' "$other" >&2; exit 1
    fi
done
if CATFOOD_TEST_MODEL=TAB_P10 sh "$root/android/target.sh" device-id c67 >/dev/null 2>&1; then
    printf '%s\n' 'identity CLI accepted contradictory model and product' >&2; exit 1
fi
if sh "$root/android/target.sh" unknown c67 >/dev/null 2>&1; then exit 1; fi
printf '%s\n' 'Cat Food target command boundary PASS; all device properties are synthetic'
