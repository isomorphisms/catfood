#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
out=${1:-"$root/dist/device-acceptance"}
cache="$out/cache"
phone="$out/stage-phone"
tablet="$out/stage-tablet"

rm -rf "$out"
mkdir -p "$cache" "$phone/payload/catfood/android" "$tablet/payload/catfood/android"

bundle_ref=$(git -C "$root" rev-parse HEAD)

fetch_checked() {
    url=$1
    digest=$2
    destination=$3
    if [ ! -f "$destination" ]; then
        temporary="$destination.tmp.$$"
        rm -f "$temporary"
        curl -fL --retry 3 --retry-delay 2 "$url" -o "$temporary"
        mv "$temporary" "$destination"
    fi
    printf '%s  %s\n' "$digest" "$destination" | sha256sum -c -
}

GREASE_PHONE_URL=https://github.com/isomorphisms/grease/releases/download/phone-armv7-5ff32e220844/grease-armv7-termux.tar.gz
GREASE_PHONE_SHA=7f2dce33f020a40156a297af38389298d2e4fb9933900379791dadb1e594b61a
GREASE_PHONE_REF=5ff32e2208440ccfe02ee38c17e6626719bcaf87
GREASE_PHONE_SOURCE=9024d14ecd25c8c55cd7e8ea0b901a3a9525565c

GREASE_TABLET_URL=https://github.com/isomorphisms/grease/releases/download/tablet-aarch64-9b3dc8904891/grease-aarch64-termux.tar.gz
GREASE_TABLET_SHA=3ddb962ef313e528e525fa03518f494577e921c2201ecb49f7a11f2fbf4e82b2
GREASE_TABLET_REF=9b3dc89048911bd0e23ee992fe00dcb3cd427f63
GREASE_TABLET_SOURCE=8052868773077602266d80bf39aad6998e2da749

REDDIT_REF=513d3515083edaf723a60292d8d333b7171469cb
REDDIT_PHONE_URL=https://github.com/isomorphisms/idric-arm-thumb/releases/download/reddit-android-513d3515083e/reddit-phone.tar.gz
REDDIT_PHONE_SHA=e731fbd5d34517d4f191b392ef1119e9dd3d556106cb12260e1e895825d46497
REDDIT_TABLET_URL=https://github.com/isomorphisms/idric-arm-thumb/releases/download/reddit-android-513d3515083e/reddit-tablet.tar.gz
REDDIT_TABLET_SHA=3cb14b45cf6a45834bfe94f87bd27c11b007f42b306ffc80d3126f23eb5bdbbd

IKE_REF=80a85b13f4047d7c4be72af2d386f3280468a9d4
IKE_PHONE_URL=https://github.com/dilapidated-shed/ike/releases/download/ike-android-80a85b13f404/ike-phone-armeabi-v7a.tar.gz
IKE_PHONE_SHA=6badcde63409ba79cb5dac1c95bc2a7cae85329cb622f2e7dc720e58b0c74114
IKE_TABLET_URL=https://github.com/dilapidated-shed/ike/releases/download/ike-android-80a85b13f404/ike-tablet-arm64-v8a.tar.gz
IKE_TABLET_SHA=51092a72e9337b7ba138f74980337f4ae4a1ee5256db33aa71e61f97a62e2fdc

CLOUD_STORAGE_REF=4be1d5a3d603154262f247581dcd76f6a4b317cd
CLOUD_STORAGE_URL=https://raw.githubusercontent.com/isomorphisms/cloud-storage-api/4be1d5a3d603154262f247581dcd76f6a4b317cd/commands/google-drive-unzip.ysh
CLOUD_STORAGE_SHA=d8f0eee6efbee1125cc227d01448f239c4895a72d254d1a786510aae69a5f97a

POWERVR_REF=7a2c75f1564dfe82fddee4e975367faf5a3720e4
POWERVR_TABLET_URL=https://github.com/isomorphisms/idris-shader-backend/releases/download/powervr-android-7a2c75f1564d/powervr-runner-tablet-arm64-v8a.tar.gz
POWERVR_TABLET_SHA=4dba2cd39d7a0fc440f8f1c09b379e2712c78411cbd8a648cc411fcfcce54ba7

fetch_checked "$GREASE_PHONE_URL" "$GREASE_PHONE_SHA" "$cache/grease-phone.tar.gz"
fetch_checked "$GREASE_TABLET_URL" "$GREASE_TABLET_SHA" "$cache/grease-tablet.tar.gz"
fetch_checked "$REDDIT_PHONE_URL" "$REDDIT_PHONE_SHA" "$cache/reddit-phone.tar.gz"
fetch_checked "$REDDIT_TABLET_URL" "$REDDIT_TABLET_SHA" "$cache/reddit-tablet.tar.gz"
fetch_checked "$IKE_PHONE_URL" "$IKE_PHONE_SHA" "$cache/ike-phone.tar.gz"
fetch_checked "$IKE_TABLET_URL" "$IKE_TABLET_SHA" "$cache/ike-tablet.tar.gz"
fetch_checked "$CLOUD_STORAGE_URL" "$CLOUD_STORAGE_SHA" "$cache/google-drive-unzip.ysh"
fetch_checked "$POWERVR_TABLET_URL" "$POWERVR_TABLET_SHA" "$cache/powervr-tablet.tar.gz"

stage_common() {
    stage=$1
    cp "$root/android/acceptance/run.sh" "$stage/run.sh"
    cp "$root/android/acceptance/grease-readable-smoke.ysh" "$stage/payload/grease-readable-smoke.ysh"
    cp "$root/android/acceptance/ib-mapped-index.ysh" "$stage/payload/ib-mapped-index.ysh"
    cp "$root/android/install.sh" "$stage/payload/catfood/android/install.sh"
    cp "$root/android/check.sh" "$stage/payload/catfood/android/check.sh"
    cp "$cache/google-drive-unzip.ysh" "$stage/payload/google-drive-unzip.ysh"
    printf '%s\n' "$bundle_ref" > "$stage/bundle-source-commit"
    chmod +x "$stage/run.sh" "$stage/payload/catfood/android/install.sh" "$stage/payload/catfood/android/check.sh"
}

stage_common "$phone"
stage_common "$tablet"

cp "$cache/grease-phone.tar.gz" "$phone/payload/grease-armv7-termux.tar.gz"
cp "$cache/reddit-phone.tar.gz" "$phone/payload/reddit-phone.tar.gz"
cp "$cache/ike-phone.tar.gz" "$phone/payload/ike-phone-armeabi-v7a.tar.gz"
cat > "$phone/config.sh" <<EOF_PHONE
TARGET=phone
EXPECTED_ABI=armeabi-v7a
GREASE_FILE=grease-armv7-termux.tar.gz
GREASE_SHA256=$GREASE_PHONE_SHA
GREASE_REF=$GREASE_PHONE_REF
GREASE_SOURCE_REF=$GREASE_PHONE_SOURCE
GREASE_IB=1
CLOUD_STORAGE_FILE=google-drive-unzip.ysh
CLOUD_STORAGE_SHA256=$CLOUD_STORAGE_SHA
CLOUD_STORAGE_REF=$CLOUD_STORAGE_REF
IKE_FILE=ike-phone-armeabi-v7a.tar.gz
IKE_SHA256=$IKE_PHONE_SHA
IKE_REF=$IKE_REF
REDDIT_FILE=reddit-phone.tar.gz
REDDIT_SHA256=$REDDIT_PHONE_SHA
REDDIT_REF=$REDDIT_REF
POWERVR_ENABLED=0
EOF_PHONE
cat > "$phone/queue.tsv" <<EOF_PHONE_QUEUE
# test\tsource\texact_ref\tevidence
catfood_legacy_migration\tisomorphisms/catfood#46\t$bundle_ref\tphysical-device installer behavior in isolated prefix
grease_readable_syntax\tisomorphisms/grease#12\t$GREASE_PHONE_REF\tphysical ARMv7 runtime
grease_ib_mapped_index\tisomorphisms/grease#12\t$GREASE_PHONE_REF\tphysical ARMv7 Grease native mmap/openat/msync path
cloud_storage_help\tisomorphisms/cloud-storage-api\t$CLOUD_STORAGE_REF\tcredential-free physical runtime parse/launch
ike_runtime\tdilapidated-shed/ike\t$IKE_REF\tphysical ARMv7 parser/dependency/recipe shell boundary
reddit_direct_dex_jni\tisomorphisms/idric-arm-thumb\t$REDDIT_REF\tphysical ARMv7 direct DEX/JNI execution
EOF_PHONE_QUEUE
cat > "$phone/payloads.tsv" <<EOF_PHONE_PAYLOADS
# file\tsource\texact_ref\tsha256\tupstream_url
grease-armv7-termux.tar.gz\tisomorphisms/grease\t$GREASE_PHONE_REF\t$GREASE_PHONE_SHA\t$GREASE_PHONE_URL
reddit-phone.tar.gz\tisomorphisms/idric-arm-thumb\t$REDDIT_REF\t$REDDIT_PHONE_SHA\t$REDDIT_PHONE_URL
ike-phone-armeabi-v7a.tar.gz\tdilapidated-shed/ike\t$IKE_REF\t$IKE_PHONE_SHA\t$IKE_PHONE_URL
google-drive-unzip.ysh\tisomorphisms/cloud-storage-api\t$CLOUD_STORAGE_REF\t$CLOUD_STORAGE_SHA\t$CLOUD_STORAGE_URL
EOF_PHONE_PAYLOADS

cp "$cache/grease-tablet.tar.gz" "$tablet/payload/grease-aarch64-termux.tar.gz"
cp "$cache/reddit-tablet.tar.gz" "$tablet/payload/reddit-tablet.tar.gz"
cp "$cache/ike-tablet.tar.gz" "$tablet/payload/ike-tablet-arm64-v8a.tar.gz"
cp "$cache/powervr-tablet.tar.gz" "$tablet/payload/powervr-runner-tablet-arm64-v8a.tar.gz"
cat > "$tablet/config.sh" <<EOF_TABLET
TARGET=tablet
EXPECTED_ABI=arm64-v8a
GREASE_FILE=grease-aarch64-termux.tar.gz
GREASE_SHA256=$GREASE_TABLET_SHA
GREASE_REF=$GREASE_TABLET_REF
GREASE_SOURCE_REF=$GREASE_TABLET_SOURCE
GREASE_IB=0
CLOUD_STORAGE_FILE=google-drive-unzip.ysh
CLOUD_STORAGE_SHA256=$CLOUD_STORAGE_SHA
CLOUD_STORAGE_REF=$CLOUD_STORAGE_REF
IKE_FILE=ike-tablet-arm64-v8a.tar.gz
IKE_SHA256=$IKE_TABLET_SHA
IKE_REF=$IKE_REF
REDDIT_FILE=reddit-tablet.tar.gz
REDDIT_SHA256=$REDDIT_TABLET_SHA
REDDIT_REF=$REDDIT_REF
POWERVR_ENABLED=1
POWERVR_FILE=powervr-runner-tablet-arm64-v8a.tar.gz
POWERVR_SHA256=$POWERVR_TABLET_SHA
POWERVR_REF=$POWERVR_REF
EOF_TABLET
cat > "$tablet/queue.tsv" <<EOF_TABLET_QUEUE
# test\tsource\texact_ref\tevidence
catfood_legacy_migration\tisomorphisms/catfood#46\t$bundle_ref\tphysical-device installer behavior in isolated prefix
grease_readable_syntax\tisomorphisms/grease#14\t$GREASE_TABLET_REF\tphysical AArch64 runtime
cloud_storage_help\tisomorphisms/cloud-storage-api\t$CLOUD_STORAGE_REF\tcredential-free physical runtime parse/launch
ike_runtime\tdilapidated-shed/ike\t$IKE_REF\tphysical AArch64 parser/dependency/recipe shell boundary
reddit_direct_dex_jni\tisomorphisms/idric-arm-thumb\t$REDDIT_REF\tphysical AArch64 direct DEX/JNI execution
powervr_vendor_driver\tisomorphisms/idris-shader-backend\t$POWERVR_REF\tphysical tablet vendor EGL/GLES execution only
EOF_TABLET_QUEUE
cat > "$tablet/payloads.tsv" <<EOF_TABLET_PAYLOADS
# file\tsource\texact_ref\tsha256\tupstream_url
grease-aarch64-termux.tar.gz\tisomorphisms/grease\t$GREASE_TABLET_REF\t$GREASE_TABLET_SHA\t$GREASE_TABLET_URL
reddit-tablet.tar.gz\tisomorphisms/idric-arm-thumb\t$REDDIT_REF\t$REDDIT_TABLET_SHA\t$REDDIT_TABLET_URL
ike-tablet-arm64-v8a.tar.gz\tdilapidated-shed/ike\t$IKE_REF\t$IKE_TABLET_SHA\t$IKE_TABLET_URL
google-drive-unzip.ysh\tisomorphisms/cloud-storage-api\t$CLOUD_STORAGE_REF\t$CLOUD_STORAGE_SHA\t$CLOUD_STORAGE_URL
powervr-runner-tablet-arm64-v8a.tar.gz\tisomorphisms/idris-shader-backend\t$POWERVR_REF\t$POWERVR_TABLET_SHA\t$POWERVR_TABLET_URL
EOF_TABLET_PAYLOADS

phone_archive="$out/catfood-phone-acceptance-$bundle_ref.tar.gz"
tablet_archive="$out/catfood-tablet-acceptance-$bundle_ref.tar.gz"

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

printf 'phone bundle:  %s\n' "$phone_archive"
printf 'tablet bundle: %s\n' "$tablet_archive"
cat "$phone_archive.sha256" "$tablet_archive.sha256"
