#!/bin/sh
# Host-side adoption of an already compiled, source-qualified Grease engine.
# The legacy source launcher and test suite are deliberately separate.
set -eu

fail() {
    printf 'Cat Food native Grease: %s\n' "$*" >&2
    exit 2
}

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
workspace=${CATFOOD_ROOT:-/opt}
build_root=${CATFOOD_BUILD_ROOT:-$workspace/.build}
checkout=$workspace/grease
candidate=${CATFOOD_GREASE_NATIVE:-}
expected_digest=${CATFOOD_GREASE_NATIVE_SHA256:-}
declared_grease=${CATFOOD_GREASE_NATIVE_GREASE_SHA:-}
declared_source=${CATFOOD_GREASE_NATIVE_SOURCE_SHA:-}

[ -e "$checkout/.git" ] || fail "missing verified Grease checkout at $checkout"
for command_name in git sha256sum od tr awk; do
    command -v "$command_name" >/dev/null 2>&1 || fail "missing host verifier: $command_name"
done

[ -n "$candidate" ] && [ -n "$expected_digest" ] &&
[ -n "$declared_grease" ] && [ -n "$declared_source" ] ||
    fail 'compiled engine unavailable; provide CATFOOD_GREASE_NATIVE, CATFOOD_GREASE_NATIVE_SHA256, CATFOOD_GREASE_NATIVE_GREASE_SHA, CATFOOD_GREASE_NATIVE_SOURCE_SHA from a producer receipt. Python 2 source launcher is not a fallback.'

case $candidate in
    /*) ;;
    *) fail 'CATFOOD_GREASE_NATIVE must be an absolute engine path' ;;
esac

printf '%s\n' "$expected_digest" | grep -Eq '^[0-9a-f]{64}$' ||
    fail 'invalid compiled engine SHA-256'
for revision in "$declared_grease" "$declared_source"; do
    printf '%s\n' "$revision" | grep -Eq '^[0-9a-f]{40}$' ||
        fail 'compiled engine source revisions must be full lowercase Git SHA-1 values'
done

actual_grease=$(git -C "$checkout" rev-parse HEAD) || fail 'cannot read Grease checkout revision'
actual_source=$(git -C "$checkout" rev-parse HEAD:source) || fail 'cannot read pinned Grease source revision'
[ "$actual_grease" = "$declared_grease" ] || fail 'producer-declared Grease revision does not match checkout'
[ "$actual_source" = "$declared_source" ] || fail 'producer-declared source revision does not match checkout gitlink'
[ "$(git -C "$checkout/source" rev-parse HEAD 2>/dev/null)" = "$actual_source" ] ||
    fail 'Grease source submodule is not at the pinned revision'

[ -f "$candidate" ] && [ -x "$candidate" ] || fail "compiled executable missing: $candidate"
magic=$(od -An -tx1 -N4 "$candidate" | tr -d ' \n')
[ "$magic" = 7f454c46 ] || fail 'compiled Grease engine must be an ELF executable; not a Python or shell launcher'

command -v readelf >/dev/null 2>&1 || fail 'readelf is needed for host ELF architecture validation'
elf_header=$(readelf -h "$candidate") || fail 'invalid ELF header'
case $(uname -m) in
    x86_64) printf '%s\n' "$elf_header" | grep -F 'Advanced Micro Devices X86-64' >/dev/null || fail 'engine is not Linux x86-64 ELF' ;;
    aarch64) printf '%s\n' "$elf_header" | grep -F 'AArch64' >/dev/null || fail 'engine is not Linux AArch64 ELF' ;;
    *) fail 'host architecture requires a separately qualified Grease binary lane' ;;
esac

actual_digest=$(sha256sum "$candidate" | awk '{print $1}')
[ "$actual_digest" = "$expected_digest" ] || fail "compiled engine digest mismatch: $actual_digest"

expected=grease=42
output=$("$candidate" -c 'var answer = 6 * 7; write -- "grease=$answer"') || fail 'compiled Grease arithmetic smoke failed'
[ "$output" = "$expected" ] || fail "compiled Grease arithmetic output mismatch: $output"

alias_expected=$(printf 'alias-ok\nstatus=1')
alias_output=$("$candidate" "$root/tests/fixtures/grease-alias.ysh") || fail 'compiled Grease alias/unalias fixture failed'
[ "$alias_output" = "$alias_expected" ] || fail "compiled Grease alias/unalias output mismatch: $alias_output"

mkdir -p "$build_root"
staging=$(mktemp -d "$build_root/.grease-native.XXXXXXXX") || fail 'cannot stage compiled Grease'
trap 'rm -rf "$staging"' EXIT HUP INT TERM
mkdir -p "$staging/bin"
cp "$candidate" "$staging/bin/ysh"
chmod 0755 "$staging/bin/ysh"
[ "$(sha256sum "$staging/bin/ysh" | awk '{print $1}')" = "$expected_digest" ] ||
    fail 'compiled engine changed during copy'
cat > "$staging/bin/grease" <<'EOF_WRAPPER'
#!/bin/sh
# Cat Food compiled Grease runtime; does not execute the Python source launcher.
self_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
exec "$self_dir/ysh" "$@"
EOF_WRAPPER
chmod 0755 "$staging/bin/grease"

[ "$("$staging/bin/grease" -c 'var answer = 6 * 7; write -- "grease=$answer"')" = "$expected" ] ||
    fail 'staged compiled Grease wrapper failed'
[ "$("$staging/bin/grease" "$root/tests/fixtures/grease-alias.ysh")" = "$alias_expected" ] ||
    fail 'staged compiled Grease alias fixture failed'

{
    printf 'format\tcatfood-grease-native-v1\n'
    printf 'grease_revision\t%s\n' "$actual_grease"
    printf 'source_revision\t%s\n' "$actual_source"
    printf 'sha256\t%s\n' "$expected_digest"
    printf 'runtime_arithmetic\tPASS\n'
    printf 'runtime_alias_unalias\tPASS\n'
    printf 'legacy_development_launcher\tNOT_RUN\n'
    printf 'legacy_full_test_suite\tNOT_RUN\n'
    printf 'producer_independent_acceptance\tNOT_VERIFIED\n'
    printf 'host_arch\t%s\n' "$(uname -m)"
} > "$staging/receipt.tsv"

# Never overwrite a previous native installation before candidate validation.
# Retain the prior bytes until installation has passed all semantic fixtures.
installed=$build_root/grease-native
if [ -e "$installed" ]; then
    previous=$build_root/.grease-native.previous.$$
    [ ! -e "$previous" ] || fail 'refusing to overwrite an existing backup path'
    mv "$installed" "$previous" || fail 'cannot move previous native installation'
    if ! mv "$staging" "$installed"; then
        mv "$previous" "$installed" || true
        fail 'failed to activate verified native Grease'
    fi
    rm -rf "$previous"
else
    mv "$staging" "$installed" || fail 'failed to activate verified native Grease'
fi
trap - EXIT HUP INT TERM
printf 'Cat Food compiled Grease qualified for host use: %s\n' "$installed/bin/grease"
