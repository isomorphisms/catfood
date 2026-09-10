#!/bin/sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
manifest="$script_dir/tools.tsv"
workspace=${CATFOOD_PHONE_ROOT:-"$HOME/opt"}
prefix=${CATFOOD_PHONE_PREFIX:-"$workspace/phone"}
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

mkdir -p "$prefix/downloads" "$prefix/tools" "$prefix/receipts" "$bin_dir"

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
    echo 'phone Cat Food will not install a compiler or a large package set to repair missing prerequisites.' >&2
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

    receipt="$prefix/receipts/$name.tsv"
    tool_dir="$prefix/tools/$name"
    wrapper="$bin_dir/$command"
    expected_url=$(printf 'url\t%s' "$url")
    expected_sha256=$(printf 'sha256\t%s' "$sha256")
    if [ -x "$wrapper" ] && [ -f "$receipt" ] &&
       grep -Fqx "$expected_url" "$receipt" 2>/dev/null &&
       grep -Fqx "$expected_sha256" "$receipt" 2>/dev/null; then
        printf '%-10s current %s@%s\n' "$name" "$source" "$ref"
        continue
    fi

    download="$prefix/downloads/$name.download.$$"
    unpack="$prefix/tools/.$name.unpack.$$"
    rm -rf "$download" "$unpack"

    printf '%-10s fetch %s@%s\n' "$name" "$source" "$ref"
    curl -fL --retry 2 "$url" -o "$download"
    printf '%s  %s\n' "$sha256" "$download" | sha256sum -c -

    rm -rf "$tool_dir"
    mkdir -p "$tool_dir"
    case "$mode" in
        file)
            mkdir -p "$(dirname -- "$tool_dir/$entrypoint")"
            mv "$download" "$tool_dir/$entrypoint"
            ;;
        archive)
            mkdir -p "$unpack"
            tar -xzf "$download" -C "$unpack"
            rm -f "$download"
            [ -e "$unpack/$entrypoint" ] || {
                echo "$name archive does not contain $entrypoint" >&2
                rm -rf "$unpack"
                exit 3
            }
            rm -rf "$tool_dir"
            mv "$unpack" "$tool_dir"
            ;;
        *)
            echo "unknown phone artifact mode: $mode" >&2
            rm -rf "$download" "$unpack"
            exit 3
            ;;
    esac

    tool="$tool_dir/$entrypoint"
    [ -f "$tool" ] || {
        echo "$name artifact is missing entrypoint $entrypoint" >&2
        exit 3
    }
    chmod +x "$tool"

    wrapper_tmp="$wrapper.tmp.$$"
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$tool" > "$wrapper_tmp"
    chmod +x "$wrapper_tmp"
    mv "$wrapper_tmp" "$wrapper"

    {
        printf 'name\t%s\n' "$name"
        printf 'source\t%s\n' "$source"
        printf 'ref\t%s\n' "$ref"
        printf 'abi\t%s\n' "$abi"
        printf 'url\t%s\n' "$url"
        printf 'sha256\t%s\n' "$sha256"
    } > "$receipt"

    printf '%-10s installed %s\n' "$name" "$wrapper"
done < "$manifest"

printf '\nphone Cat Food root: %s\n' "$workspace"
printf 'stable commands:     %s\n' "$bin_dir"
printf 'add to PATH if needed: export PATH="%s:$PATH"\n\n' "$bin_dir"

sh "$script_dir/doctor.sh"
