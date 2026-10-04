#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
out=${1:-"$root/dist/device-acceptance"}

# Preserve the original exact-artifact assembly, then replace only the pieces
# whose physical phone run exposed an incorrect acceptance boundary.
sh "$root/android/acceptance/build-bundles.sh" "$out"

bundle_ref=$(git -C "$root" rev-parse HEAD)
phone="$out/stage-phone"
tablet="$out/stage-tablet"
cache="$out/cache"

old_cloud_ref=4be1d5a3d603154262f247581dcd76f6a4b317cd
old_cloud_sha=d8f0eee6efbee1125cc227d01448f239c4895a72d254d1a786510aae69a5f97a
old_cloud_url=https://raw.githubusercontent.com/isomorphisms/cloud-storage-api/4be1d5a3d603154262f247581dcd76f6a4b317cd/commands/google-drive-unzip.ysh

cloud_ref=c5b69d7fa0ea7672c9b9bf5dbce5367cee31325f
cloud_sha=a9212ae25d7498ac080ad40e6cadd5b192e596dfdfc726c8f6492ba5c71f780c
cloud_url=https://raw.githubusercontent.com/isomorphisms/cloud-storage-api/c5b69d7fa0ea7672c9b9bf5dbce5367cee31325f/commands/google-drive-unzip.ysh
cloud_file="$cache/google-drive-unzip-current.ysh"

curl -fL --retry 3 --retry-delay 2 "$cloud_url" -o "$cloud_file"
printf '%s  %s\n' "$cloud_sha" "$cloud_file" | sha256sum -c -

for stage in "$phone" "$tablet"; do
    cp "$root/android/acceptance/run-v2.sh" "$stage/run.sh"
    chmod +x "$stage/run.sh"
    cp "$cloud_file" "$stage/payload/google-drive-unzip.ysh"

    sed -i \
        -e "s/$old_cloud_ref/$cloud_ref/g" \
        -e "s/$old_cloud_sha/$cloud_sha/g" \
        -e "s|$old_cloud_url|$cloud_url|g" \
        "$stage/config.sh" "$stage/queue.tsv" "$stage/payloads.tsv"
done

phone_archive="$out/catfood-phone-acceptance-$bundle_ref.tar.gz"
tablet_archive="$out/catfood-tablet-acceptance-$bundle_ref.tar.gz"
rm -f "$phone_archive" "$phone_archive.sha256" "$tablet_archive" "$tablet_archive.sha256"

tar --sort=name --mtime='UTC 2020-01-01' --owner=0 --group=0 --numeric-owner \
    -C "$phone" -czf "$phone_archive" .
tar --sort=name --mtime='UTC 2020-01-01' --owner=0 --group=0 --numeric-owner \
    -C "$tablet" -czf "$tablet_archive" .

(
    cd "$out"
    phone_name=$(basename "$phone_archive")
    tablet_name=$(basename "$tablet_archive")
    sha256sum "$phone_name" > "$phone_name.sha256"
    sha256sum "$tablet_name" > "$tablet_name.sha256"
)

printf 'corrected phone bundle:  %s\n' "$phone_archive"
printf 'corrected tablet bundle: %s\n' "$tablet_archive"
cat "$phone_archive.sha256" "$tablet_archive.sha256"
