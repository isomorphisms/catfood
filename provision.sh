#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
workspace=${CATFOOD_ROOT:-/opt}
cache=${CATFOOD_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/catfood}
oils_version=${CATFOOD_OILS_VERSION:-0.37.0}
oils_sha256=${CATFOOD_OILS_SHA256:-f4d41d20a0523dbcfbd4ba231f82edf25b08d4965d65bc71fcb56666d6743000}

if [ -n "${CATFOOD_PREFIX:-}" ]; then
    prefix=$CATFOOD_PREFIX
elif [ "$(id -u)" -eq 0 ]; then
    prefix=/usr/local
else
    prefix=$HOME/.local
fi

as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        printf 'cat food needs root or sudo for: %s\n' "$*" >&2
        return 1
    fi
}

install_packages() {
    if [ "${CATFOOD_NO_PACKAGES:-0}" = 1 ]; then
        return 0
    fi

    if command -v apt-get >/dev/null 2>&1; then
        as_root apt-get update
        as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
            bash build-essential ca-certificates cmake curl espeak-ng ffmpeg gfortran git jq \
            libbz2-dev libcurl4-openssl-dev libdeflate-dev libexpat1-dev libffi-dev \
            libgdbm-dev libgmp-dev liblzma-dev libncurses-dev libpcre2-dev libreadline-dev \
            libsqlite3-dev libssl-dev make ninja-build openjdk-17-jdk-headless perl \
            pkg-config python3-venv rsync tk-dev tmux texinfo unzip uuid-dev vim w3m \
            xz-utils zlib1g-dev

        # PDF image/figure extraction candidates; leave disabled until one is chosen.
        # apt-get install -y poppler-utils  # pdfimages
        # apt-get install -y mupdf-tools  # mutool extract
        # apt-get install -y libpoppler-private-dev libleptonica-dev  # build AllenAI pdffigures v1 from source
        # PDFFigures2 itself is not packaged by Debian; use its upstream Scala/sbt build.
    else
        printf '%s\n' 'cat food: no apt-get; expecting build dependencies to already exist' >&2
    fi
}

install_ysh() {
    if command -v ysh >/dev/null 2>&1 && ysh -c 'echo' >/dev/null 2>&1; then
        return 0
    fi

    command -v curl >/dev/null 2>&1 || {
        printf '%s\n' 'cat food needs curl to install YSH' >&2
        exit 127
    }
    command -v sha256sum >/dev/null 2>&1 || {
        printf '%s\n' 'cat food needs sha256sum to verify YSH' >&2
        exit 127
    }

    mkdir -p "$cache" "$prefix"
    archive=$cache/oils-for-unix-$oils_version.tar.gz
    source_dir=$cache/oils-for-unix-$oils_version
    url=https://oils.pub/download/oils-for-unix-$oils_version.tar.gz

    if [ ! -f "$archive" ] || ! printf '%s  %s\n' "$oils_sha256" "$archive" | sha256sum -c - >/dev/null 2>&1; then
        rm -f "$archive.tmp"
        curl -fL "$url" -o "$archive.tmp"
        printf '%s  %s\n' "$oils_sha256" "$archive.tmp" | sha256sum -c -
        mv "$archive.tmp" "$archive"
    fi

    rm -rf "$source_dir"
    tar --no-same-owner -xzf "$archive" -C "$cache"

    (
        cd "$source_dir"
        ./configure --prefix "$prefix" --datarootdir "$prefix/share"
        _build/oils.sh
        if [ -w "$prefix" ]; then
            ./install
        else
            as_root ./install
        fi
    )

    "$prefix/bin/ysh" -c 'echo' >/dev/null
}

install_packages
install_ysh

if [ -n "${CATFOOD_CONFIG_DIR:-}" ]; then
    CATFOOD_CONFIG_DIR=$CATFOOD_CONFIG_DIR sh "$root/import-config.sh"
fi

PATH=$prefix/bin:$workspace/bin:$PATH
export PATH

CATFOOD_ROOT=$workspace CATFOOD_PREFIX=$prefix \
    sh "$root/refresh.sh"
