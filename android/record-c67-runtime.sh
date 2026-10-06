#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$root/android/target.sh"

workspace=${CATFOOD_ROOT:-"$HOME/opt"}
receipt=${CATFOOD_C67_RUNTIME_RECEIPT:-"$workspace/receipts/c67-runtime.tsv"}

catfood_android_verify_device_target c67

abi=$(catfood_android_getprop ro.product.cpu.abi || :)
model=$(catfood_android_getprop ro.product.model || :)
product=$(catfood_android_getprop ro.product.device || :)
fingerprint=$(catfood_android_getprop ro.build.fingerprint || :)
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
grep -Fqx 'platform	linux-aarch64' "$binary_receipt" || {
    printf '%s\n' 'MIRO C67 jq receipt is not the pinned linux-aarch64 asset' >&2
    exit 3
}
grep -Fqx 'runtime_probe_result	PASS' "$binary_receipt" || {
    printf '%s\n' 'MIRO C67 jq receipt does not contain a passing runtime probe' >&2
    exit 3
}

mkdir -p "$(dirname -- "$receipt")"
{
    printf 'schema\tcatfood-c67-runtime-v1\n'
    printf 'target\tc67\n'
    printf 'delivery_target\ttablet\n'
    printf 'product_device\t%s\n' "$product"
    printf 'model\t%s\n' "$model"
    printf 'fingerprint\t%s\n' "$fingerprint"
    printf 'sdk\t%s\n' "$sdk"
    printf 'abi\t%s\n' "$abi"
    printf 'kernel_machine\t%s\n' "$machine"
    printf 'page_size_bytes\t%s\n' "$page_size"
    printf 'native_probe\t%s\n' "$native_probe"
    printf 'native_probe_output\t%s\n' "$probe_output"
    printf 'native_probe_receipt\t%s\n' "$binary_receipt"
    printf 'native_probe_result\tPASS\n'
} > "$receipt.tmp.$$"
mv "$receipt.tmp.$$" "$receipt"

printf 'Cat Food C67 runtime receipt: %s\n' "$receipt"
