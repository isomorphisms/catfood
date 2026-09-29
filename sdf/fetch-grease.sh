#!/bin/sh
set -eu

root_script=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
. "$root_script/platform.sh"
. "$root_script/grease-package.conf"

CATFOOD_SDF_EXPECT_RELEASE=$GREASE_TARGET_RELEASE
export CATFOOD_SDF_EXPECT_RELEASE
catfood_sdf_require_platform

root=${CATFOOD_ROOT:-"$HOME/opt"}
downloads=$root/downloads
receipts=$root/receipts
archive=$downloads/$GREASE_ARCHIVE_NAME
checksum=$archive.sha256
archive_tmp=$archive.tmp.$
checksum_tmp=$checksum.tmp.$
receipt=$receipts/grease-netbsd-9.3-amd64-$GREASE_REPOSITORY_REVISION.tsv
receipt_tmp=$receipt.tmp.$

cleanup() {
    rm -f "$archive_tmp" "$checksum_tmp" "$receipt_tmp"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$downloads" "$receipts"

url=${CATFOOD_GREASE_URL:-$GREASE_URL}
sha256_url=${CATFOOD_GREASE_SHA256_URL:-$GREASE_SHA256_URL}

catfood_sdf_download "$sha256_url" "$checksum_tmp"
catfood_sdf_download "$url" "$archive_tmp"

expected=$(awk 'NF { print $1; exit }' "$checksum_tmp")
case $expected in
    ''|*[!0123456789abcdefABCDEF]*)
        printf 'invalid Grease SHA-256 file from %s\n' "$sha256_url" >&2
        exit 1
        ;;
esac
[ "${#expected}" -eq 64 ] || {
    printf 'invalid Grease SHA-256 length from %s\n' "$sha256_url" >&2
    exit 1
}
[ "$expected" = "$GREASE_SHA256" ] || {
    printf 'Grease release checksum differs from Cat Food pin: pinned %s, release says %s\n' "$GREASE_SHA256" "$expected" >&2
    exit 1
}

actual=$(catfood_sdf_sha256 "$archive_tmp")
[ "$actual" = "$GREASE_SHA256" ] || {
    printf 'Grease SHA-256 mismatch: pinned %s, found %s\n' "$GREASE_SHA256" "$actual" >&2
    exit 1
}

mv "$checksum_tmp" "$checksum"
mv "$archive_tmp" "$archive"
trap - EXIT HUP INT TERM

CATFOOD_ROOT=$root sh "$root_script/install-grease.sh" "$archive"

{
    printf 'repository_revision\t%s\n' "$GREASE_REPOSITORY_REVISION"
    printf 'release_tag\t%s\n' "$GREASE_RELEASE_TAG"
    printf 'archive\t%s\n' "$archive"
    printf 'sha256\t%s\n' "$actual"
    printf 'pinned_sha256\t%s\n' "$GREASE_SHA256"
    printf 'source_url\t%s\n' "$url"
} > "$receipt_tmp"
mv "$receipt_tmp" "$receipt"

printf 'receipt=%s\n' "$receipt"
