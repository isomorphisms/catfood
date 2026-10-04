#!/bin/sh
set -eu

# Cat Food Crawl Space phone bootstrap.
# The phone consumes a published binary; this script never builds Crawl Space.

workspace=${CATFOOD_ROOT:-"$HOME/opt"}
client=${CATFOOD_CRAWLSPACE:-"$workspace/bin/crawlspace"}
adb_command=${CATFOOD_ADB:-adb}
remote=${CATFOOD_CRAWLSPACE_REMOTE:-/data/local/tmp/crawlspace}
port=${CRAWLSPACE_PORT:-49317}
expected_build_id=${CATFOOD_CRAWLSPACE_BUILD_ID:-94f475dcad4f1661c5a638e9d24fe8fb22b3a279}
optional=0

case ${1:-} in
    '') ;;
    --if-connected) optional=1 ;;
    *)
        printf 'usage: crawlspace-bootstrap [--if-connected]\n' >&2
        exit 2
        ;;
esac

if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ]; then
    esc=$(printf '\033')
    cyan="$esc[36m"
    yellow="$esc[33m"
    green="$esc[32m"
    red="$esc[31m"
    reset="$esc[0m"
else
    cyan= yellow= green= red= reset=
fi

section() {
    printf '%s== %s ==%s\n' "$cyan" "$*" "$reset"
}

attention() {
    printf '%s%s%s\n' "$yellow" "$*" "$reset"
}

pass() {
    printf '%sPASS:%s %s\n' "$green" "$reset" "$*"
}

fail() {
    printf '%sFAIL:%s %s\n' "$red" "$reset" "$*" >&2
}

have_command() {
    case $1 in
        */*) [ -x "$1" ] ;;
        *) command -v "$1" >/dev/null 2>&1 ;;
    esac
}

line_present() {
    value=$1
    wanted=$2
    if command -v grep >/dev/null 2>&1; then
        printf '%s\n' "$value" | grep -Fqx "$wanted"
    elif [ -x /system/bin/toybox ]; then
        printf '%s\n' "$value" | /system/bin/toybox grep -Fqx "$wanted"
    else
        return 1
    fi
}

strip_crlf() {
    if command -v tr >/dev/null 2>&1; then
        tr -d '\r\n'
    elif [ -x /system/bin/toybox ]; then
        /system/bin/toybox tr -d '\r\n'
    else
        cat
    fi
}

resolve_payload() {
    candidate=$1
    resolved=
    if command -v readlink >/dev/null 2>&1; then
        resolved=$(readlink -f "$candidate" 2>/dev/null || true)
    elif [ -x /system/bin/toybox ]; then
        resolved=$(/system/bin/toybox readlink -f "$candidate" 2>/dev/null || true)
    fi
    if [ -n "$resolved" ]; then
        printf '%s\n' "$resolved"
    else
        printf '%s\n' "$candidate"
    fi
}

crawlspace_ready() {
    discovery=$("$client" discover 2>/dev/null) || return 1
    line_present "$discovery" 'status=ready' || return 1
    line_present "$discovery" 'daemon_uid=2000' || return 1
    line_present "$discovery" 'capability=crawlspace.runtime-identity.v1' || return 1

    identity=$("$client" identify 2>/dev/null) || return 1
    line_present "$identity" 'status=ready' || return 1
    line_present "$identity" 'daemon_uid=2000' || return 1
    line_present "$identity" 'daemon_authority=shell' || return 1
    line_present "$identity" 'daemon_role=native-command-bridge' || return 1
    line_present "$identity" "build_id=$expected_build_id" || return 1
    return 0
}

[ -x "$client" ] || {
    fail "Crawl Space runtime is not installed at $client"
    exit 3
}

version=$("$client" --version 2>/dev/null || true)
if [ "$version" != 'crawlspace transport=2 discovery=1' ]; then
    fail "unexpected Crawl Space runtime: ${version:-no version response}"
    exit 3
fi

section 'Crawl Space'
if crawlspace_ready; then
    pass 'shell daemon is already ready; ADB is not needed'
    exit 0
fi

if ! have_command "$adb_command"; then
    if [ "$optional" -eq 1 ]; then
        attention 'PENDING: Crawl Space is installed, but ADB is unavailable for this post-reboot bootstrap.'
        exit 0
    fi
    fail 'ADB is required once after reboot to start the shell daemon.'
    exit 127
fi

adb_state=$("$adb_command" get-state 2>/dev/null || true)
if [ "$adb_state" != device ]; then
    if [ "$optional" -eq 1 ]; then
        attention 'PENDING: Crawl Space is installed; connect Wireless debugging once to start its shell daemon.'
        exit 0
    fi
    fail 'ADB has no connected device. Connect Wireless debugging, then rerun crawlspace-bootstrap.'
    exit 69
fi

config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/crawlspace
token_file=$config_dir/token
mkdir -p "$config_dir"
chmod 700 "$config_dir"

if [ ! -s "$token_file" ]; then
    umask 077
    temporary_token=$token_file.tmp.$$
    rm -f "$temporary_token"
    if [ -x /system/bin/toybox ]; then
        /system/bin/toybox dd if=/dev/urandom of="$temporary_token" bs=32 count=1 2>/dev/null
    elif command -v dd >/dev/null 2>&1; then
        dd if=/dev/urandom of="$temporary_token" bs=32 count=1 2>/dev/null
    else
        fail 'no byte-copy command is available to create the authentication token'
        exit 127
    fi
    [ -s "$temporary_token" ] || {
        rm -f "$temporary_token"
        fail 'authentication token generation failed'
        exit 1
    }
    mv "$temporary_token" "$token_file"
fi
chmod 600 "$token_file"

payload=$(resolve_payload "$client")
[ -f "$payload" ] || {
    fail "Crawl Space runtime payload is missing: $payload"
    exit 3
}

attention 'Starting the shell daemon through the existing ADB connection.'
"$adb_command" shell "mkdir -p '$remote' && chmod 700 '$remote'" >/dev/null

old_pid=$("$adb_command" shell "cat '$remote/pid' 2>/dev/null || true" 2>/dev/null | strip_crlf)
case "$old_pid" in
    ''|*[!0-9]*) ;;
    *)
        old_exe=$("$adb_command" shell "/system/bin/toybox readlink '/proc/$old_pid/exe' 2>/dev/null || true" 2>/dev/null | strip_crlf)
        if [ "$old_exe" = "$remote/crawlspace" ]; then
            "$adb_command" shell "kill '$old_pid' 2>/dev/null || true" >/dev/null
        fi
        ;;
esac

"$adb_command" push "$payload" "$remote/crawlspace" >/dev/null
"$adb_command" push "$token_file" "$remote/token" >/dev/null
"$adb_command" shell "chmod 500 '$remote/crawlspace'; chmod 400 '$remote/token'" >/dev/null
"$adb_command" shell "cd '$remote'; ./crawlspace serve ./token '$port' >server.log 2>&1 </dev/null & echo \$! >pid" >/dev/null

attempt=0
while [ "$attempt" -lt 5 ]; do
    if crawlspace_ready; then
        identity=$("$client" run /system/bin/id 2>/dev/null || true)
        case "$identity" in
            *'uid=2000(shell)'*)
                pass "Crawl Space is executing as Android shell (uid 2000), build $expected_build_id."
                exit 0
                ;;
        esac
    fi
    attempt=$((attempt + 1))
    sleep 1
done

fail 'Crawl Space daemon did not become ready.'
"$adb_command" shell "cat '$remote/server.log' 2>/dev/null || true" >&2 || true
exit 1
