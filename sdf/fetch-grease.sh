#!/bin/sh
set -eu

root_script=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
. "$root_script/platform.sh"
. "$root_script/grease-package.conf"

catfood_sdf_require_platform

root=${CATFOOD_ROOT:-"$HOME/opt"}
downloads=$root/downloads
receipts=$root/receipts
archive=$downloads/$GREASE_ARCHIVE_NAME
checksum=$archive.sha256
archive_tmp=$archive.tmp.$$
checksum_tmp=$checksum.tmp.$$

cleanup() {
    rm -f "$archive_tmp" "$checksum_tmp"
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

actual=$(catfood_sdf_sha256 "$archive_tmp")
[ "$actual" = "$expected" ] || {
    printf 'Grease SHA-256 mismatch: expected %s, found %s\n' "$expected" "$actual" >&2
    exit 1
}

mv "$checksum_tmp" "$checksum"
mv "$archive_tmp" "$archive"
trap - EXIT HUP INT TERM

CATFOOD_ROOT=$root sh "$root_script/install-grease.sh" "$archive"

receipt=$receipts/grease-netbsd-11-amd64.tsv
{
    printf 'repository_revision\t%s\n' "$GREASE_REPOSITORY_REVISION"
    printf 'release_tag\t%s\n' "$GREASE_RELEASE_TAG"
    printf 'archive\t%s\n' "$archive"
    printf 'sha256\t%s\n' "$actual"
    printf 'source_url\t%s\n' "$url"
} > "$receipt"

printf 'receipt=%s\n' "$receipt"
