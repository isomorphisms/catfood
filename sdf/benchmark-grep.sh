#!/bin/sh
set -eu

mailbox=${MAILBOX:-/var/mail/isomorphisms}
grease=${GREASE:-"${CATFOOD_ROOT:-$HOME/opt}/bin/grease"}
baseline_shell=${BASELINE_SHELL:-${SHELL:-/bin/sh}}
state=${CATFOOD_SDF_STATE:-"$HOME/.local/state/catfood-sdf"}
time_command=${TIME_COMMAND:-/usr/bin/time}

[ -r "$mailbox" ] || {
    printf 'mailbox is not readable: %s\n' "$mailbox" >&2
    exit 1
}
[ -x "$grease" ] || {
    printf 'Grease is not executable: %s\n' "$grease" >&2
    exit 1
}
[ -x "$baseline_shell" ] || {
    printf 'baseline shell is not executable: %s\n' "$baseline_shell" >&2
    exit 1
}
[ -x "$time_command" ] || {
    printf 'time command is not executable: %s\n' "$time_command" >&2
    exit 1
}

case $mailbox in
    *\"*)
        printf '%s\n' 'mailbox path may not contain a double quote' >&2
        exit 2
        ;;
esac

mkdir -p "$state"
run_id=$(date '+%Y%m%dT%H%M%S')
out=$state/grep-$run_id
mkdir -p "$out"

pipeline="grep -aEi '^(To|Cc):.*SPEC-LIST' \"$mailbox\" | sort -fu | head -50"

run_one() {
    label=$1
    shell=$2
    printf 'running=%s shell=%s\n' "$label" "$shell"
    "$time_command" -p "$shell" -c "$pipeline" >"$out/$label.out" 2>"$out/$label.time"
}

printf 'mailbox=%s\n' "$mailbox"
printf 'bytes=%s\n' "$(wc -c < "$mailbox" | tr -d ' ')"
printf 'pipeline=%s\n' "$pipeline"

# Grease runs second on purpose for the first control: any filesystem-cache
# advantage biases toward Grease rather than against it.
run_one baseline "$baseline_shell"
run_one grease "$grease"

if ! cmp -s "$out/baseline.out" "$out/grease.out"; then
    printf '%s\n' 'FAIL: baseline and Grease produced different output' >&2
    diff -u "$out/baseline.out" "$out/grease.out" >&2 || true
    exit 1
fi

printf '%s\n' 'PASS: baseline and Grease output match'
printf '%s\n' '--- baseline time ---'
cat "$out/baseline.time"
printf '%s\n' '--- grease time ---'
cat "$out/grease.time"
printf 'results=%s\n' "$out"
