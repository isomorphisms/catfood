#!/bin/sh
set -eu

workspace=${CATFOOD_ROOT:-$HOME/opt}
cache=${CATFOOD_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/catfood}
target=${CATFOOD_TARGET:-}
backend_sha=${CATFOOD_REDDIT_BACKEND_SHA:-b7d50d50bc1b11f3c470051a39693cfe5996608c}
release_tag=${CATFOOD_REDDIT_RELEASE_TAG:-reddit-android-b7d50d50bc1b}
release_base="https://github.com/isomorphisms/idric-arm-thumb/releases/download/$release_tag"

case "$target" in
    phone)
        expected_abi=armeabi-v7a
        archive_name=reddit-phone.tar.gz
        ;;
    tablet)
        expected_abi=arm64-v8a
        archive_name=reddit-tablet.tar.gz
        ;;
    *)
        printf 'Reddit Android bundle requires CATFOOD_TARGET=phone or tablet; found %s\n' "${target:-unset}" >&2
        exit 2
        ;;
esac

abi=
if command -v getprop >/dev/null 2>&1; then
    abi=$(getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')
fi
machine=$(uname -m 2>/dev/null || printf '%s\n' unknown)
case "$target:$abi:$machine" in
    phone:armeabi-v7a:*|phone::armv7*|phone::armv8l) ;;
    tablet:arm64-v8a:aarch64|tablet:arm64-v8a:arm64|tablet::aarch64|tablet::arm64) ;;
    *)
        printf 'Reddit %s bundle requires %s Android; found abi=%s machine=%s\n' \
            "$target" "$expected_abi" "${abi:-unknown}" "$machine" >&2
        exit 2
        ;;
esac

for command in curl tar sha256sum grep readlink; do
    command -v "$command" >/dev/null 2>&1 || {
        printf 'Reddit Android installer needs %s\n' "$command" >&2
        exit 127
    }
done
[ -x /system/bin/app_process ] || {
    printf '%s\n' 'Reddit Android installer needs /system/bin/app_process' >&2
    exit 127
}

install_dir="$workspace/.catfood/$target/reddit/$backend_sha"
receipt_dir="$workspace/.catfood/receipts"
receipt="$receipt_dir/$target-reddit.tsv"
bin_dir="$workspace/bin"
archive="$cache/$archive_name.$backend_sha"
checksums="$cache/reddit-SHA256SUMS.$backend_sha"
temporary="$install_dir.tmp.$$"
archive_url="$release_base/$archive_name"
checksums_url="$release_base/SHA256SUMS"
tab=$(printf '\t')

mkdir -p "$cache" "$receipt_dir" "$bin_dir" "$(dirname -- "$install_dir")"

already_installed=0
if [ -f "$install_dir/classes.dex" ] && [ -f "$install_dir/libreddit_cli.so" ] &&
   [ -x "$install_dir/bin/reddit" ] && [ -f "$receipt" ] &&
   grep -Fqx "backend_sha${tab}$backend_sha" "$receipt" 2>/dev/null &&
   grep -Fqx "abi${tab}$expected_abi" "$receipt" 2>/dev/null; then
    already_installed=1
fi

if [ "$already_installed" -eq 0 ]; then
    rm -f "$checksums.tmp" "$archive.tmp"
    printf 'fetch Reddit Android checksums %s\n' "$release_tag"
    curl -fL --retry 2 "$checksums_url" -o "$checksums.tmp"
    grep -E "^[0-9a-fA-F]{64}  ${archive_name}$" "$checksums.tmp" > "$checksums.one" || {
        printf 'release checksum file has no entry for %s\n' "$archive_name" >&2
        rm -f "$checksums.tmp" "$checksums.one"
        exit 3
    }
    artifact_sha256=$(awk '{print $1}' "$checksums.one")
    mv "$checksums.tmp" "$checksums"

    printf 'fetch Reddit %s bundle %s\n' "$target" "$backend_sha"
    curl -fL --retry 2 "$archive_url" -o "$archive.tmp"
    printf '%s  %s\n' "$artifact_sha256" "$archive.tmp" | sha256sum -c -
    mv "$archive.tmp" "$archive"
    rm -f "$checksums.one"

    rm -rf "$temporary"
    mkdir -p "$temporary"
    tar -xzf "$archive" -C "$temporary"

    [ -f "$temporary/classes.dex" ] || {
        printf '%s\n' 'Reddit Android bundle is missing classes.dex' >&2
        rm -rf "$temporary"
        exit 3
    }
    [ -f "$temporary/libreddit_cli.so" ] || {
        printf '%s\n' 'Reddit Android bundle is missing libreddit_cli.so' >&2
        rm -rf "$temporary"
        exit 3
    }
    [ -f "$temporary/android-receipt.txt" ] || {
        printf '%s\n' 'Reddit Android bundle is missing android-receipt.txt' >&2
        rm -rf "$temporary"
        exit 3
    }
    grep -Fqx "target=$target" "$temporary/android-receipt.txt" || {
        printf '%s\n' 'Reddit Android bundle target receipt does not match' >&2
        rm -rf "$temporary"
        exit 3
    }
    grep -Fqx "abi=$expected_abi" "$temporary/android-receipt.txt" || {
        printf '%s\n' 'Reddit Android bundle ABI receipt does not match' >&2
        rm -rf "$temporary"
        exit 3
    }
    grep -Fqx "backend_sha=$backend_sha" "$temporary/android-receipt.txt" || {
        printf '%s\n' 'Reddit Android bundle backend receipt does not match' >&2
        rm -rf "$temporary"
        exit 3
    }

    mkdir -p "$temporary/bin"
    cat > "$temporary/bin/reddit" <<'EOF'
#!/bin/sh
set -eu
physical=$(readlink -f "$0")
root=$(CDPATH='' cd -- "$(dirname -- "$physical")/.." && pwd)
exec env CLASSPATH="$root/classes.dex" \
    /system/bin/app_process "-Dreddit.library=$root/libreddit_cli.so" \
    /system/bin org.isomorphisms.reddit.RedditCli "$@"
EOF
    chmod 0755 "$temporary/bin/reddit"

    rm -rf "$install_dir"
    mv "$temporary" "$install_dir"

    {
        printf 'target\t%s\n' "$target"
        printf 'abi\t%s\n' "$expected_abi"
        printf 'packaging_source\tisomorphisms/idric-arm-thumb\n'
        printf 'backend_sha\t%s\n' "$backend_sha"
        printf 'release_tag\t%s\n' "$release_tag"
        printf 'url\t%s\n' "$archive_url"
        printf 'artifact_sha256\t%s\n' "$artifact_sha256"
        printf 'dex_jni_emulator_execution\tPASS_UPSTREAM\n'
        printf 'physical_device_execution\tPENDING\n'
    } > "$receipt"
else
    printf 'Reddit %s artifact is already installed at %s\n' "$target" "$install_dir"
fi

destination="$bin_dir/reddit"
if [ -e "$destination" ] && [ ! -L "$destination" ]; then
    printf '%s exists and is not a symlink; refusing to replace it\n' "$destination" >&2
    exit 4
fi
rm -f "$destination"
ln -s "$install_dir/bin/reddit" "$destination"

printf 'Reddit installed: %s\n' "$destination"
printf 'receipt: %s\n' "$receipt"
printf '%s\n' 'physical-device search has not been claimed yet'
