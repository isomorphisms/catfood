#!/bin/sh
set -eu

workspace=${CATFOOD_ROOT:-"$HOME/opt"}
state_home=${CATFOOD_STATE_HOME:-${XDG_STATE_HOME:-"$HOME/.local/state"}/catfood}
state_dir=${CATFOOD_SHIZUKU_STATE_DIR:-"$state_home/shizuku"}
action=${1:-save}

sha256_file() {
    file=$1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{ print $1 }'
        return
    fi
    toybox=${CATFOOD_TOYBOX:-/system/bin/toybox}
    if [ -x "$toybox" ]; then
        "$toybox" sha256sum "$file" | awk '{ print $1 }'
        return
    fi
    printf '%s\n' 'Cat Food needs SHA-256 to preserve Shizuku state' >&2
    return 127
}

pair_state() {
    directory=$1
    have_rish=0
    have_dex=0
    [ -f "$directory/rish" ] && have_rish=1
    [ -f "$directory/rish_shizuku.dex" ] && have_dex=1

    if [ "$have_rish" -eq 1 ] && [ "$have_dex" -eq 1 ]; then
        return 0
    fi
    if [ "$have_rish" -ne "$have_dex" ]; then
        printf 'incomplete Shizuku rish bundle in %s; need both rish and rish_shizuku.dex\n' "$directory" >&2
        return 2
    fi
    return 1
}

find_source_dir() {
    if [ -n "${CATFOOD_SHIZUKU_RISH_DIR:-}" ]; then
        if pair_state "$CATFOOD_SHIZUKU_RISH_DIR"; then
            printf '%s\n' "$CATFOOD_SHIZUKU_RISH_DIR"
            return 0
        else
            return $?
        fi
    fi

    if pair_state "$workspace"; then
        printf '%s\n' "$workspace"
        return 0
    else
        status=$?
        [ "$status" -ne 2 ] || return 2
    fi

    rish_path=$(command -v rish 2>/dev/null || true)
    if [ -n "$rish_path" ]; then
        case $rish_path in
            */*) rish_dir=${rish_path%/*} ;;
            *) rish_dir=. ;;
        esac
        if pair_state "$rish_dir"; then
            CDPATH='' cd -- "$rish_dir" && pwd -P
            return 0
        else
            status=$?
            [ "$status" -ne 2 ] || return 2
        fi
    fi

    if [ "$workspace" != "$HOME" ]; then
        if pair_state "$HOME"; then
            printf '%s\n' "$HOME"
            return 0
        else
            status=$?
            [ "$status" -ne 2 ] || return 2
        fi
    fi

    return 1
}

save_bundle() {
    if source_dir=$(find_source_dir); then
        :
    else
        status=$?
        if [ "$status" -eq 1 ]; then
            printf '%s\n' 'Cat Food Shizuku state: no rish bundle found; nothing to preserve'
            return 0
        fi
        return "$status"
    fi

    rish_sha=$(sha256_file "$source_dir/rish")
    dex_sha=$(sha256_file "$source_dir/rish_shizuku.dex")
    short_rish=$(printf '%s\n' "$rish_sha" | cut -c1-16)
    short_dex=$(printf '%s\n' "$dex_sha" | cut -c1-16)
    snapshot_id=$short_rish-$short_dex
    snapshots=$state_dir/snapshots
    snapshot=$snapshots/$snapshot_id

    umask 077
    mkdir -p "$snapshots"

    if [ ! -d "$snapshot" ]; then
        staging=$state_dir/.snapshot.$$
        rm -rf "$staging"
        trap 'rm -rf "$staging"' EXIT HUP INT TERM
        mkdir -p "$staging"

        cp "$source_dir/rish" "$staging/rish"
        cp "$source_dir/rish_shizuku.dex" "$staging/rish_shizuku.dex"
        chmod 0500 "$staging/rish"
        chmod 0400 "$staging/rish_shizuku.dex"

        {
            printf 'schema\tcatfood-shizuku-state-v1\n'
            printf 'scope\trish-bundle\n'
            printf 'manager_package\tmoe.shizuku.privileged.api\n'
            printf 'source_dir\t%s\n' "$source_dir"
            printf 'rish_sha256\t%s\n' "$rish_sha"
            printf 'dex_sha256\t%s\n' "$dex_sha"
        } > "$staging/receipt.tsv"

        mv "$staging" "$snapshot"
        trap - EXIT HUP INT TERM
    fi

    printf '%s\n' "$snapshot_id" > "$state_dir/current.tmp.$$"
    mv "$state_dir/current.tmp.$$" "$state_dir/current"
    printf 'Cat Food preserved Shizuku rish bundle: %s\n' "$snapshot"
}

restore_bundle() {
    destination=${2:-${CATFOOD_SHIZUKU_RESTORE_DIR:-"$workspace"}}

    [ -f "$state_dir/current" ] || {
        printf 'Cat Food has no preserved Shizuku rish bundle under %s\n' "$state_dir" >&2
        return 1
    }
    snapshot_id=$(cat "$state_dir/current")
    case $snapshot_id in
        ''|*/*|*..*)
            printf 'invalid Cat Food Shizuku snapshot id: %s\n' "$snapshot_id" >&2
            return 2
            ;;
    esac
    snapshot=$state_dir/snapshots/$snapshot_id
    [ -f "$snapshot/rish" ] && [ -f "$snapshot/rish_shizuku.dex" ] || {
        printf 'Cat Food Shizuku snapshot is incomplete: %s\n' "$snapshot" >&2
        return 1
    }

    umask 077
    mkdir -p "$destination"
    cp "$snapshot/rish" "$destination/.rish.catfood.$$"
    cp "$snapshot/rish_shizuku.dex" "$destination/.rish_shizuku.dex.catfood.$$"
    chmod 0500 "$destination/.rish.catfood.$$"
    chmod 0400 "$destination/.rish_shizuku.dex.catfood.$$"
    mv "$destination/.rish.catfood.$$" "$destination/rish"
    mv "$destination/.rish_shizuku.dex.catfood.$$" "$destination/rish_shizuku.dex"

    printf 'Cat Food restored Shizuku rish bundle to %s\n' "$destination"
}

case "$action" in
    save)
        [ "$#" -eq 1 ] || { printf 'usage: %s save | restore [DIRECTORY]\n' "$0" >&2; exit 2; }
        save_bundle
        ;;
    restore)
        [ "$#" -le 2 ] || { printf 'usage: %s save | restore [DIRECTORY]\n' "$0" >&2; exit 2; }
        restore_bundle "$@"
        ;;
    *)
        printf 'usage: %s save | restore [DIRECTORY]\n' "$0" >&2
        exit 2
        ;;
esac
