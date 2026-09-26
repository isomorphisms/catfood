#!/bin/sh
set -eu

mode=${1:-container}
controller_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
root=${2:-$controller_root}
root=$(CDPATH='' cd -- "$root" && pwd)

case $mode in
    github|container|cloud) ;;
    *) printf 'usage: %s github|container|cloud [SOURCE_ROOT]\n' "$0" >&2; exit 2 ;;
esac

# Runtime acceptance requires an explicitly provisioned workbench. Contract
# fixtures and target detection alone cannot establish delivered execution.
if [ -z "${CATFOOD_ROOT:-}" ] || [ -z "${CATFOOD_PREFIX:-}" ]; then
    printf '%s\n' 'x86 follower acceptance requires CATFOOD_ROOT and CATFOOD_PREFIX for the provisioned workbench' >&2
    exit 1
fi
if [ ! -x "$CATFOOD_ROOT/bin/catfood-doctor" ]; then
    printf '%s\n' 'x86 follower acceptance requires the installed catfood-doctor' >&2
    exit 1
fi
# The source launcher is meaningful only with its actual built interpreter.
# Compare the existing builder stamp with the verified workbench checkout and
# its gitlink; a renamed upstream shell or a missing build cannot qualify.
checkouts=$("$root/catfood" where grease)
grease=$(printf '%s\n' "$checkouts" | awk -F '\t' '$2 == "workbench" {print $3}')
[ -d "$grease" ] || { echo 'missing verified Grease workbench checkout' >&2; exit 1; }
grease_head=$(git -C "$grease" rev-parse HEAD)
source_pin=$(git -C "$grease" rev-parse HEAD:source)
[ "$(git -C "$grease/source" rev-parse HEAD)" = "$source_pin" ]
stamp="$CATFOOD_ROOT/.build/stamps/grease"
[ -f "$stamp" ] || { echo 'missing Grease build stamp' >&2; exit 1; }
[ "$(cat "$stamp")" = "$grease_head $source_pin" ] || {
    echo 'Grease build stamp does not match its resolved source' >&2
    exit 1
}
printf 'Grease build provenance: %s %s\n' "$grease_head" "$source_pin"
actual=$("$CATFOOD_ROOT/bin/grease" -c 'false ∨ echo canonical-grease')
[ "$actual" = canonical-grease ] || { echo 'installed Grease identity probe failed' >&2; exit 1; }
"$CATFOOD_ROOT/bin/catfood-doctor"

# These additional contract checks do not claim physical Android acceptance.
sh "$root/tests/entrypoint.sh"
sh "$root/tests/targets.sh"
sh "$root/tests/android-delivery.sh"
if [ -f "$root/tests/github-normalization.sh" ]; then
    sh "$root/tests/github-normalization.sh"
fi

case $mode in
    github|container) CATFOOD_TARGET=container "$root/catfood" --target | grep '^container$' >/dev/null ;;
    cloud) CATFOOD_TARGET=cloud "$root/catfood" --target | grep '^cloud$' >/dev/null ;;
esac

printf 'x86 follower acceptance passed: %s at %s\n' "$mode" "$root"
