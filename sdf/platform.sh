#!/bin/sh

catfood_sdf_system() {
    uname -s 2>/dev/null || printf '%s\n' unknown
}

catfood_sdf_machine() {
    uname -m 2>/dev/null || printf '%s\n' unknown
}

catfood_sdf_require_platform() {
    system=$(catfood_sdf_system)
    machine=$(catfood_sdf_machine)

    if [ "$system" != NetBSD ]; then
        printf 'cat food sdf requires NetBSD; found: %s\n' "$system" >&2
        return 2
    fi

    case $machine in
        amd64|x86_64) ;;
        *)
            printf 'cat food sdf currently requires amd64/x86_64; found: %s\n' "$machine" >&2
            return 2
            ;;
    esac
}

catfood_sdf_choose_downloader() {
    requested=${CATFOOD_SDF_DOWNLOADER:-}
    if [ -n "$requested" ]; then
        case $requested in
            ftp|curl|wget) ;;
            *)
                printf 'unsupported CATFOOD_SDF_DOWNLOADER: %s\n' "$requested" >&2
                return 2
                ;;
        esac
        command -v "$requested" >/dev/null 2>&1 || {
            printf 'requested downloader is not installed: %s\n' "$requested" >&2
            return 127
        }
        printf '%s\n' "$requested"
        return 0
    fi

    for candidate in ftp curl wget; do
        if command -v "$candidate" >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    printf '%s\n' 'cat food sdf needs one of: ftp, curl, wget' >&2
    return 127
}

catfood_sdf_sha256_backend() {
    if command -v sha256 >/dev/null 2>&1; then
        printf '%s\n' sha256
    elif command -v cksum >/dev/null 2>&1; then
        printf '%s\n' cksum
    elif command -v sha256sum >/dev/null 2>&1; then
        printf '%s\n' sha256sum
    elif command -v openssl >/dev/null 2>&1; then
        printf '%s\n' openssl
    else
        printf '%s\n' 'cat food sdf needs sha256, cksum, sha256sum, or openssl' >&2
        return 127
    fi
}

catfood_sdf_sha256() {
    file=$1
    backend=$(catfood_sdf_sha256_backend) || return $?
    case $backend in
        sha256) sha256 -q "$file" ;;
        cksum) cksum -a SHA256 -q "$file" ;;
        sha256sum) sha256sum "$file" | awk '{print $1}' ;;
        openssl) openssl dgst -sha256 "$file" | awk '{print $NF}' ;;
    esac
}

catfood_sdf_download() {
    url=$1
    output=$2

    case $url in
        file://*)
            cp "${url#file://}" "$output"
            return
            ;;
    esac

    downloader=$(catfood_sdf_choose_downloader) || return $?
    case $downloader in
        ftp) ftp -o "$output" "$url" ;;
        curl) curl -fL "$url" -o "$output" ;;
        wget) wget -O "$output" "$url" ;;
    esac
}
