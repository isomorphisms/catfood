#!/bin/sh
# Stage-zero installer test: synthetic identities, real published bytes.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
tab=$(printf '\t')
ref=0e6ba10f8edde26e940685ac386ad4279afbe259
mkdir -p "$tmp/bin"
cp "$root/tests/android-properties.sh" "$tmp/bin/getprop"
chmod +x "$tmp/bin/getprop"
export CATFOOD_GETPROP="$tmp/bin/getprop"
export CATFOOD_TOOLS="$tmp/tools.tsv" CATFOOD_ANDROID_DELIVERY="$tmp/delivery.tsv" CATFOOD_ANDROID_PACKAGES="$tmp/packages.tsv"
printf '%s\n' 'ish https://github.com/dilapidated-shed/grease.git ish none' > "$CATFOOD_TOOLS"
printf '%s\n' 'grease	reference	n/a	n/a	fixture' 'ish	runtime	package:ish-armeabi-v7a	package:ish-arm64-v8a	fixture' > "$CATFOOD_ANDROID_DELIVERY"
awk -F '\t' 'NR == 1 || $1 ~ /^ish-/ {print}' "$root/android/packages.tsv" > "$CATFOOD_ANDROID_PACKAGES"
test "$(awk -F '\t' '$1 ~ /^ish-/ {n++} END {print n+0}' "$CATFOOD_ANDROID_PACKAGES")" -eq 2

check_payload() {
    dir=$1
    abi=$2
    class=$3
    machine=$4
    test -x "$dir/bin/ish" || return 1
    test ! -L "$dir/bin/ish" || return 1
    for alias in grease ysh osh oils-for-unix; do test ! -e "$dir/bin/$alias" || return 1; done
    grep -Fqx "source_sha${tab}$ref" "$dir/receipts/build.tsv" || return 1
    grep -Fqx "abi${tab}$abi" "$dir/receipts/build.tsv" || return 1
    grep -Fqx "physical_device_execution${tab}PENDING" "$dir/receipts/build.tsv" || return 1
    test "$(wc -l < "$dir/receipts/files.sha256")" -eq 6 || return 1
    while read -r digest path; do
        relative=${path#*/build/package/}
        test "$relative" != "$path" || return 1
        case "$relative" in bin/ish|libexec/ish/scheme|libexec/ish/petite.boot|libexec/ish/scheme.boot|libexec/ish/ish-backend.so|libexec/ish/libish_runtime.so) ;; *) exit 1 ;; esac
        printf '%s  %s\n' "$digest" "$dir/$relative" | sha256sum -c - >/dev/null || return 1
    done < "$dir/receipts/files.sha256"
    # Chez's compiled Scheme .so is not an ELF; inspect native ELF components.
    for native in bin/ish libexec/ish/scheme libexec/ish/libish_runtime.so; do
        readelf -h "$dir/$native" > "$tmp/header" || return 1
        grep -Eq "Class: +$class$" "$tmp/header" || return 1
        grep -Eq "Machine: +$machine$" "$tmp/header" || return 1
        readelf -S "$dir/$native" > "$tmp/sections" || return 1
        if grep -Eq '\.(symtab|debug_)' "$tmp/sections"; then
            printf 'unstripped Ish payload: %s\n' "$native" >&2
            return 1
        fi
    done
}

install_target() {
    target=$1
    abi=$2
    class=$3
    machine=$4
    export CATFOOD_TARGET="$target" CATFOOD_DEVICE_ID="synthetic-ish-$target"
    export CATFOOD_ROOT="$tmp/work-$target" CATFOOD_CACHE="$tmp/cache-$target"
    sh "$root/android/install.sh" > "$tmp/install-$target.log"
    package=ish-$abi
    receipt="$CATFOOD_ROOT/receipts/$target-$package.tsv"
    sh "$root/android/check.sh" receipt "$receipt" "$target" "$CATFOOD_DEVICE_ID" >/dev/null
    for stage in build launch runtime emulator physical_device; do
        grep -Fqx "${stage}_result${tab}NOT_VERIFIED" "$receipt"
    done
    for stage in package publication installation; do
        grep -Fqx "${stage}_result${tab}PASS" "$receipt"
    done
    check_payload "$CATFOOD_ROOT/packages/$package/$ref" "$abi" "$class" "$machine"
    # Validate reuse without converting an install receipt into runtime evidence.
    sh "$root/android/install.sh" > "$tmp/reinstall-$target.log"
    grep -Fq 'current' "$tmp/reinstall-$target.log"
    grep -Fqx "physical_device_result${tab}NOT_VERIFIED" "$receipt"
    if sh "$root/android/check.sh" receipt "$receipt" "$target" another-instance >/dev/null 2>&1; then
        printf '%s\n' 'Ish receipt accepted another physical instance' >&2; exit 1
    fi
}

install_target phone armeabi-v7a ELF32 ARM
install_target c67 arm64-v8a ELF64 AArch64
install_target tablet arm64-v8a ELF64 AArch64
c67="$tmp/work-c67/receipts/c67-ish-arm64-v8a.tsv"
tablet="$tmp/work-tablet/receipts/tablet-ish-arm64-v8a.tsv"
test "$(awk -F '\t' '$1=="sha256" {print $2}' "$c67")" = "$(awk -F '\t' '$1=="sha256" {print $2}' "$tablet")"
for pair in "$c67 tablet" "$tablet c67"; do
    set -- $pair
    if sh "$root/android/check.sh" receipt "$1" "$2" >/dev/null 2>&1; then
        printf '%s\n' 'Ish shared ABI artifact accepted the wrong physical target' >&2; exit 1
    fi
done
# Mutate real payload bytes; the packaged content receipt must reject them.
cp -R "$tmp/work-c67/packages/ish-arm64-v8a/$ref" "$tmp/corrupt"
printf corruption >> "$tmp/corrupt/bin/ish"
if (check_payload "$tmp/corrupt" arm64-v8a ELF64 AArch64) >/dev/null 2>&1; then
    printf '%s\n' 'Ish package check accepted modified executable bytes' >&2; exit 1
fi
if check_payload "$tmp/work-c67/packages/ish-arm64-v8a/$ref" armeabi-v7a ELF32 ARM >/dev/null 2>&1; then
    printf '%s\n' 'Ish package check accepted an ARM64 artifact as ARM32' >&2; exit 1
fi
cp -R "$tmp/work-c67/packages/ish-arm64-v8a/$ref" "$tmp/alias"
ln -s ish "$tmp/alias/bin/grease"
if check_payload "$tmp/alias" arm64-v8a ELF64 AArch64 >/dev/null 2>&1; then
    printf '%s\n' 'Ish package check accepted a Grease alias' >&2; exit 1
fi
printf '%s\n' 'Published paired Ish archives: digest, payload, stripped ABI, install, reuse and negative receipt checks PASS; no Android execution claimed'
