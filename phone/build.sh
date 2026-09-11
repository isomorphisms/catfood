#!/bin/sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
manifest=${CATFOOD_PHONE_MANIFEST:-"$script_dir/tools.tsv"}
workspace=${CATFOOD_PHONE_ROOT:-${CATFOOD_ROOT:-"$HOME/opt"}}
state_root=${CATFOOD_PHONE_PREFIX:-"$workspace"}
bin_dir=${CATFOOD_PHONE_BIN:-"$workspace/bin"}

[ -f "$manifest" ] || {
    echo "phone manifest is missing: $manifest" >&2
    exit 1
}

phone_abi=
if command -v getprop >/dev/null 2>&1; then
    phone_abi=$(getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')
fi
if [ -z "$phone_abi" ]; then
    case $(uname -m) in
        armv7l|armv8l) phone_abi=armeabi-v7a ;;
        aarch64) phone_abi=arm64-v8a ;;
        *) phone_abi=unknown ;;
    esac
fi

case "$phone_abi" in
    armeabi-v7a|arm64-v8a) ;;
    *)
        echo "phone Cat Food supports physical Android ARM targets; found ABI: $phone_abi" >&2
        exit 1
        ;;
esac

mkdir -p "$state_root/downloads" "$state_root/tools" "$state_root/receipts" "$bin_dir"

tab=$(printf '\t')
missing=0
while IFS="$tab" read -r name mode command abi source ref url sha256 entrypoint; do
    case "$name" in
        ''|'#'*) continue ;;
    esac
    [ "$mode" = system ] || continue
    if command -v "$command" >/dev/null 2>&1; then
        printf '%-10s system PASS\n' "$name"
    else
        printf '%-10s system MISSING (%s)\n' "$name" "$command" >&2
        missing=1
    fi
done < "$manifest"

[ "$missing" -eq 0 ] || {
    echo 'phone Cat Food will not install a compiler or source tree to repair missing prerequisites.' >&2
    exit 2
}

while IFS="$tab" read -r name mode command abi source ref url sha256 entrypoint; do
    case "$name" in
        ''|'#'*) continue ;;
    esac
    [ "$mode" != system ] || continue

    if [ "$abi" != any ] && [ "$abi" != "$phone_abi" ]; then
        printf '%-10s SKIP abi=%s phone=%s\n' "$name" "$abi" "$phone_abi"
        continue
    fi

    if [ "$url" = PENDING ] || [ "$sha256" = PENDING ]; then
        printf '%-10s PENDING prebuilt artifact (%s@%s)\n' "$name" "$source" "$ref"
        continue
    fi

    receipt="$state_root/receipts/$name.tsv"
    tool_dir="$state_root/tools/$name"
    wrapper="$bin_dir/$command"
    expected_url=$(printf 'url\t%s' "$url")
    expected_sha256=$(printf 'sha256\t%s' "$sha256")
    if [ -x "$wrapper" ] && [ -f "$receipt" ] &&
       grep -Fqx "$expected_url" "$receipt" 2>/dev/null &&
       grep -Fqx "$expected_sha256" "$receipt" 2>/dev/null; then
        printf '%-10s current %s@%s\n' "$name" "$source" "$ref"
        continue
    fi

    if [ -e "$wrapper" ] || [ -L "$wrapper" ]; then
        if [ ! -f "$receipt" ] || [ ! -f "$wrapper" ] ||
           ! grep -F '# catfood phone artifact wrapper' "$wrapper" >/dev/null 2>&1; then
            printf '%s exists and is not a Cat Food phone artifact wrapper; leaving it alone\n' "$wrapper" >&2
            exit 3
        fi
    fi

    download="$state_root/downloads/$name.download.$$"
    staging="$state_root/tools/.$name.staging.$$"
    rm -rf "$download" "$staging"

    printf '%-10s fetch %s@%s\n' "$name" "$source" "$ref"
    curl -fL --retry 2 "$url" -o "$download"
    printf '%s  %s\n' "$sha256" "$download" | sha256sum -c -

    mkdir -p "$staging"
    case "$mode" in
        file)
            mkdir -p "$(dirname -- "$staging/$entrypoint")"
            mv "$download" "$staging/$entrypoint"
            ;;
        archive)
            tar -xzf "$download" -C "$staging"
            rm -f "$download"
            ;;
        *)
            echo "unknown phone artifact mode: $mode" >&2
            rm -rf "$download" "$staging"
            exit 3
            ;;
    esac

    [ -f "$staging/$entrypoint" ] || {
        echo "$name artifact does not contain $entrypoint" >&2
        rm -rf "$staging"
        exit 3
    }
    chmod +x "$staging/$entrypoint"

    rm -rf "$tool_dir"
    mv "$staging" "$tool_dir"
    tool="$tool_dir/$entrypoint"

    wrapper_tmp="$bin_dir/.$command.tmp.$$"
    {
        printf '%s\n' '#!/bin/sh'
        printf '%s\n' '# catfood phone artifact wrapper'
        printf 'exec "%s" "$@"\n' "$tool"
    } > "$wrapper_tmp"
    chmod +x "$wrapper_tmp"
    mv "$wrapper_tmp" "$wrapper"

    receipt_tmp="$state_root/receipts/.$name.tmp.$$"
    {
        printf 'name\t%s\n' "$name"
        printf 'command\t%s\n' "$command"
        printf 'source\t%s\n' "$source"
        printf 'ref\t%s\n' "$ref"
        printf 'abi\t%s\n' "$abi"
        printf 'url\t%s\n' "$url"
        printf 'sha256\t%s\n' "$sha256"
    } > "$receipt_tmp"
    mv "$receipt_tmp" "$receipt"

    printf '%-10s installed %s\n' "$name" "$wrapper"
done < "$manifest"

printf '\nphone Cat Food root: %s\n' "$workspace"
printf 'artifact tools:       %s\n' "$state_root/tools"
printf 'artifact receipts:    %s\n' "$state_root/receipts"
printf 'stable commands:      %s\n' "$bin_dir"
printf 'add to PATH if needed: export PATH="%s:$PATH"\n\n' "$bin_dir"

CATFOOD_PHONE_MANIFEST="$manifest" \
CATFOOD_PHONE_ROOT="$workspace" \
CATFOOD_PHONE_PREFIX="$state_root" \
CATFOOD_PHONE_BIN="$bin_dir" \
    sh "$script_dir/doctor.sh"
