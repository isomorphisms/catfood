#!/bin/sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
manifest=${CATFOOD_PHONE_MANIFEST:-"$script_dir/tools.tsv"}
workspace=${CATFOOD_PHONE_ROOT:-${CATFOOD_ROOT:-"$HOME/opt"}}
state_root=${CATFOOD_PHONE_PREFIX:-"$workspace"}
bin_dir=${CATFOOD_PHONE_BIN:-"$workspace/bin"}

abi=unknown
fingerprint=unknown
emulator=unknown
if command -v getprop >/dev/null 2>&1; then
    value=$(getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')
    [ -z "$value" ] || abi=$value
    value=$(getprop ro.build.fingerprint 2>/dev/null | tr -d '\r')
    [ -z "$value" ] || fingerprint=$value
    kernel_qemu=$(getprop ro.kernel.qemu 2>/dev/null | tr -d '\r')
    boot_qemu=$(getprop ro.boot.qemu 2>/dev/null | tr -d '\r')
    if [ "$kernel_qemu" = 1 ] || [ "$boot_qemu" = 1 ]; then
        emulator=yes
    else
        emulator=no
    fi
fi

printf 'device      Android\n'
printf 'abi         %s\n' "$abi"
printf 'emulator    %s\n' "$emulator"
printf 'fingerprint %s\n' "$fingerprint"
printf 'storage     '
df -h "$HOME" 2>/dev/null | tail -n 1 || true
printf 'root        %s\n' "$workspace"
printf '\n'

tab=$(printf '\t')
failed=0
while IFS="$tab" read -r name mode command wanted_abi source ref url sha256 entrypoint; do
    case "$name" in
        ''|'#'*) continue ;;
    esac

    if [ "$mode" = system ]; then
        if command -v "$command" >/dev/null 2>&1; then
            printf '%-10s PASS system %s\n' "$name" "$(command -v "$command")"
        else
            printf '%-10s FAIL missing system command %s\n' "$name" "$command"
            failed=1
        fi
        continue
    fi

    if [ "$wanted_abi" != any ] && [ "$wanted_abi" != "$abi" ]; then
        printf '%-10s SKIP artifact abi=%s\n' "$name" "$wanted_abi"
        continue
    fi

    if [ "$url" = PENDING ] || [ "$sha256" = PENDING ]; then
        if [ -x "$bin_dir/$command" ]; then
            printf '%-10s LOCAL %s (manifest artifact still pending)\n' "$name" "$bin_dir/$command"
        else
            printf '%-10s PENDING %s@%s\n' "$name" "$source" "$ref"
        fi
        continue
    fi

    wrapper="$bin_dir/$command"
    receipt="$state_root/receipts/$name.tsv"
    if [ ! -x "$wrapper" ]; then
        printf '%-10s FAIL expected installed command %s\n' "$name" "$wrapper"
        failed=1
        continue
    fi
    if [ ! -f "$receipt" ]; then
        printf '%-10s FAIL missing receipt %s\n' "$name" "$receipt"
        failed=1
        continue
    fi
    if ! grep -F '# catfood phone artifact wrapper' "$wrapper" >/dev/null 2>&1; then
        printf '%-10s FAIL stable command is not the managed phone wrapper\n' "$name"
        failed=1
        continue
    fi

    receipt_ok=1
    for expected in \
        "name${tab}$name" \
        "command${tab}$command" \
        "source${tab}$source" \
        "ref${tab}$ref" \
        "abi${tab}$wanted_abi" \
        "url${tab}$url" \
        "sha256${tab}$sha256"
    do
        if ! grep -Fqx "$expected" "$receipt" 2>/dev/null; then
            receipt_ok=0
            break
        fi
    done
    if [ "$receipt_ok" -ne 1 ]; then
        printf '%-10s FAIL receipt does not match manifest\n' "$name"
        failed=1
        continue
    fi

    case "$name" in
        grease)
            if result=$("$wrapper" -c 'false ∨ echo grease-phone-ok' 2>&1) &&
               [ "$result" = grease-phone-ok ]; then
                printf '%-10s PASS exact receipt + executable smoke\n' "$name"
            else
                printf '%-10s FAIL executable smoke: %s\n' "$name" "$result"
                failed=1
            fi
            ;;
        *)
            printf '%-10s PASS exact receipt + %s\n' "$name" "$wrapper"
            ;;
    esac
done < "$manifest"

[ "$failed" -eq 0 ] || exit 1
