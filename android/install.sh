#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
packages=${CATFOOD_ANDROID_PACKAGES:-"$root/android/packages.tsv"}
delivery=${CATFOOD_ANDROID_DELIVERY:-"$root/android/delivery.tsv"}
tools=${CATFOOD_TOOLS:-"$root/tools.tsv"}
target=${CATFOOD_TARGET:-}
workspace=${CATFOOD_ROOT:-"$HOME/opt"}
cache=${CATFOOD_CACHE:-"${XDG_CACHE_HOME:-$HOME/.cache}/catfood"}

case "$target" in
    phone) expected_abi=armeabi-v7a ;;
    tablet) expected_abi=arm64-v8a ;;
    *)
        printf 'Android delivery requires CATFOOD_TARGET=phone or tablet; found %s\n' "${target:-unset}" >&2
        exit 2
        ;;
esac

CATFOOD_TOOLS="$tools" CATFOOD_ANDROID_DELIVERY="$delivery" CATFOOD_ANDROID_PACKAGES="$packages" \
    sh "$root/android/check.sh" check >/dev/null

abi=${CATFOOD_DEVICE_ABI:-}
if [ -z "$abi" ] && command -v getprop >/dev/null 2>&1; then
    abi=$(getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')
fi
if [ -z "$abi" ]; then
    machine=$(uname -m 2>/dev/null || printf '%s\n' unknown)
    case "$machine" in
        armv7*|armv8l|arm) abi=armeabi-v7a ;;
        aarch64|arm64) abi=arm64-v8a ;;
        *) abi=unknown ;;
    esac
fi
if [ "$abi" != "$expected_abi" ]; then
    printf 'Cat Food %s delivery requires ABI %s; found %s\n' "$target" "$expected_abi" "$abi" >&2
    exit 2
fi

mkdir -p "$workspace/bin" "$workspace/downloads" "$workspace/packages" "$workspace/receipts" "$cache"
PATH="$workspace/bin:$PATH"
export PATH
tab=$(printf '\t')

install_termux_packages() {
    values=$1
    package=$2
    [ "$values" != - ] || return 0
    command -v pkg >/dev/null 2>&1 || {
        printf '%s declares Termux packages but pkg is not available: %s\n' "$package" "$values" >&2
        exit 127
    }
    old_ifs=$IFS
    IFS=,
    set -- $values
    IFS=$old_ifs
    printf '%-24s pkg %s\n' "$package" "$*"
    pkg install -y "$@"
}

require_commands() {
    values=$1
    [ "$values" != - ] || return 0
    old_ifs=$IFS
    IFS=,
    set -- $values
    IFS=$old_ifs
    for required in "$@"; do
        command -v "$required" >/dev/null 2>&1 || {
            printf 'Cat Food %s package installation needs command: %s\n' "$target" "$required" >&2
            exit 127
        }
    done
}

check_runtime_requirements() {
    values=$1
    package=$2
    [ "$values" != - ] || return 0
    old_ifs=$IFS
    IFS=,
    set -- $values
    IFS=$old_ifs
    for required in "$@"; do
        case "$required" in
            command:*)
                name=${required#command:}
                command -v "$name" >/dev/null 2>&1 || {
                    printf '%s runtime dependency is missing command: %s\n' "$package" "$name" >&2
                    exit 3
                }
                ;;
            path:*)
                path=${required#path:}
                [ -e "$path" ] || {
                    printf '%s runtime dependency is missing path: %s\n' "$package" "$path" >&2
                    exit 3
                }
                ;;
            *)
                printf '%s has invalid runtime requirement: %s\n' "$package" "$required" >&2
                exit 3
                ;;
        esac
    done
}

check_package_requirements() {
    values=$1
    package=$2
    [ "$values" != - ] || return 0
    old_ifs=$IFS
    IFS=,
    set -- $values
    IFS=$old_ifs
    for required in "$@"; do
        expected_ref=$(awk -F '\t' -v package="$required" -v target="$target" '
            /^[[:space:]]*($|#)/ { next }
            $1 == package && $2 == target { print $7; exit }
        ' "$packages")
        [ -n "$expected_ref" ] || {
            printf '%s requires undeclared package: %s\n' "$package" "$required" >&2
            exit 3
        }
        receipt="$workspace/receipts/$target-$required.tsv"
        [ -f "$receipt" ] && grep -Fqx "package_ref${tab}$expected_ref" "$receipt" 2>/dev/null || {
            printf '%s requires package %s at %s before installation\n' "$package" "$required" "$expected_ref" >&2
            exit 3
        }
    done
}

safe_command_destination() {
    destination=$1
    mode=$2
    if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
        return 0
    fi
    case "$mode" in
        dex-jni)
            if [ -f "$destination" ] && grep -F '# catfood android dex-jni wrapper' "$destination" >/dev/null 2>&1; then
                return 0
            fi
            ;;
        archive|file)
            if [ -L "$destination" ]; then
                existing=$(readlink "$destination" 2>/dev/null || printf '%s' '')
                case "$existing" in "$workspace/packages/"*) return 0 ;; esac
            fi
            ;;
    esac
    printf '%s exists and is not owned by Cat Food Android delivery; leaving it alone\n' "$destination" >&2
    exit 4
}

package_ids=$(awk -F '\t' -v target="$target" '
    /^[[:space:]]*($|#)/ { next }
    $2 == target && !seen[$1]++ { print $1 }
' "$packages")

for package in $package_ids; do
    row=$(awk -F '\t' -v package="$package" '
        /^[[:space:]]*($|#)/ { next }
        $1 == package { print; exit }
    ' "$packages")
    [ -n "$row" ] || { printf 'package vanished while reading manifest: %s\n' "$package" >&2; exit 3; }
    IFS="$tab" read -r package_id package_target package_abi mode source source_ref package_ref url sha256 \
        first_command first_entrypoint main_class jni_library jni_property install_requires termux_packages \
        runtime_requires package_requires <<EOF_ROW
$row
EOF_ROW

    [ "$package_target" = "$target" ] && [ "$package_abi" = "$abi" ] || {
        printf '%s manifest target/ABI does not match device\n' "$package" >&2
        exit 3
    }
    install_termux_packages "$termux_packages" "$package"
    require_commands "$install_requires"
    check_runtime_requirements "$runtime_requires" "$package"
    check_package_requirements "$package_requires" "$package"

    entries_file="$workspace/receipts/.$package.entries.$$"
    awk -F '\t' -v package="$package" '
        /^[[:space:]]*($|#)/ { next }
        $1 == package { print $10 "\t" $11 }
    ' "$packages" > "$entries_file"

    package_dir="$workspace/packages/$package/$package_ref"
    receipt="$workspace/receipts/$target-$package.tsv"
    current=0
    if [ -d "$package_dir" ] && [ -f "$receipt" ] &&
       grep -Fqx "package_ref${tab}$package_ref" "$receipt" 2>/dev/null &&
       grep -Fqx "sha256${tab}$sha256" "$receipt" 2>/dev/null &&
       grep -Fqx "termux_packages${tab}$termux_packages" "$receipt" 2>/dev/null; then
        current=1
        while IFS="$tab" read -r command entrypoint; do
            [ -f "$package_dir/$entrypoint" ] || current=0
        done < "$entries_file"
        if [ "$mode" = dex-jni ] && [ ! -f "$package_dir/$jni_library" ]; then
            current=0
        fi
    fi

    if [ "$current" -eq 0 ]; then
        if [ ! -f "$workspace/downloads/$package-$sha256" ] ||
           ! printf '%s  %s\n' "$sha256" "$workspace/downloads/$package-$sha256" | sha256sum -c - >/dev/null 2>&1; then
            download="$workspace/downloads/$package-$sha256"
            temporary_download="$download.tmp.$$"
            rm -f "$temporary_download"
            printf '%-24s fetch %s@%s\n' "$package" "$source" "$source_ref"
            curl -fL --retry 2 "$url" -o "$temporary_download"
            printf '%s  %s\n' "$sha256" "$temporary_download" | sha256sum -c -
            mv "$temporary_download" "$download"
        else
            download="$workspace/downloads/$package-$sha256"
        fi

        staging="$workspace/packages/.$package.staging.$$"
        rm -rf "$staging"
        mkdir -p "$staging"
        case "$mode" in
            archive|dex-jni) tar -xzf "$download" -C "$staging" ;;
            file)
                mkdir -p "$staging/$(dirname -- "$first_entrypoint")"
                cp "$download" "$staging/$first_entrypoint"
                ;;
        esac

        while IFS="$tab" read -r command entrypoint; do
            [ -f "$staging/$entrypoint" ] || {
                printf '%s package is missing declared entrypoint: %s\n' "$package" "$entrypoint" >&2
                rm -rf "$staging" "$entries_file"
                exit 3
            }
        done < "$entries_file"

        if [ "$mode" = dex-jni ]; then
            package_receipt="$staging/catfood-package.tsv"
            [ -f "$package_receipt" ] || {
                printf '%s DEX/JNI package is missing catfood-package.tsv\n' "$package" >&2
                rm -rf "$staging" "$entries_file"
                exit 3
            }
            for expected in \
                "target${tab}$target" \
                "abi${tab}$abi" \
                "source_ref${tab}$source_ref" \
                "package_ref${tab}$package_ref"; do
                grep -Fqx "$expected" "$package_receipt" || {
                    printf '%s DEX/JNI package receipt does not match: %s\n' "$package" "$expected" >&2
                    rm -rf "$staging" "$entries_file"
                    exit 3
                }
            done
            [ -f "$staging/$jni_library" ] || {
                printf '%s DEX/JNI package is missing JNI library: %s\n' "$package" "$jni_library" >&2
                rm -rf "$staging" "$entries_file"
                exit 3
            }
        fi

        mkdir -p "$(dirname -- "$package_dir")"
        rm -rf "$package_dir"
        mv "$staging" "$package_dir"
        {
            printf 'package\t%s\n' "$package"
            printf 'target\t%s\n' "$target"
            printf 'abi\t%s\n' "$abi"
            printf 'mode\t%s\n' "$mode"
            printf 'source\t%s\n' "$source"
            printf 'source_ref\t%s\n' "$source_ref"
            printf 'package_ref\t%s\n' "$package_ref"
            printf 'url\t%s\n' "$url"
            printf 'sha256\t%s\n' "$sha256"
            printf 'termux_packages\t%s\n' "$termux_packages"
            printf 'runtime_requires\t%s\n' "$runtime_requires"
            printf 'package_requires\t%s\n' "$package_requires"
            printf 'physical_device_execution\tPENDING\n'
        } > "$receipt.tmp.$$"
        mv "$receipt.tmp.$$" "$receipt"
    else
        printf '%-24s current %s\n' "$package" "$package_ref"
    fi

    while IFS="$tab" read -r command entrypoint; do
        [ -n "$command" ] || continue
        destination="$workspace/bin/$command"
        safe_command_destination "$destination" "$mode"
        case "$mode" in
            archive|file)
                chmod +x "$package_dir/$entrypoint"
                rm -f "$destination"
                ln -s "$package_dir/$entrypoint" "$destination"
                ;;
            dex-jni)
                app_process=${CATFOOD_APP_PROCESS:-/system/bin/app_process}
                [ -x "$app_process" ] || {
                    printf '%s needs executable Android app_process: %s\n' "$package" "$app_process" >&2
                    rm -f "$entries_file"
                    exit 127
                }
                temporary_wrapper="$destination.tmp.$$"
                cat > "$temporary_wrapper" <<EOF_WRAPPER
#!/bin/sh
# catfood android dex-jni wrapper
set -eu
root=\$(CDPATH='' cd -- "\$(dirname -- "\$0")/.." && pwd)
package_dir="\$root/packages/$package/$package_ref"
app_process=\${CATFOOD_APP_PROCESS:-/system/bin/app_process}
exec env CLASSPATH="\$package_dir/$entrypoint" "\$app_process" "-D$jni_property=\$package_dir/$jni_library" /system/bin "$main_class" "\$@"
EOF_WRAPPER
                chmod +x "$temporary_wrapper"
                mv "$temporary_wrapper" "$destination"
                ;;
        esac
        printf '%-24s command %s\n' "$package" "$destination"
    done < "$entries_file"
    rm -f "$entries_file"
done

printf '\nCat Food %s installed all currently published packages.\n' "$target"
unresolved=$(CATFOOD_TOOLS="$tools" CATFOOD_ANDROID_DELIVERY="$delivery" CATFOOD_ANDROID_PACKAGES="$packages" \
    sh "$root/android/check.sh" gaps "$target")
if [ -n "$unresolved" ]; then
    printf '%s\n' 'Whole-inventory readiness remains PENDING:'
    printf '%s\n' "$unresolved"
    printf '%s\n' 'No source build fallback was attempted.'
else
    printf '%s\n' 'No manifest-level Android delivery gaps remain; runtime/device acceptance is still separate.'
fi
