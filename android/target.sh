#!/bin/sh
# Stage-zero identity oracle; observed properties are not hardware attestation.
catfood_android_getprop() {
    if [ -n "${CATFOOD_GETPROP:-}" ]; then "$CATFOOD_GETPROP" "$1"
    elif command -v getprop >/dev/null 2>&1; then getprop "$1"
    elif [ -x /system/bin/getprop ]; then /system/bin/getprop "$1"
    else return 1
    fi
}
catfood_android_expected_abi() {
    case $1 in
        phone) printf '%s\n' armeabi-v7a ;;
        c67|tablet) printf '%s\n' arm64-v8a ;;
        *) return 2 ;;
    esac
}
catfood_android_delivery_target() { catfood_android_expected_abi "$1"; }
catfood_android_package_allowed() {
    awk -F '\t' -v package="$1" -v device="$2" '
        $1 == package {
            restricted=1
            n=split($2, devices, ",")
            for (i=1; i<=n; i++) if (devices[i] == device) allowed=1
        }
        END {exit restricted && !allowed}
    ' "${CATFOOD_ANDROID_RESTRICTIONS:-$root/android/package-restrictions.tsv}"
}
# Only immutable embedded package metadata retains the legacy wire labels.
catfood_android_legacy_lane() {
    case $1 in
        armeabi-v7a) printf '%s\n' phone ;;
        arm64-v8a) printf '%s\n' tablet ;;
        *) return 2 ;;
    esac
}
catfood_android_class() {
    case $1 in
        phone|c67) printf '%s\n' phone ;;
        tablet) printf '%s\n' tablet ;;
        termux) printf '%s\n' unknown ;;
        *) printf '%s\n' host ;;
    esac
}
catfood_android_profile() {
    # A1 product tokens are not retained; its model is the positive evidence.
    awk -v product="$1" -v model="$2" -v abi="$3" '
    BEGIN {
        p=""; m=""
        if (product == "Miro_C67") p="c67"
        if (product == "TAB_P10" || product == "TAB_P10_ROW") p="tablet"
        if (model == "Miro C67") m="c67"
        if (model == "TAB_P10" || model == "TAB_P10_ROW") m="tablet"
        if (model == "MIRO A1" || model == "Miro A1") m="phone"
        if ((p != "" && m != "" && p != m) ||
            (p != "" && model != "" && model != "-" && m == "") ||
            (m == "c67" && product != "" && product != "-" && p != m)) {
            print "conflicting Android identity properties" > "/dev/stderr"; exit 2
        }
        known=(m != "" ? m : p)
        if (known == "") { print "termux"; exit }
        expected=(known == "phone" ? "armeabi-v7a" : "arm64-v8a")
        if (abi != "" && abi != "-" && abi != expected) {
            print "Android identity/ABI mismatch" > "/dev/stderr"; exit 2
        }
        print known
    }'
}
catfood_detect_android_target() {
    cf_product=$(catfood_android_getprop ro.product.device 2>/dev/null || :)
    cf_model=$(catfood_android_getprop ro.product.model 2>/dev/null || :)
    cf_abi=$(catfood_android_getprop ro.product.cpu.abi 2>/dev/null || :)
    catfood_android_profile "$cf_product" "$cf_model" "$cf_abi"
}
catfood_detect_target() {
    case ${PREFIX:-}:${TERMUX_VERSION:-} in
        /data/data/com.termux/*:*|*:*?*) catfood_detect_android_target ;;
        *)
            # Positive-host rule from the existing SDF work.
            cf_system=$(uname -s 2>/dev/null || printf '%s\n' unknown)
            if [ "$cf_system" = Linux ] && [ -r /etc/os-release ] &&
                grep -Eq '^ID=("?(debian|ubuntu)"?)$' /etc/os-release; then
                printf '%s\n' cloud
            else
                printf '%s\n' 'unsupported automatic Cat Food host; Debian/Ubuntu Linux evidence required' >&2
                return 2
            fi
            ;;
    esac
}
catfood_android_verify_device_target() {
    cf_requested=$1
    cf_observed=$(catfood_detect_android_target) || return $?
    case $cf_requested in phone|c67|tablet) ;; *) return 2 ;; esac
    if [ "$cf_observed" != termux ] && [ "$cf_requested" != "$cf_observed" ]; then
        printf 'Android target mismatch: requested %s, observed %s\n' "$cf_requested" "$cf_observed" >&2
        return 2
    fi
    cf_abi=$(catfood_android_getprop ro.product.cpu.abi 2>/dev/null || :)
    cf_expected=$(catfood_android_expected_abi "$cf_requested")
    if [ -n "$cf_abi" ] && [ "$cf_abi" != "$cf_expected" ]; then
        printf 'Android target ABI mismatch: expected %s, observed %s\n' "$cf_expected" "$cf_abi" >&2
        return 2
    fi
    # No properties means a planning override, never installation evidence.
    if [ "$cf_observed" = termux ]; then
        cf_product=$(catfood_android_getprop ro.product.device 2>/dev/null || :)
        cf_model=$(catfood_android_getprop ro.product.model 2>/dev/null || :)
        if [ -n "$cf_product$cf_model" ]; then
            printf '%s\n' 'unknown Android identity cannot satisfy a known device target' >&2
            return 2
        fi
    fi
}
catfood_android_require_device() {
    catfood_android_verify_device_target "$1" || return $?
    cf_observed=$(catfood_detect_android_target) || return $?
    if [ "$cf_observed" != "$1" ]; then
        printf '%s\n' 'Android delivery requires observed device identity' >&2
        return 2
    fi
    cf_abi=$(catfood_android_getprop ro.product.cpu.abi 2>/dev/null || :)
    cf_expected=$(catfood_android_expected_abi "$1")
    if [ "$cf_abi" != "$cf_expected" ]; then
        printf '%s\n' 'Android delivery requires observed primary ABI' >&2
        return 2
    fi
    if [ -n "${CATFOOD_DEVICE_ABI:-}" ] && [ "$CATFOOD_DEVICE_ABI" != "$cf_abi" ]; then
        printf '%s\n' 'CATFOOD_DEVICE_ABI contradicts observed ABI' >&2
        return 2
    fi
}
catfood_verify_workbench_target() {
    case ${PREFIX:-}:${TERMUX_VERSION:-} in
        /data/data/com.termux/*:*|*:*?*)
            printf '%s\n' 'Android runtime consumer cannot be selected as a build workbench' >&2
            return 2 ;;
    esac
    cf_model=$(catfood_android_getprop ro.product.model 2>/dev/null || :)
    if [ -n "$cf_model" ] || [ "$(uname -s)" != Linux ] ||
        ! grep -Eq '^ID=("?(debian|ubuntu)"?)$' /etc/os-release; then
        printf '%s\n' 'workbench target requires observed Debian/Ubuntu Linux host' >&2
        return 2
    fi
}
catfood_android_device_id() {
    # Local per-installation identity, shared with inventory; never copy between
    # handsets. This alias is not a hardware serial or attestation.
    cf_id_file=${CATFOOD_DEVICE_ID_FILE:-${CATFOOD_DEVICE_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/catfood/device}/device-id}
    cf_id=${CATFOOD_DEVICE_ID:-}
    if [ -z "$cf_id" ] && [ -r "$cf_id_file" ]; then cf_id=$(cat "$cf_id_file"); fi
    if [ -z "$cf_id" ]; then
        [ -r /proc/sys/kernel/random/uuid ] || return 2
        cf_id=$(cat /proc/sys/kernel/random/uuid)
        (umask 077; mkdir -p "$(dirname -- "$cf_id_file")"; printf '%s\n' "$cf_id" > "$cf_id_file")
    fi
    case $cf_id in ''|-|*[!a-zA-Z0-9_.-]*) return 2 ;; esac
    printf '%s\n' "$cf_id"
}

# Narrow command interface for post-bootstrap consumers in other languages.
# Sourcing this stage-zero library still defines functions only.
if [ "${0##*/}" = target.sh ]; then
    [ "$#" -eq 2 ] || { printf '%s\n' 'usage: target.sh device-id|expected-abi phone|c67|tablet' >&2; exit 2; }
    case $1 in
        device-id)
            catfood_android_require_device "$2" || exit 2
            catfood_android_device_id || exit 2
            ;;
        expected-abi) catfood_android_expected_abi "$2" || exit 2 ;;
        *) printf '%s\n' 'unknown target oracle operation' >&2; exit 2 ;;
    esac
fi
