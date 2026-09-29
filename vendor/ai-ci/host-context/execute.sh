#!/bin/sh
# Stage-zero local executor. Receipts are outputs, never authorization inputs.
# Requires a trusted POSIX shell and a trusted PATH; not a security sandbox.
set -uf

fail_argument() {
    printf 'Invalid execution request (HC-REQUEST): %s\n' "$*" >&2
    exit 125
}

# v1 serializes one argument per line. Reject control characters rather than
# changing an argument's meaning or allowing it to forge a receipt row.
plain_field() {
    case $1 in
        *"$(printf '\t')"*|*"$(printf '\r')"*|*'
'*) return 1 ;;
        *) return 0 ;;
    esac
}

receipt=
request=
expected_os=
expected_arch=
expected_node=
expected_release=
expected_cwd=
expected_uid=
seen=' '
while [ "$#" -gt 0 ]; do
    key=$1
    case $key in
        --receipt|--request|--expect-os|--expect-arch|--expect-node|--expect-uid|--expect-release|--expect-cwd)
            [ "$#" -ge 2 ] || fail_argument "missing value for $key"
            case $seen in *" $key "*) fail_argument "duplicate $key" ;; esac
            seen="$seen$key "
            plain_field "$2" || fail_argument "control character in $key"
            [ -n "$2" ] || fail_argument "empty $key"
            case $key in
                --receipt) receipt=$2 ;;
                --request) request=$2 ;;
                --expect-os) expected_os=$2 ;;
                --expect-arch) expected_arch=$2 ;;
                --expect-node) expected_node=$2 ;;
                --expect-release) expected_release=$2 ;;
                --expect-cwd) expected_cwd=$2 ;;
                --expect-uid) expected_uid=$2 ;;
            esac
            shift 2
            ;;
        *) fail_argument "unknown option $key" ;;
    esac
done
[ -n "$request" ] && [ -n "$receipt" ] &&
[ -n "$expected_os" ] && [ -n "$expected_arch" ] ||
    fail_argument '--request, --receipt, --expect-os and --expect-arch are required'
case $receipt in /*) ;; *) fail_argument 'receipt path must be absolute' ;; esac
case $request in /*) ;; *) fail_argument 'request path must be absolute' ;; esac
case $expected_uid in ''|*[!0-9]*)
    [ -z "$expected_uid" ] || fail_argument 'expected uid must be numeric' ;;
esac

# Invoke this file as a script, never source it into the caller.
child_pid=
sequence=0
original_umask=$(umask)
umask 077

stop_child() {
    if [ -n "$child_pid" ]; then
        kill -TERM "$child_pid" 2>/dev/null || :
        # Only the direct child is supervised; descendants are not covered.
        kill -KILL "$child_pid" 2>/dev/null || :
        wait "$child_pid" 2>/dev/null || :
        child_pid=
    fi
}
write_failed() {
    stop_child
    printf '%s\n' 'Receipt write failed (HC-RECEIPT); success is not recorded.' >&2
    exit 125
}
record() {
    sequence=$((sequence + 1))
    printf '%s\t%s\t%s\t%s\n' "$sequence" "$1" "$2" "$3" >&3 || write_failed
}
block() {
    record blocked code "$1"
    record final outcome blocked
    printf '%s (%s)\n' "$2" "$1" >&2
    exit 125
}
interrupted() {
    trap '' HUP INT TERM
    stop_child
    record interrupted code HC-INTERRUPTED
    record final outcome interrupted
    exit 125
}

# Resolve only regular executable files, not aliases, functions, or builtins.
# No PATH defaults, package-manager guesses, or installer fallback.
resolve_executable() (
    name=$1
    case $name in
        /*)
            [ -f "$name" ] && [ -x "$name" ] || exit 1
            printf '%s\n' "$name"
            exit 0
            ;;
        ''|-*|*/*) exit 1 ;;
    esac
    rest=$captured_path
    while :; do
        case $rest in
            *:*) directory=${rest%%:*}; rest=${rest#*:}; more=1 ;;
            *) directory=$rest; more=0 ;;
        esac
        candidate=$directory/$name
        if [ -f "$candidate" ] && [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            exit 0
        fi
        [ "$more" -eq 1 ] || break
    done
    exit 1
)

supervise() {
    trap interrupted HUP INT TERM
    record meta schema aici-local-execution-v1
    record meta scope direct-child-only
    record meta runner_pid "$$"
    captured_path=${PATH-}
    plain_field "$captured_path" || block HC-PATH 'PATH contains control characters'
    case :$captured_path: in *::*) block HC-PATH 'PATH has an empty component' ;; esac
    path_tail=$captured_path
    while :; do
        case $path_tail in
            *:*) component=${path_tail%%:*}; path_tail=${path_tail#*:}; more=1 ;;
            *) component=$path_tail; more=0 ;;
        esac
        case $component in /*) ;; *) block HC-PATH 'PATH must contain only absolute directories' ;; esac
        [ "$more" -eq 1 ] || break
    done
    record observed path "$captured_path"
    current_directory=$(command pwd -P) || block HC-CWD 'Cannot observe current directory'
    plain_field "$current_directory" || block HC-CWD 'Current directory contains control characters'
    record observed cwd "$current_directory"

    uname_program=$(resolve_executable uname) || block HC-PROBE 'No executable uname; no installation is attempted'
    id_program=$(resolve_executable id) || block HC-PROBE 'No executable id; no installation is attempted'
    record observed uname_program "$uname_program"
    record observed id_program "$id_program"
    actual_os=$("$uname_program" -s) || block HC-PROBE 'Operating-system probe failed'
    actual_arch=$("$uname_program" -m) || block HC-PROBE 'Architecture probe failed'
    actual_release=$("$uname_program" -r) || block HC-PROBE 'Release probe failed'
    actual_node=$("$uname_program" -n) || block HC-PROBE 'Node-name probe failed'
    actual_uid=$("$id_program" -u) || block HC-PROBE 'User-id probe failed'
    for observed in "$actual_os" "$actual_arch" "$actual_release" "$actual_node" "$actual_uid"; do
        [ -n "$observed" ] && plain_field "$observed" || block HC-PROBE 'Invalid output from host probe'
    done
    record observed os "$actual_os"
    record observed arch "$actual_arch"
    record observed release "$actual_release"
    record observed node "$actual_node"
    record observed uid "$actual_uid"
    record expected os "$expected_os"
    record expected arch "$expected_arch"
    [ "$actual_os" = "$expected_os" ] || block HC-OS 'Operating system does not match the request'
    [ "$actual_arch" = "$expected_arch" ] || block HC-ARCH 'Architecture does not match the request'
    if [ -n "$expected_release" ]; then
        record expected release "$expected_release"
        [ "$actual_release" = "$expected_release" ] || block HC-RELEASE 'Release does not match the request'
    fi
    if [ -n "$expected_cwd" ]; then
        record expected cwd "$expected_cwd"
        [ "$current_directory" = "$expected_cwd" ] || block HC-CWD 'Working directory does not match the request'
    fi
    if [ -n "$expected_node" ]; then
        record expected node "$expected_node"
        [ "$actual_node" = "$expected_node" ] || block HC-NODE 'Node name does not match the request'
    fi
    if [ -n "$expected_uid" ]; then
        record expected uid "$expected_uid"
        [ "$actual_uid" = "$expected_uid" ] || block HC-UID 'User id does not match the request'
    fi

    [ -f "$request" ] && [ -r "$request" ] || block HC-REQUEST 'Request is not a readable regular file'
    # od is an explicit, checked bootstrap dependency for the restricted
    # argv-file format. Reject NUL before shell read could discard it.
    od_program=$(resolve_executable od) || block HC-PROBE 'No executable od; no installation is attempted'
    record observed od_program "$od_program"
    byte_dump=$("$od_program" -A n -t x1 -v -N 65537 "$request") || block HC-REQUEST 'Cannot inspect request bytes'
    set -- $byte_dump
    [ "$#" -le 65536 ] || block HC-REQUEST 'Request exceeds 65536 bytes'
    for byte in "$@"; do
        [ "$byte" != 00 ] || block HC-REQUEST 'NUL byte in request'
    done
    # Snapshot the entire argv in this process before starting the child.
    # No eval, shell command string, or separate claimed command-use trace.
    set --
    line=
    count=0
    while IFS= read -r line || [ -n "$line" ]; do
        plain_field "$line" || block HC-REQUEST 'Control character in argument'
        count=$((count + 1))
        [ "$count" -le 256 ] || block HC-REQUEST 'Request exceeds 256 argv entries'
        [ "${#line}" -le 16384 ] || block HC-REQUEST 'Argument exceeds 16384 characters'
        set -- "$@" "$line"
    done < "$request"
    [ "$#" -gt 0 ] && [ -n "$1" ] || block HC-REQUEST 'Request has no program'
    requested_program=$1
    record request argc "$#"
    index=0
    for argument in "$@"; do
        record argument "$index" "$argument"
        index=$((index + 1))
    done
    executable=$(resolve_executable "$requested_program") || block HC-COMMAND 'Requested program is unavailable; acquisition remains unknown'
    record observed executable "$executable"
    # Scope deliberately includes shell exec semantics, not a claim that a
    # script or subprocess tree has been validated. See README boundaries.
    [ -r /dev/null ] || block HC-STDIN 'Noninteractive input is unavailable'
    [ -f "$executable" ] && [ -x "$executable" ] || block HC-COMMAND 'Executable disappeared before launch'
    record ready operation execute
    shift
    (
        exec 3>&-
        trap - HUP INT TERM
        umask "$original_umask"
        exec "$executable" "$@"
    ) </dev/null &
    child_pid=$!
    record launched child_pid "$child_pid"
    if wait "$child_pid"; then status=0; else status=$?; fi
    child_pid=
    record exited wait_status "$status"
    if [ "$status" -eq 0 ]; then
        record final outcome succeeded
    else
        record final outcome failed
    fi
    exit "$status"
}

# Noclobber protects existing receipts and symlinks. Redirection happens
# before supervise can perform any requested operation. An interrupted or
# unwritable receipt has no valid success trailer.
if [ -e "$receipt" ] || [ -L "$receipt" ]; then
    printf '%s\n' 'Receipt already exists (HC-RECEIPT); no operation was started.' >&2
    exit 125
fi
set -C
supervise 3> "$receipt"
