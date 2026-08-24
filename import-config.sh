#!/bin/sh
set -eu

source_dir=${CATFOOD_CONFIG_DIR:-${1:-}}
config_home=${XDG_CONFIG_HOME:-$HOME/.config}

if [ -z "$source_dir" ]; then
    printf '%s\n' 'usage: CATFOOD_CONFIG_DIR=/path/to/private-config ./import-config.sh' >&2
    printf '%s\n' 'expected optional files: az/amazon-secret and az/abebooks-impact' >&2
    exit 2
fi

if [ ! -d "$source_dir" ]; then
    printf 'cat food config source is not a directory: %s\n' "$source_dir" >&2
    exit 1
fi

umask 077
mkdir -p "$config_home/az"
imported=0

import_one() {
    name=$1
    src=$source_dir/az/$name
    [ -f "$src" ] || src=$source_dir/$name
    [ -f "$src" ] || return 0

    dst=$config_home/az/$name
    tmp=$dst.tmp.$$
    cp "$src" "$tmp"
    chmod 600 "$tmp"
    mv "$tmp" "$dst"
    printf 'imported %s\n' "$dst"
    imported=1
}

import_one amazon-secret
import_one abebooks-impact

if [ "$imported" -eq 0 ]; then
    printf '%s\n' 'no supported Cat Food config files found' >&2
    exit 1
fi
