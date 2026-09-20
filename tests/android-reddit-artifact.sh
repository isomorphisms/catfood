#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
tab=$(printf '\t')

tools="$tmp/tools.tsv"
delivery="$tmp/delivery.tsv"
packages="$tmp/packages.tsv"
fake_bin="$tmp/bin"
mkdir -p "$fake_bin"

cat > "$tools" <<'EOF_TOOLS'
reddit https://github.com/isomorphisms/idric-arm-thumb.git main none
EOF_TOOLS

cat > "$delivery" <<'EOF_DELIVERY'
# name	role	phone	tablet	note
grease	reference	n/a	n/a	fixture-not-under-test
reddit	runtime	package:reddit-phone	package:reddit-tablet	exact-published-artifact-test
EOF_DELIVERY

{
    sed -n '1p' "$root/android/packages.tsv"
    awk -F '\t' '$1 == "reddit-phone" || $1 == "reddit-tablet" { print }' "$root/android/packages.tsv"
} > "$packages"

test "$(awk -F '\t' '$1 == "reddit-phone" { count++ } END { print count+0 }' "$packages")" -eq 1
test "$(awk -F '\t' '$1 == "reddit-tablet" { count++ } END { print count+0 }' "$packages")" -eq 1

checksums_url=https://github.com/isomorphisms/idric-arm-thumb/releases/download/reddit-android-45b8b5e1e391/SHA256SUMS
checksums="$tmp/SHA256SUMS"
curl -fL --retry 2 "$checksums_url" -o "$checksums"
printf '%s  %s\n' \
    a5a2f1dd8496924821ae647afaf7be4b92af741ce96454540f8af0c136f1ffa5 \
    "$checksums" | sha256sum -c -
grep -Fqx '063fd4dcc04409c09caef34d2295d93361e2ba441d87dac8476f81d71530662c  reddit-phone.tar.gz' "$checksums"
grep -Fqx '4bcd1e3a95342f58e6ba399455110476104d88507c9b3b2bfc856f39478f84e9  reddit-tablet.tar.gz' "$checksums"

cat > "$fake_bin/app_process" <<'EOF_APP_PROCESS'
#!/bin/sh
printf '%s\n' 'artifact-contract test must not execute app_process' >&2
exit 99
EOF_APP_PROCESS
chmod +x "$fake_bin/app_process"

check_target() {
    target=$1
    abi=$2
    package=$3
    expected_sha=$4
    expected_url=$5

    workspace="$tmp/workspace-$target"
    cache="$tmp/cache-$target"
    mkdir -p "$workspace" "$cache"

    CATFOOD_TARGET="$target" \
    CATFOOD_DEVICE_ABI="$abi" \
    CATFOOD_ROOT="$workspace" \
    CATFOOD_CACHE="$cache" \
    CATFOOD_TOOLS="$tools" \
    CATFOOD_ANDROID_DELIVERY="$delivery" \
    CATFOOD_ANDROID_PACKAGES="$packages" \
    CATFOOD_APP_PROCESS="$fake_bin/app_process" \
        sh "$root/android/install.sh"

    receipt="$workspace/receipts/$target-$package.tsv"
    CATFOOD_TOOLS="$tools" \
    CATFOOD_ANDROID_DELIVERY="$delivery" \
    CATFOOD_ANDROID_PACKAGES="$packages" \
        sh "$root/android/check.sh" receipt "$receipt" >/dev/null

    grep -Fqx "sha256${tab}$expected_sha" "$receipt"
    grep -Fqx "url${tab}$expected_url" "$receipt"
    grep -Fqx "package_result${tab}PASS" "$receipt"
    grep -Fqx "publication_result${tab}PASS" "$receipt"
    grep -Fqx "installation_result${tab}PASS" "$receipt"
    grep -Fqx "launch_result${tab}NOT_VERIFIED" "$receipt"
    grep -Fqx "runtime_result${tab}NOT_VERIFIED" "$receipt"
    grep -Fqx "emulator_result${tab}NOT_VERIFIED" "$receipt"
    grep -Fqx "physical_device_result${tab}NOT_VERIFIED" "$receipt"

    package_ref=45b8b5e1e3919816f8818602784acefc7f3b7ca6
    package_dir="$workspace/packages/$package/$package_ref"
    test "$(stat -c '%a' "$package_dir/classes.dex")" = 444
    test "$(stat -c '%a' "$package_dir/libreddit_cli.so")" = 444
    test -x "$workspace/bin/reddit"
}

check_target \
    phone \
    armeabi-v7a \
    reddit-phone \
    063fd4dcc04409c09caef34d2295d93361e2ba441d87dac8476f81d71530662c \
    https://github.com/isomorphisms/idric-arm-thumb/releases/download/reddit-android-45b8b5e1e391/reddit-phone.tar.gz

check_target \
    tablet \
    arm64-v8a \
    reddit-tablet \
    4bcd1e3a95342f58e6ba399455110476104d88507c9b3b2bfc856f39478f84e9 \
    https://github.com/isomorphisms/idric-arm-thumb/releases/download/reddit-android-45b8b5e1e391/reddit-tablet.tar.gz

printf '%s\n' 'exact published Reddit phone/tablet artifacts satisfy the Cat Food package/install contract; no launch or device execution was claimed'
