#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$root/android/target.sh"
. "$root/android/content.sh"

workspace=${CATFOOD_ROOT:-"$HOME/opt"}
receipt=${CATFOOD_C67_RUNTIME_RECEIPT:-"$workspace/receipts/c67-runtime.tsv"}

catfood_android_require_device c67
device_id=$(catfood_android_device_id)

abi=$(catfood_android_getprop ro.product.cpu.abi || :)
model=$(catfood_android_getprop ro.product.model || :)
product=$(catfood_android_getprop ro.product.device || :)
fingerprint=$(catfood_android_getprop ro.build.fingerprint || :)
[ -n "$fingerprint" ] && [ "$fingerprint" != - ] || { printf '%s\n' 'runtime observation requires a nonempty firmware fingerprint' >&2; exit 2; }
sdk=$(catfood_android_getprop ro.build.version.sdk || :)
machine=$(uname -m 2>/dev/null || printf '%s\n' unknown)

[ "$abi" = arm64-v8a ] || {
    printf 'MIRO C67 runtime receipt requires arm64-v8a; found %s\n' "${abi:-unknown}" >&2
    exit 2
}
[ "$machine" = aarch64 ] || [ "$machine" = arm64 ] || {
    printf 'MIRO C67 runtime receipt requires AArch64 kernel userspace; found %s\n' "$machine" >&2
    exit 2
}

page_size=
if command -v getconf >/dev/null 2>&1; then
    page_size=$(getconf PAGESIZE 2>/dev/null || :)
fi
if [ -z "$page_size" ] && [ -r /proc/self/smaps ]; then
    page_kb=$(awk '/^KernelPageSize:/ { print $2; exit }' /proc/self/smaps 2>/dev/null || :)
    case $page_kb in
        ''|*[!0-9]*) ;;
        *) page_size=$((page_kb * 1024)) ;;
    esac
fi
case $page_size in
    ''|*[!0-9]*)
        printf '%s\n' 'MIRO C67 runtime receipt could not determine runtime page size' >&2
        exit 3
        ;;
esac

native_probe=$workspace/bin/jq
[ -x "$native_probe" ] || {
    printf 'MIRO C67 native probe is missing: %s\n' "$native_probe" >&2
    exit 3
}
binary_manifest=${CATFOOD_BINARY_MANIFEST:-"$root/runtime-binaries.tsv"}
probe_sha256=$(awk -F '\t' '$1 == "jq" && $4 == "linux-aarch64" && $5 == "file" {print $7; found++} END {if (found != 1) exit 1}' "$binary_manifest")
if command -v sha256sum >/dev/null 2>&1; then
    printf '%s  %s\n' "$probe_sha256" "$native_probe" | sha256sum -c - >/dev/null
else
    printf '%s  %s\n' "$probe_sha256" "$native_probe" | /system/bin/toybox sha256sum -c - >/dev/null
fi
probe_output=$("$native_probe" --version 2>&1) || {
    printf '%s\n' 'MIRO C67 arm64 native jq probe failed' >&2
    exit 3
}
case $probe_output in
    jq-*) ;;
    *)
        printf 'MIRO C67 native jq probe returned unexpected output: %s\n' "$probe_output" >&2
        exit 3
        ;;
esac

binary_receipt=$workspace/receipts/runtime-binary-linux-aarch64-jq.tsv
[ -f "$binary_receipt" ] || {
    printf 'MIRO C67 native probe receipt is missing: %s\n' "$binary_receipt" >&2
    exit 3
}
awk -F '\t' 'NF!=2 || seen[$1]++ {exit 1}' "$binary_receipt" || {
    printf '%s\n' 'ambiguous native probe receipt' >&2; exit 3;
}
grep -Fqx 'platform	linux-aarch64' "$binary_receipt" || {
    printf '%s\n' 'MIRO C67 jq receipt is not the pinned linux-aarch64 asset' >&2
    exit 3
}
grep -Fqx 'runtime_probe_result	PASS' "$binary_receipt" || {
    printf '%s\n' 'MIRO C67 jq receipt does not contain a passing runtime probe' >&2
    exit 3
}

# Mutable facts and exact probe bytes are observed again after execution.
[ "$(cf_hash "$native_probe")" = "$probe_sha256" ] &&
[ "$(catfood_android_getprop ro.build.fingerprint)" = "$fingerprint" ] &&
[ "$(catfood_android_getprop ro.product.model)" = "$model" ] &&
[ "$(catfood_android_getprop ro.product.device)" = "$product" ] &&
[ "$(catfood_android_getprop ro.product.cpu.abi)" = "$abi" ] || {
    printf '%s\n' 'runtime bytes or device facts changed during execution' >&2; exit 3;
}

mkdir -p "$(dirname -- "$receipt")"
{
    printf 'schema\tcatfood-c67-runtime-v1\n'
    printf 'target\tc67\n'
    printf 'package_lane\tarm64-v8a\n'
    printf 'device_id\t%s\n' "$device_id"
    printf 'product_device\t%s\n' "$product"
    printf 'model\t%s\n' "$model"
    printf 'fingerprint\t%s\n' "$fingerprint"
    printf 'sdk\t%s\n' "$sdk"
    printf 'abi\t%s\n' "$abi"
    printf 'kernel_machine\t%s\n' "$machine"
    printf 'page_size_bytes\t%s\n' "$page_size"
    printf 'native_probe\t%s\n' "$native_probe"
    printf 'native_probe_sha256\t%s\n' "$probe_sha256"
    printf 'native_probe_output\t%s\n' "$probe_output"
    printf 'native_probe_receipt\t%s\n' "$binary_receipt"
    printf 'native_probe_result\tPASS\n'
    printf 'procedure_sha256\t%s\n' "$(cf_hash "$0")"
    printf 'binary_manifest_sha256\t%s\n' "$(cf_hash "$binary_manifest")"
    printf 'native_probe_receipt_sha256\t%s\n' "$(cf_hash "$binary_receipt")"
    printf 'scope\t%s\n' "$(if [ -n "${CATFOOD_GETPROP:-}${CATFOOD_BINARY_MANIFEST:-}" ] || [ ! -x /system/bin/getprop ]; then printf synthetic; else printf physical-observation; fi)"
    printf 'acceptance_authorization\tNOT_VERIFIED\n'
} > "$receipt.tmp.$$"
if [ -f "$receipt" ]; then
    mkdir -p "$(dirname -- "$receipt")/history"
    cp "$receipt" "$(dirname -- "$receipt")/history/$(basename -- "$receipt").$(cf_hash "$receipt")"
fi
mv "$receipt.tmp.$$" "$receipt"

printf 'Cat Food C67 runtime receipt: %s\n' "$receipt"
