#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
manifest=${CATFOOD_BINARY_MANIFEST:-"$root/runtime-binaries.tsv"}
workspace=${CATFOOD_ROOT:-"$HOME/opt"}
cache=${CATFOOD_CACHE:-"${XDG_CACHE_HOME:-$HOME/.cache}/catfood"}
platform=${CATFOOD_BINARY_PLATFORM:-}

if [ -z "$platform" ]; then
    os=$(uname -s 2>/dev/null || printf '%s\n' unknown)
    machine=$(uname -m 2>/dev/null || printf '%s\n' unknown)
    case "$os:$machine" in
        Linux:armv7*|Linux:armv8l|Linux:arm) platform=linux-armv7 ;;
        Linux:aarch64|Linux:arm64) platform=linux-aarch64 ;;
        Linux:x86_64|Linux:amd64) platform=linux-x86_64 ;;
        Linux:riscv64) platform=linux-riscv64 ;;
        *)
            printf 'Cat Food has no pinned runtime-binary row for %s/%s\n' "$os" "$machine" >&2
            exit 2
            ;;
    esac
fi

[ -f "$manifest" ] || {
    printf 'Cat Food runtime-binary manifest not found: %s\n' "$manifest" >&2
    exit 2
}

mkdir -p "$workspace/bin" "$workspace/packages/runtime-binaries" "$workspace/receipts" "$cache/runtime-binaries"
tab=$(printf '\t')

verify_sha256() {
    expected=$1
    file=$2
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s  %s\n' "$expected" "$file" | sha256sum -c - >/dev/null
        return
    fi
    toybox=${CATFOOD_TOYBOX:-/system/bin/toybox}
    if [ -x "$toybox" ]; then
        printf '%s  %s\n' "$expected" "$file" | "$toybox" sha256sum -c - >/dev/null
        return
    fi
    printf '%s\n' 'Cat Food needs SHA-256 verification; neither sha256sum nor Android toybox is available' >&2
    exit 127
}

ensure_runtime_command() {
    command_name=$1
    package_name=$2
    if command -v "$command_name" >/dev/null 2>&1; then
        return 0
    fi
    if [ "${CATFOOD_NO_PACKAGES:-0}" != 1 ] && command -v pkg >/dev/null 2>&1; then
        printf 'runtime-binaries         pkg %s\n' "$package_name"
        pkg install -y "$package_name"
    fi
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'Cat Food runtime-binary installation needs command: %s\n' "$command_name" >&2
        exit 127
    }
}

ensure_runtime_command curl curl

safe_destination() {
    destination=$1
    if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
        return 0
    fi
    if [ -L "$destination" ]; then
        existing=$(readlink "$destination" 2>/dev/null || printf '%s' '')
        case "$existing" in
            "$workspace/packages/runtime-binaries/"*) return 0 ;;
        esac
    fi
    printf '%s exists and is not owned by Cat Food runtime binaries; leaving it alone\n' "$destination" >&2
    exit 4
}

matched=0
while IFS="$tab" read -r command source version row_platform mode url sha256 entrypoint probe_arg probe_contains; do
    case "$command" in ''|\#*) continue ;; esac
    [ "$row_platform" = "$platform" ] || continue
    matched=1

    case "$mode" in
        file) ;;
        tar.gz) ensure_runtime_command tar tar ;;
        *)
            printf '%s has unsupported runtime-binary mode: %s\n' "$command" "$mode" >&2
            exit 3
            ;;
    esac

    package_dir="$workspace/packages/runtime-binaries/$command/$version/$platform"
    binary="$package_dir/$command"
    marker="$package_dir/asset.sha256"
    destination="$workspace/bin/$command"
    receipt="$workspace/receipts/runtime-binary-$platform-$command.tsv"

    current=0
    if [ -x "$binary" ] && [ -f "$marker" ] && grep -Fqx "$sha256" "$marker"; then
        probe_output=$("$binary" "$probe_arg" 2>&1 || :)
        if printf '%s\n' "$probe_output" | grep -F "$probe_contains" >/dev/null 2>&1; then
            current=1
        fi
    fi

    if [ "$current" -eq 0 ]; then
        download="$cache/runtime-binaries/$command-$version-$platform-$sha256"
        if [ ! -f "$download" ] || ! verify_sha256 "$sha256" "$download"; then
            temporary_download=$download.tmp.$$
            rm -f "$temporary_download"
            printf '%-24s fetch %s %s for %s\n' "$command" "$source" "$version" "$platform"
            curl -fsSL --retry 2 "$url" -o "$temporary_download"
            verify_sha256 "$sha256" "$temporary_download"
            mv "$temporary_download" "$download"
        fi

        staging="$workspace/packages/runtime-binaries/.$command.staging.$$"
        rm -rf "$staging"
        mkdir -p "$staging"
        case "$mode" in
            file)
                cp "$download" "$staging/$command"
                ;;
            tar.gz)
                unpack="$staging/unpack"
                mkdir -p "$unpack"
                tar -xzf "$download" -C "$unpack"
                [ -f "$unpack/$entrypoint" ] || {
                    printf '%s archive is missing declared entrypoint: %s\n' "$command" "$entrypoint" >&2
                    rm -rf "$staging"
                    exit 3
                }
                cp "$unpack/$entrypoint" "$staging/$command"
                rm -rf "$unpack"
                ;;
        esac
        chmod 0755 "$staging/$command"

        probe_output=$("$staging/$command" "$probe_arg" 2>&1) || {
            printf '%s runtime probe failed on %s\n' "$command" "$platform" >&2
            rm -rf "$staging"
            exit 3
        }
        printf '%s\n' "$probe_output" | grep -F "$probe_contains" >/dev/null 2>&1 || {
            printf '%s runtime probe returned an unexpected version on %s: %s\n' "$command" "$platform" "$probe_output" >&2
            rm -rf "$staging"
            exit 3
        }

        printf '%s\n' "$sha256" > "$staging/asset.sha256"
        mkdir -p "$(dirname -- "$package_dir")"
        rm -rf "$package_dir"
        mv "$staging" "$package_dir"

        {
            printf 'schema\tcatfood-runtime-binary-v1\n'
            printf 'command\t%s\n' "$command"
            printf 'source\t%s\n' "$source"
            printf 'version\t%s\n' "$version"
            printf 'platform\t%s\n' "$platform"
            printf 'url\t%s\n' "$url"
            printf 'sha256\t%s\n' "$sha256"
            printf 'installation_result\tPASS\n'
            printf 'runtime_probe_result\tPASS\n'
            printf 'runtime_probe_evidence\t%s\n' "$probe_output"
        } > "$receipt.tmp.$$"
        mv "$receipt.tmp.$$" "$receipt"
    else
        printf '%-24s current %s %s\n' "$command" "$version" "$platform"
    fi

    safe_destination "$destination"
    rm -f "$destination"
    ln -s "$binary" "$destination"
done < "$manifest"

[ "$matched" -eq 1 ] || {
    printf 'Cat Food runtime-binary manifest has no rows for %s\n' "$platform" >&2
    exit 2
}

printf 'Cat Food runtime binaries are current for %s under %s\n' "$platform" "$workspace"
