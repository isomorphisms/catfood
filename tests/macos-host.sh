#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || {
    printf '%s\n' 'This test requires a real native macOS ARM64 host' >&2
    exit 2
}
workspace=$(mktemp -d "${TMPDIR:-/tmp}/catfood-macos-test.XXXXXXXX")
trap 'rm -rf "$workspace"' 0 HUP INT TERM

[ "$(CATFOOD_TARGET=auto sh "$root/catfood" --target)" = macos-arm64 ]
CATFOOD_TARGET=macos-arm64 CATFOOD_ROOT="$workspace" \
    sh "$root/catfood"

receipt="$workspace/receipts/macos-host-smoke.tsv"
[ -f "$receipt" ]
tab=$(printf '\t')
source_commit=$(git -C "$root" rev-parse --verify HEAD)
grep -Fqx "source_commit${tab}$source_commit" "$receipt"
grep -Fqx "host_os${tab}Darwin" "$receipt"
grep -Fqx "host_architecture${tab}arm64" "$receipt"
grep -Fqx "source_tree${tab}clean" "$receipt"
grep -Fqx "compile_link_result${tab}PASS" "$receipt"
grep -Fqx "macho_architecture${tab}arm64" "$receipt"
grep -Fqx "native_execution_result${tab}PASS" "$receipt"
grep -Fqx "native_execution_output${tab}catfood-macos=42" "$receipt"

# A successful compiler/tool probe does not imply a source feed or a full
# project build, and it cannot install Linux runtime-binary artifacts.
[ ! -e "$workspace/grease" ]
[ ! -e "$workspace/packages/runtime-binaries" ]

# A missing developer SDK is a real failure, never converted to PASS from
# the previous successful receipt.
mkdir -p "$workspace/fake-bin"
cat > "$workspace/fake-bin/xcrun" <<'EOF_XCRUN'
#!/bin/sh
exit 17
EOF_XCRUN
chmod 0755 "$workspace/fake-bin/xcrun"
if CATFOOD_TARGET=macos-arm64 CATFOOD_ROOT="$workspace" \
    PATH="$workspace/fake-bin:$PATH" sh "$root/catfood" >"$workspace/out" 2>"$workspace/err"; then
    printf '%s\n' 'a missing SDK was accepted' >&2
    exit 1
fi
grep -F 'macOS SDK not available' "$workspace/err" >/dev/null

printf '%s\n' 'macOS ARM64 native compiler/framework/runtime smoke PASS'
