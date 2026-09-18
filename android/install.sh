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

verify_sha256() {
    expected=$1
    file=$2
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s  %s\n' "$expected" "$file" | sha256sum -c -
        return
    fi
    toybox=${CATFOOD_TOYBOX:-/system/bin/toybox}
    if [ -x "$toybox" ]; then
        printf '%s  %s\n' "$expected" "$file" | "$toybox" sha256sum -c -
        return
    fi
    printf '%s\n' 'Cat Food needs SHA-256 verification; neither sha256sum nor Android toybox is available' >&2
    exit 127
}

termux_package_command() {
    case $1 in
        gawk) printf '%s\n' awk ;;
        libiconv) printf '%s\n' iconv ;;
        *) printf '%s\n' "$1" ;;
    esac
}

install_termux_packages() {
    values=$1
    package=$2
    [ "$values" != - ] || return 0

    old_ifs=$IFS
    IFS=,
    set -- $values
    IFS=$old_ifs

    missing=
    for candidate in "$@"; do
        provided_command=$(termux_package_command "$candidate")
        if ! command -v "$provided_command" >/dev/null 2>&1; then
            missing="$missing${missing:+ }$candidate"
        fi
    done
    [ -n "$missing" ] || return 0

    command -v pkg >/dev/null 2>&1 || {
        printf '%s declares missing Termux packages but pkg is not available: %s\n' "$package" "$missing" >&2
        exit 127
    }
    set -- $missing
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
        [ -f "$receipt" ] &&
        CATFOOD_TOOLS="$tools" CATFOOD_ANDROID_DELIVERY="$delivery" CATFOOD_ANDROID_PACKAGES="$packages" \
            sh "$root/android/check.sh" receipt "$receipt" >/dev/null 2>&1 &&
        grep -Fqx "package_ref${tab}$expected_ref" "$receipt" 2>/dev/null &&
        grep -Fqx "installation_result${tab}PASS" "$receipt" 2>/dev/null || {
            printf '%s requires package %s at %s before installation\n' "$package" "$required" "$expected_ref" >&2
            exit 3
        }
    done
}

remove_legacy_workbench_link() {
    name=$1
    path=$workspace/bin/$name
    [ -L "$path" ] || return 0
    existing=$(readlink "$path" 2>/dev/null || printf '%s' '')
    case "$existing" in
        "$workspace/packages/"*) ;;
        "$workspace/"*)
            printf '%-24s remove legacy workbench link\n' "$name"
            rm -f "$path"
            ;;
    esac
}

remove_legacy_workbench_wrapper() {
    name=$1
    marker=$2
    path=$workspace/bin/$name
    if [ -f "$path" ] && grep -F "$marker" "$path" >/dev/null 2>&1; then
        printf '%-24s remove legacy workbench wrapper\n' "$name"
        rm -f "$path"
    fi
}

# Older Cat Food Termux feeds treated the device as a source workbench.  A
# phone/tablet is now a runtime target.  Remove only the links and wrappers
# written by those old Cat Food paths; arbitrary user commands remain protected.
for legacy_command in R Rscript edric idris2 fieldmouse icu ib-smoke ick ithon osh ysh grease go_down_load gdl; do
    remove_legacy_workbench_link "$legacy_command"
done
remove_legacy_workbench_wrapper az '# catfood az wrapper'
remove_legacy_workbench_wrapper abe '# catfood az wrapper'
remove_legacy_workbench_wrapper aa '# catfood aa wrapper'

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

gopeed_control_marker="# Cat Food's small command-line client for the local Gopeed REST service."

safe_gopeed_control_destination() {
    name=$1
    destination=$workspace/bin/$name
    [ ! -e "$destination" ] && [ ! -L "$destination" ] && return 0

    if [ "$name" = gopeed ] && [ -f "$destination" ] &&
       grep -F "$gopeed_control_marker" "$destination" >/dev/null 2>&1; then
        return 0
    fi

    if [ "$name" != gopeed ] && [ -L "$destination" ]; then
        existing=$(readlink "$destination" 2>/dev/null || printf '%s' '')
        case "$existing" in
            gopeed|"$workspace/bin/gopeed") return 0 ;;
        esac
    fi

    printf '%s exists and is not the Cat Food Gopeed control command; leaving it alone\n' "$destination" >&2
    exit 4
}

install_gopeed_control_command() {
    script=$root/gopeed.ysh
    [ -f "$script" ] || return 0

    # The Android product fleet stays package-only. This one command is part
    # of the Cat Food control plane itself and is installed only after the
    # delivered Grease package has made YSH available.
    if [ ! -x "$workspace/bin/ysh" ]; then
        printf '%-24s %s\n' gopeed-control 'not installed: ysh is unavailable' >&2
        return 0
    fi

    safe_gopeed_control_destination gopeed
    safe_gopeed_control_destination gdl
    safe_gopeed_control_destination go_down_load

    cp "$script" "$workspace/bin/gopeed"
    chmod 0755 "$workspace/bin/gopeed"
    rm -f "$workspace/bin/gdl" "$workspace/bin/go_down_load"
    ln -s gopeed "$workspace/bin/gdl"
    ln -s gopeed "$workspace/bin/go_down_load"
    printf '%-24s command %s (aliases: gdl go_down_load)\n' gopeed-control "$workspace/bin/gopeed"
}

package_ids=$(awk -F '\t' -v target="$target" '
    /^[[:space:]]*($|#)/ { next }
    $2 == target && !seen[$1]++ { print $1 }
' "$packages")

for package in $package_ids; do
    publication_result=NOT_VERIFIED
    publication_evidence=-
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
       CATFOOD_TOOLS="$tools" CATFOOD_ANDROID_DELIVERY="$delivery" CATFOOD_ANDROID_PACKAGES="$packages" \
           sh "$root/android/check.sh" receipt "$receipt" >/dev/null 2>&1 &&
       grep -Fqx "installation_result${tab}PASS" "$receipt" 2>/dev/null; then
        current=1
        while IFS="$tab" read -r command entrypoint; do
            [ -f "$package_dir/$entrypoint" ] || current=0
        done < "$entries_file"
        if [ "$mode" = dex-jni ] && [ ! -f "$package_dir/$jni_library" ]; then
            current=0
        fi
    fi

    if [ "$current" -eq 0 ]; then
        rm -f "$receipt"
        download="$workspace/downloads/$package-$sha256"
        if [ ! -f "$download" ] || ! verify_sha256 "$sha256" "$download" >/dev/null 2>&1; then
            temporary_download="$download.tmp.$$"
            rm -f "$temporary_download"
            printf '%-24s fetch %s@%s\n' "$package" "$source" "$source_ref"
            curl -fL --retry 2 "$url" -o "$temporary_download"
            verify_sha256 "$sha256" "$temporary_download"
            mv "$temporary_download" "$download"
            publication_result=PASS
            publication_evidence=$url
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

    if [ "$current" -eq 0 ]; then
        {
            printf 'schema\tcatfood-android-evidence-v1\n'
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
            printf 'build_result\tNOT_VERIFIED\n'
            printf 'build_evidence\t-\n'
            printf 'package_result\tPASS\n'
            printf 'package_evidence\tsha256:%s\n' "$sha256"
            printf 'publication_result\t%s\n' "$publication_result"
            printf 'publication_evidence\t%s\n' "$publication_evidence"
            printf 'installation_result\tPASS\n'
            printf 'installation_evidence\t%s\n' "$package_dir"
            printf 'launch_result\tNOT_VERIFIED\n'
            printf 'launch_evidence\t-\n'
            printf 'runtime_result\tNOT_VERIFIED\n'
            printf 'runtime_evidence\t-\n'
            printf 'emulator_result\tNOT_VERIFIED\n'
            printf 'emulator_evidence\t-\n'
            printf 'physical_device_result\tNOT_VERIFIED\n'
            printf 'physical_device_evidence\t-\n'
        } > "$receipt.tmp.$$"
        CATFOOD_TOOLS="$tools" CATFOOD_ANDROID_DELIVERY="$delivery" CATFOOD_ANDROID_PACKAGES="$packages" \
            sh "$root/android/check.sh" receipt "$receipt.tmp.$$" >/dev/null
        mv "$receipt.tmp.$$" "$receipt"
    fi
done

install_gopeed_control_command

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
