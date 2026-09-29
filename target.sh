#!/bin/sh

catfood_detect_target() {
    case ${PREFIX:-}:${TERMUX_VERSION:-} in
        /data/data/com.termux/*:*|*:*?*)
            machine=$(uname -m 2>/dev/null || printf '%s\n' unknown)
            case $machine in
                armv7*|armv8l|arm) printf '%s\n' phone ;;
                aarch64|arm64) printf '%s\n' tablet ;;
                *) printf '%s\n' termux ;;
            esac
            return 0
            ;;
    esac

    system=$(uname -s 2>/dev/null || printf '%s\n' unknown)
    case $system in
        NetBSD)
            machine=$(uname -m 2>/dev/null || printf '%s\n' unknown)
            case $machine in
                amd64|x86_64) printf '%s\n' netbsd ;;
                *)
                    printf 'unsupported NetBSD architecture: %s\n' "$machine" >&2
                    return 2
                    ;;
            esac
            ;;
        Linux)
            os_release=${CATFOOD_OS_RELEASE:-/etc/os-release}
            [ -r "$os_release" ] || {
                printf 'cat food cannot identify Linux distribution: %s is not readable\n' "$os_release" >&2
                return 2
            }
            os_id=$(awk -F= '$1 == "ID" { print $2; exit }' "$os_release")
            case $os_id in
                \"*\") os_id=${os_id#\"}; os_id=${os_id%\"} ;;
            esac
            case $os_id in
                debian|ubuntu) printf '%s\n' cloud ;;
                *)
                    printf 'unsupported Linux distribution: %s\n' "${os_id:-unknown}" >&2
                    return 2
                    ;;
            esac
            ;;
        *)
            printf 'unsupported operating system: %s\n' "$system" >&2
            return 2
            ;;
    esac
}

catfood_normalize_target() {
    case $1 in
        hetzner) printf '%s\n' cloud ;;
        phone|tablet|container|cloud|termux|netbsd|sdf) printf '%s\n' "$1" ;;
        *)
            printf 'CATFOOD_TARGET must be phone, tablet, container, cloud, termux, netbsd, sdf, or hetzner; found: %s\n' "$1" >&2
            return 2
            ;;
    esac
}
