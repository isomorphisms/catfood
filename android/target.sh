#!/bin/sh
# Shared Android device/ABI target selection.
#
# Physical device identity is distinct from the package lane:
# phone  -> armeabi-v7a package lane
# tablet -> arm64-v8a package lane
# c67    -> physical MIRO C67, consuming the arm64-v8a/tablet package lane

catfood_android_getprop() {
    property=$1
    if command -v getprop >/dev/null 2>&1; then
        getprop "$property" 2>/dev/null | tr -d '\r'
    elif [ -x /system/bin/getprop ]; then
        /system/bin/getprop "$property" 2>/dev/null | tr -d '\r'
    else
        return 1
    fi
}

catfood_detect_android_target() {
    machine=$(uname -m 2>/dev/null || printf '%s\n' unknown)
    case $machine in
        armv7*|armv8l|arm)
            printf '%s\n' phone
            ;;
        aarch64|arm64)
            product_device=$(catfood_android_getprop ro.product.device || :)
            product_model=$(catfood_android_getprop ro.product.model || :)
            case "$product_device:$product_model" in
                Miro_C67:*|*:Miro\ C67) printf '%s\n' c67 ;;
                *) printf '%s\n' tablet ;;
            esac
            ;;
        *)
            printf '%s\n' termux
            ;;
    esac
}

catfood_detect_target() {
    case ${PREFIX:-}:${TERMUX_VERSION:-} in
        /data/data/com.termux/*:*|*:*?*) catfood_detect_android_target ;;
        *) printf '%s\n' cloud ;;
    esac
}

catfood_android_delivery_target() {
    case $1 in
        phone) printf '%s\n' phone ;;
        c67|tablet) printf '%s\n' tablet ;;
        *) return 2 ;;
    esac
}

catfood_android_expected_abi() {
    case $1 in
        phone) printf '%s\n' armeabi-v7a ;;
        c67|tablet) printf '%s\n' arm64-v8a ;;
        *) return 2 ;;
    esac
}

catfood_android_verify_device_target() {
    requested=$1
    case $requested in
        c67)
            product_device=$(catfood_android_getprop ro.product.device || :)
            product_model=$(catfood_android_getprop ro.product.model || :)
            case "$product_device:$product_model" in
                Miro_C67:*|*:Miro\ C67) return 0 ;;
            esac
            printf 'Cat Food c67 target requires physical MIRO C67 identity; found device=%s model=%s\n' \
                "${product_device:-unknown}" "${product_model:-unknown}" >&2
            return 2
            ;;
        phone|tablet)
            return 0
            ;;
        *)
            return 2
            ;;
    esac
}
