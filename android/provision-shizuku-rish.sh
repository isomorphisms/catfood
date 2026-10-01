#!/bin/sh
set -eu

red='\033[1;31m'
green='\033[1;32m'
cyan='\033[1;36m'
yellow='\033[1;33m'
reset='\033[0m'

section() { printf '\n%b== %s ==%b\n' "$cyan" "$1" "$reset"; }
pass() { printf '%bPASS%b %s\n' "$green" "$reset" "$1"; }
warn() { printf '%bWARN%b %s\n' "$yellow" "$reset" "$1" >&2; }
fail() { printf '%bFAIL%b %s\n' "$red" "$reset" "$1" >&2; exit 1; }

usage() {
    cat <<'EOF_USAGE'
usage: provision-shizuku-rish.sh [--dry-run|--apply]

Provision Shizuku's rish launcher for Termux without depending on removable
storage. The default is a dry run.

Source order:
  1. CATFOOD_SHIZUKU_SOURCE_DIR, when explicitly set
  2. assets from the installed Shizuku manager APK, when readable
  3. Shizuku's shared-storage export under internal /storage/emulated/0

Destination defaults to ~/opt with a ~/opt/bin/rish wrapper.
EOF_USAGE
}

mode=dry_run
while [ "$#" -gt 0 ]; do
    case $1 in
        --dry-run) mode=dry_run ;;
        --apply) mode=apply ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; fail "unknown option: $1" ;;
    esac
    shift
done

: "${HOME:?HOME is required}"
install_dir=${CATFOOD_SHIZUKU_INSTALL_DIR:-${CATFOOD_ROOT:-"$HOME/opt"}}
bin_dir=${CATFOOD_SHIZUKU_BIN_DIR:-"$HOME/opt/bin"}
state_home=${CATFOOD_STATE_HOME:-${XDG_STATE_HOME:-"$HOME/.local/state"}/catfood}
state_dir=$state_home/shizuku
manager_package=${CATFOOD_SHIZUKU_PACKAGE:-moe.shizuku.privileged.api}
application_id=${CATFOOD_SHIZUKU_APPLICATION_ID:-com.termux}

case $application_id in
    ''|*[!A-Za-z0-9._-]*) fail "invalid Shizuku terminal application id: $application_id" ;;
esac

temporary=
cleanup() {
    [ -z "$temporary" ] || rm -rf "$temporary"
}
trap cleanup EXIT HUP INT TERM

make_temporary() {
    [ -n "$temporary" ] && return 0
    temporary_base=${TMPDIR:-"$HOME/.cache"}
    mkdir -p "$temporary_base"
    temporary=$(mktemp -d "$temporary_base/catfood-shizuku.XXXXXX")
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
        return 2
    fi
    return 1
}

find_pm() {
    if [ -n "${CATFOOD_PM:-}" ]; then
        printf '%s\n' "$CATFOOD_PM"
        return 0
    fi
    if [ -x /system/bin/pm ]; then
        printf '%s\n' /system/bin/pm
        return 0
    fi
    command -v pm 2>/dev/null || return 1
}

find_unzip() {
    if [ -n "${CATFOOD_UNZIP:-}" ]; then
        printf '%s\n' "$CATFOOD_UNZIP"
        return 0
    fi
    command -v unzip 2>/dev/null || return 1
}

installed_apk() {
    pm_command=$(find_pm || true)
    [ -n "$pm_command" ] || return 1
    apk=$($pm_command path "$manager_package" 2>/dev/null \
        | tr -d '\r' \
        | sed -n 's/^package://p' \
        | sed -n '1p')
    [ -n "$apk" ] && [ -r "$apk" ] || return 1
    printf '%s\n' "$apk"
}

extract_installed_assets() {
    apk=$1
    unzip_command=$(find_unzip || true)
    [ -n "$unzip_command" ] || return 1
    make_temporary
    extracted=$temporary/installed
    mkdir -p "$extracted"
    "$unzip_command" -p "$apk" assets/rish > "$extracted/rish" 2>/dev/null || return 1
    "$unzip_command" -p "$apk" assets/rish_shizuku.dex > "$extracted/rish_shizuku.dex" 2>/dev/null || return 1
    [ -s "$extracted/rish" ] && [ -s "$extracted/rish_shizuku.dex" ] || return 1
    source_dir=$extracted
    return 0
}

source_kind=
source_path=
source_dir=
choose_source() {
    if [ -n "${CATFOOD_SHIZUKU_SOURCE_DIR:-}" ]; then
        status=0
        pair_state "$CATFOOD_SHIZUKU_SOURCE_DIR" || status=$?
        case $status in
            0)
                source_kind=explicit-export
                source_path=$CATFOOD_SHIZUKU_SOURCE_DIR
                source_dir=$CATFOOD_SHIZUKU_SOURCE_DIR
                return 0
                ;;
            2) fail "incomplete Shizuku rish pair in $CATFOOD_SHIZUKU_SOURCE_DIR" ;;
            *) fail "Shizuku rish pair not found in CATFOOD_SHIZUKU_SOURCE_DIR=$CATFOOD_SHIZUKU_SOURCE_DIR" ;;
        esac
    fi

    apk=$(installed_apk || true)
    if [ -n "$apk" ]; then
        if extract_installed_assets "$apk"; then
            source_kind=installed-apk
            source_path=$apk
            return 0
        fi
        warn "Shizuku is installed at $apk but its rish assets could not be extracted"
    fi

    for candidate in "$HOME/storage/shared/Shizuku" /storage/emulated/0/Shizuku; do
        status=0
        pair_state "$candidate" || status=$?
        case $status in
            0)
                source_kind=shared-export
                source_path=$candidate
                source_dir=$candidate
                return 0
                ;;
            2) fail "incomplete Shizuku rish pair in $candidate" ;;
        esac
    done
    return 1
}

sha256_file() {
    file=$1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
        return
    fi
    if [ -x /system/bin/toybox ]; then
        /system/bin/toybox sha256sum "$file" | awk '{print $1}'
        return
    fi
    printf '%s\n' unavailable
}

prepare_launcher() {
    input=$1
    output=$2
    if grep -F 'RISH_APPLICATION_ID="PKG"' "$input" >/dev/null 2>&1; then
        sed "s/RISH_APPLICATION_ID=\"PKG\"/RISH_APPLICATION_ID=\"$application_id\"/" "$input" > "$output"
        return 0
    fi
    if grep -F "RISH_APPLICATION_ID=\"$application_id\"" "$input" >/dev/null 2>&1; then
        cat "$input" > "$output"
        return 0
    fi
    fail "rish launcher does not contain the expected Shizuku RISH_APPLICATION_ID assignment"
}

write_wrapper() {
    wrapper=$1
    case $install_dir in
        *"'"*) fail "Shizuku install path contains an unsupported single quote: $install_dir" ;;
    esac
    {
        printf '%s\n' '#!/system/bin/sh'
        printf '%s\n' '# catfood shizuku rish wrapper'
        printf "exec /system/bin/sh '%s/rish' \"\$@\"\n" "$install_dir"
    } > "$wrapper"
}

probe_runtime() {
    [ "${CATFOOD_SHIZUKU_SKIP_RUNTIME_PROBE:-0}" != 1 ] || {
        printf 'shizuku_rish_runtime\tnot-probed\n'
        return 0
    }

    runner=$bin_dir/rish
    output=
    status=0
    if command -v timeout >/dev/null 2>&1; then
        output=$(timeout 8 "$runner" -c 'id -u' 2>&1) || status=$?
    else
        output=$("$runner" -c 'id -u' 2>&1) || status=$?
    fi
    if [ "$status" -eq 0 ] && printf '%s\n' "$output" | grep -Fx 2000 >/dev/null 2>&1; then
        pass 'rish reached Shizuku shell uid 2000'
        printf 'shizuku_rish_runtime\tPASS\tuid=2000\n'
        return 0
    fi

    first_line=$(printf '%s\n' "$output" | sed -n '1p')
    warn 'rish files are installed but the Shizuku shell is not reachable yet; pair/start Shizuku and rerun this pass'
    printf 'shizuku_rish_runtime\tpending\tstatus=%s\t%s\n' "$status" "$first_line"
    return 0
}

section 'Shizuku rish provisioning'
printf 'mode=%s\n' "$mode"
printf 'install_dir=%s\n' "$install_dir"
printf 'bin_dir=%s\n' "$bin_dir"
printf 'removable_storage=not_required\n'

if ! choose_source; then
    warn 'No usable Shizuku rish source is visible yet. Cat Food checked the installed Shizuku APK and internal shared-storage export; removable SD storage is not involved.'
    printf 'shizuku_rish\tpending\tsource=unavailable\n'
    exit 0
fi

printf 'source_kind=%s\n' "$source_kind"
printf 'source=%s\n' "$source_path"

make_temporary
prepared=$temporary/prepared
mkdir -p "$prepared"
prepare_launcher "$source_dir/rish" "$prepared/rish"
cp "$source_dir/rish_shizuku.dex" "$prepared/rish_shizuku.dex"
chmod 0500 "$prepared/rish"
chmod 0400 "$prepared/rish_shizuku.dex"

rish_sha=$(sha256_file "$prepared/rish")
dex_sha=$(sha256_file "$prepared/rish_shizuku.dex")

if [ "$mode" = dry_run ]; then
    printf 'would_install_rish\t%s\trish_sha256=%s\tdex_sha256=%s\n' "$install_dir" "$rish_sha" "$dex_sha"
    printf 'would_install_rish_wrapper\t%s/rish\n' "$bin_dir"
    pass 'Shizuku rish source is provisionable'
    exit 0
fi

mkdir -p "$install_dir" "$bin_dir" "$state_dir"

if [ -e "$bin_dir/rish" ] && ! grep -F '# catfood shizuku rish wrapper' "$bin_dir/rish" >/dev/null 2>&1; then
    fail "$bin_dir/rish already exists and is not Cat Food's Shizuku wrapper"
fi

rish_tmp=$install_dir/.rish.catfood.$$
dex_tmp=$install_dir/.rish_shizuku.dex.catfood.$$
wrapper_tmp=$bin_dir/.rish.catfood.$$
receipt_tmp=$state_dir/.installed.tsv.$$
cp "$prepared/rish" "$rish_tmp"
cp "$prepared/rish_shizuku.dex" "$dex_tmp"
chmod 0500 "$rish_tmp"
chmod 0400 "$dex_tmp"
write_wrapper "$wrapper_tmp"
chmod 0500 "$wrapper_tmp"

mv "$rish_tmp" "$install_dir/rish"
mv "$dex_tmp" "$install_dir/rish_shizuku.dex"
mv "$wrapper_tmp" "$bin_dir/rish"

{
    printf 'schema\tcatfood-shizuku-install-v1\n'
    printf 'manager_package\t%s\n' "$manager_package"
    printf 'application_id\t%s\n' "$application_id"
    printf 'source_kind\t%s\n' "$source_kind"
    printf 'source\t%s\n' "$source_path"
    printf 'install_dir\t%s\n' "$install_dir"
    printf 'rish_sha256\t%s\n' "$rish_sha"
    printf 'dex_sha256\t%s\n' "$dex_sha"
} > "$receipt_tmp"
chmod 0600 "$receipt_tmp"
mv "$receipt_tmp" "$state_dir/installed.tsv"

pass "Installed Shizuku rish pair in $install_dir"
pass "Installed stable rish command at $bin_dir/rish"
probe_runtime
