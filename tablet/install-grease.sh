#!/bin/sh
set -eu

workspace=${CATFOOD_ROOT:-$HOME/opt}
cache=${CATFOOD_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/catfood}
packaging_sha=9b3dc89048911bd0e23ee992fe00dcb3cd427f63
source_sha=8052868773077602266d80bf39aad6998e2da749
artifact_sha256=3ddb962ef313e528e525fa03518f494577e921c2201ecb49f7a11f2fbf4e82b2
release_tag=tablet-aarch64-9b3dc8904891
archive_name=grease-aarch64-termux.tar.gz
url="https://github.com/isomorphisms/grease/releases/download/$release_tag/$archive_name"

abi=
if command -v getprop >/dev/null 2>&1; then
    abi=$(getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')
fi
machine=$(uname -m 2>/dev/null || printf '%s\n' unknown)
case "$abi:$machine" in
    arm64-v8a:aarch64|arm64-v8a:arm64|:aarch64|:arm64) ;;
    *)
        printf 'tablet Grease requires AArch64 Android; found abi=%s machine=%s\n' "${abi:-unknown}" "$machine" >&2
        exit 2
        ;;
esac

for command in curl tar sha256sum; do
    command -v "$command" >/dev/null 2>&1 || {
        printf 'tablet Grease installer needs %s\n' "$command" >&2
        exit 127
    }
done

install_dir="$workspace/.catfood/tablet/grease/$packaging_sha"
receipt_dir="$workspace/.catfood/receipts"
receipt="$receipt_dir/tablet-grease.tsv"
bin_dir="$workspace/bin"
archive="$cache/$archive_name.$packaging_sha"
temporary="$install_dir.tmp.$$"

mkdir -p "$cache" "$receipt_dir" "$bin_dir" "$(dirname -- "$install_dir")"

if [ -x "$install_dir/bin/grease" ] && [ -x "$install_dir/bin/ysh" ] &&
   [ -f "$receipt" ] &&
   grep -Fqx "packaging_sha\t$packaging_sha" "$receipt" 2>/dev/null &&
   grep -Fqx "artifact_sha256\t$artifact_sha256" "$receipt" 2>/dev/null; then
    printf 'tablet Grease artifact is already installed at %s\n' "$install_dir"
else
    rm -f "$archive.tmp"
    printf 'fetch tablet Grease %s\n' "$packaging_sha"
    curl -fL --retry 2 "$url" -o "$archive.tmp"
    printf '%s  %s\n' "$artifact_sha256" "$archive.tmp" | sha256sum -c -
    mv "$archive.tmp" "$archive"

    rm -rf "$temporary"
    mkdir -p "$temporary"
    tar -xzf "$archive" -C "$temporary"
    [ -x "$temporary/bin/grease" ] || {
        printf '%s\n' 'tablet Grease archive is missing bin/grease' >&2
        rm -rf "$temporary"
        exit 3
    }
    [ -x "$temporary/bin/ysh" ] || {
        printf '%s\n' 'tablet Grease archive is missing bin/ysh' >&2
        rm -rf "$temporary"
        exit 3
    }
    rm -rf "$install_dir"
    mv "$temporary" "$install_dir"

    {
        printf 'target\ttablet\n'
        printf 'abi\tarm64-v8a\n'
        printf 'packaging_source\tisomorphisms/grease\n'
        printf 'packaging_sha\t%s\n' "$packaging_sha"
        printf 'source_sha\t%s\n' "$source_sha"
        printf 'release_tag\t%s\n' "$release_tag"
        printf 'url\t%s\n' "$url"
        printf 'artifact_sha256\t%s\n' "$artifact_sha256"
        printf 'physical_tablet_execution\tPENDING\n'
    } > "$receipt"
fi

install_link() {
    name=$1
    target=$2
    destination="$bin_dir/$name"
    if [ -e "$destination" ] && [ ! -L "$destination" ]; then
        printf '%s exists and is not a symlink; refusing to replace it\n' "$destination" >&2
        exit 4
    fi
    rm -f "$destination"
    ln -s "$target" "$destination"
}

install_link grease "$install_dir/bin/grease"
install_link ysh "$install_dir/bin/ysh"

printf 'tablet Grease installed: %s\n' "$bin_dir/grease"
printf 'receipt: %s\n' "$receipt"
printf '%s\n' 'execution has not been claimed yet; run the tablet smoke separately'
