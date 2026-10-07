#!/bin/sh
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
for mutant in unknown-as-tablet cross-receipt; do
    subject="$tmp/$mutant"
    mkdir -p "$subject"
    cp -R "$root/android" "$root/tests" "$root/ci" "$root/catfood" "$root/provision.sh" "$root/repository-aliases.tsv" "$subject/"
    case $mutant in
        unknown-as-tablet)
            sed 's/if (known == "") { print "termux"; exit }/if (known == "") { print "tablet"; exit }/' \
                "$subject/android/target.sh" > "$subject/android/target.mutant"
            mv "$subject/android/target.mutant" "$subject/android/target.sh"
            test_name=targets
            diagnostic='expected termux, found tablet'
            ;;
        cross-receipt)
            sed '/if (expected_target != "" && t != expected_target) fail/d' \
                "$subject/android/check.sh" > "$subject/android/check.mutant"
            mv "$subject/android/check.mutant" "$subject/android/check.sh"
            test_name=c67-delivery
            diagnostic='cross-device or malformed receipt accepted'
            ;;
    esac
    if sh "$subject/tests/$test_name.sh" > "$tmp/$mutant.log" 2>&1; then
        printf 'mutation survived: %s\n' "$mutant" >&2; exit 1
    fi
    grep -F "$diagnostic" "$tmp/$mutant.log" >/dev/null || { cat "$tmp/$mutant.log" >&2; exit 1; }
    printf 'mutation rejected: %s (%s)\n' "$mutant" "$diagnostic"
done
