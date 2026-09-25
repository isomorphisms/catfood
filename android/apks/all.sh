#!/bin/sh
set -eu

self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$self_dir/../.." && pwd)

usage() {
    cat <<'EOF'
usage: android/apks/all.sh [phone|tablet] [destination]

Stage every APK usable on the selected Android target.

Aliases:
  phone, miro-a1, armv7, armeabi-v7a
  tablet, tab-p10-row, arm64, aarch64, arm64-v8a

With no target, CATFOOD_TARGET=phone|tablet is honored first; otherwise
the Android ABI list / machine architecture is inspected.
EOF
}

case $# in
    0|1|2) ;;
    *) usage >&2; exit 2 ;;
esac

requested=${1:-${CATFOOD_TARGET:-}}
destination=${2:-}

if [ -z "$requested" ] || [ "$requested" = auto ]; then
    abis=
    if command -v getprop >/dev/null 2>&1; then
        abis=$(getprop ro.product.cpu.abilist 2>/dev/null || true)
    fi
    case ",$abis," in
        *,arm64-v8a,*) requested=tablet ;;
        *,armeabi-v7a,*) requested=phone ;;
        *)
            machine=$(uname -m 2>/dev/null || printf '%s\n' unknown)
            case "$machine" in
                aarch64|arm64) requested=tablet ;;
                armv7*|armv8l|arm) requested=phone ;;
                *)
                    printf '%s\n' "cannot infer Android APK target from ABI/machine: $machine" >&2
                    usage >&2
                    exit 2
                    ;;
            esac
            ;;
    esac
fi

case "$requested" in
    phone|miro-a1|armv7|armeabi-v7a)
        shelf=miro-a1
        ;;
    tablet|tab-p10-row|arm64|aarch64|arm64-v8a)
        shelf=tab-p10-row
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        printf '%s\n' "unknown APK target: $requested" >&2
        usage >&2
        exit 2
        ;;
esac

if [ -z "$destination" ]; then
    if [ -d "$HOME/storage/downloads" ] && [ -w "$HOME/storage/downloads" ]; then
        destination="$HOME/storage/downloads/CatFood-APKs/$shelf"
    else
        destination="$repo_root/dist/android-apks/$shelf"
    fi
fi

source_dir="$self_dir/$shelf"
manifest="$source_dir/manifest.tsv"
[ -f "$manifest" ] || {
    printf '%s\n' "missing APK shelf manifest: $manifest" >&2
    exit 1
}

if command -v sha256sum >/dev/null 2>&1; then
    sha256_command=sha256sum
elif [ -x /system/bin/toybox ]; then
    sha256_command='/system/bin/toybox sha256sum'
else
    printf '%s\n' 'need sha256sum or Android toybox sha256sum to verify APKs' >&2
    exit 1
fi

mkdir -p "$destination"
combined_manifest="$destination/manifest.tsv"
printf '%s\n' 'shelf	repository	source_kind	source_ref	asset	file	sha256	bytes	native_abis	url' > "$combined_manifest"

tab=$(printf '\t')
while IFS="$tab" read -r repository source_kind source_ref asset file sha256 bytes native_abis url; do
    case "$repository" in
        ''|repository) continue ;;
    esac

    source_file="$source_dir/$file"
    [ -f "$source_file" ] || {
        printf '%s\n' "missing APK: $source_file" >&2
        exit 1
    }

    got_sha=$($sha256_command "$source_file" | awk '{print $1}')
    [ "$got_sha" = "$sha256" ] || {
        printf '%s\n' "APK digest mismatch: $source_file" >&2
        exit 1
    }

    got_bytes=$(wc -c < "$source_file" | tr -d ' ')
    [ "$got_bytes" = "$bytes" ] || {
        printf '%s\n' "APK byte-count mismatch: $source_file" >&2
        exit 1
    }

    cp "$source_file" "$destination/$file"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n'         "$shelf" "$repository" "$source_kind" "$source_ref" "$asset" "$file"         "$sha256" "$bytes" "$native_abis" "$url" >> "$combined_manifest"
done < "$manifest"

count=$(awk 'END { print NR - 1 }' "$combined_manifest")
printf '%s\n' "Staged $count APKs for $shelf"
printf '%s\n' "Folder: $destination"
