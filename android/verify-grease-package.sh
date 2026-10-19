#!/bin/sh
# Stage zero: verify published payload bytes before any runtime invocation.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
[ "$#" = 2 ] || exit 2
directory=$1
package=$2
fail() { printf 'Cat Food Grease package: %s\n' "$*" >&2; exit 3; }
tab=$(printf '\t')
row=$(awk -F '\t' -v p="$package" '$1==p && $10=="grease" {print; n++} END {if(n!=1)exit 1}' "$root/android/packages.tsv") || fail 'missing unique package declaration'
IFS="$tab" read -r name lane abi mode source source_ref package_ref rest <<EOF
$row
EOF
case $abi in armeabi-v7a) elf_class=1; machine='40 0';; arm64-v8a) elf_class=2; machine='183 0';; *) fail 'unsupported ABI';; esac
for member in bin/grease bin/ysh receipts/build.tsv; do
    [ -f "$directory/$member" ] && [ ! -L "$directory/$member" ] || fail "missing or redirected payload: $member"
done
magic=$(od -An -tu1 -N6 "$directory/bin/ysh" | xargs)
[ "$magic" = "127 69 76 70 $elf_class 1" ] || fail 'wrong ELF class or byte order'
observed_machine=$(od -An -tu1 -j18 -N2 "$directory/bin/ysh" | xargs)
[ "$observed_machine" = "$machine" ] || fail 'wrong ELF ABI'
payload=$(awk -F '\t' -v p="$package" '$1==p {print; n++} END{if(n!=1)exit 1}' "$root/android/grease-payloads.tsv") || fail 'missing payload digest declaration'
IFS="$tab" read -r name engine_digest launcher_digest metadata_digest <<EOF
$payload
EOF
verify() {
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s  %s\n' "$1" "$2" | sha256sum -c - >/dev/null
    else
        printf '%s  %s\n' "$1" "$2" | /system/bin/toybox sha256sum -c - >/dev/null
    fi
}
verify "$engine_digest" "$directory/bin/ysh" || fail 'corrupt native engine'
verify "$launcher_digest" "$directory/bin/grease" || fail 'stale or corrupt launcher'
verify "$metadata_digest" "$directory/receipts/build.tsv" || fail 'corrupt packaging receipt'
for pair in "source_sha${tab}$source_ref" "packaging_sha${tab}$package_ref" "abi${tab}$abi"; do
    grep -Fx "$pair" "$directory/receipts/build.tsv" >/dev/null || fail 'package/source/ABI mismatch'
done
printf 'PASS verified native Grease package %s\n' "$package"
