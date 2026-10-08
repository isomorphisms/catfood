#!/bin/sh
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
ref=1111111111111111111111111111111111111111
contract="$tmp/app.tsv"
cat > "$contract" <<'EOF'
schema	catfood-android-application-v1
repository	isomorphismes/wegert
package_id	org.isomorphisms.wegert
launcher_label	zero & infinity
min_sdk	26
packaging	shared
armeabi-v7a	supported
arm64-v8a	supported
EOF
sh "$root/android/plan-build.sh" "$contract" phone "$ref" > "$tmp/a1.tsv"
sh "$root/android/plan-build.sh" "$contract" phone "$ref" > "$tmp/replay.tsv"
cmp "$tmp/a1.tsv" "$tmp/replay.tsv"
grep -Fx 'launcher_label	zero & infinity' "$tmp/a1.tsv"
grep -Fx 'phone	MIRO_A1	armeabi-v7a	required	not_run' "$tmp/a1.tsv"
grep -Fx 'c67	MIRO_C67	arm64-v8a	required	not_run' "$tmp/a1.tsv"
sh "$root/android/plan-build.sh" "$contract" c67 "$ref" > "$tmp/c67.tsv"
grep -Fx 'c67	MIRO_C67	arm64-v8a	required	not_run' "$tmp/c67.tsv"
if grep -q '^phone	' "$tmp/c67.tsv"; then
    echo 'reverse A1 obligation invented for C67-only request' >&2; exit 1
fi
sed 's/^arm64-v8a	supported$/arm64-v8a	incompatible/' "$contract" > "$tmp/incompatible.tsv"
sh "$root/android/plan-build.sh" "$tmp/incompatible.tsv" phone "$ref" > "$tmp/inc.tsv"
grep -Fx 'c67	MIRO_C67	arm64-v8a	incompatible	not_run' "$tmp/inc.tsv"
sed 's/^arm64-v8a	supported$/arm64-v8a	unknown/' "$contract" > "$tmp/unknown.tsv"
sh "$root/android/plan-build.sh" "$tmp/unknown.tsv" phone "$ref" > "$tmp/blocked.tsv"
grep -Fx 'c67	MIRO_C67	arm64-v8a	blocked	not_run' "$tmp/blocked.tsv"
if [ "$(grep '^contract_sha256	' "$tmp/blocked.tsv")" = "$(grep '^contract_sha256	' "$tmp/a1.tsv")" ]; then
    echo 'changed requirements reused plan identity' >&2; exit 1
fi
reject() {
    expected=$1
    candidate=$2
    if sh "$root/android/plan-build.sh" "$candidate" phone "$ref" >"$tmp/out" 2>"$tmp/err"; then
        echo "invalid $candidate was accepted" >&2; exit 1
    fi
    grep -F "$expected" "$tmp/err"
}
cp "$contract" "$tmp/duplicate.tsv"
printf 'launcher_label	Wegert\n' >> "$tmp/duplicate.tsv"
reject 'duplicate application contract field' "$tmp/duplicate.tsv"
sed '/^launcher_label	/d' "$contract" > "$tmp/missing.tsv"
reject 'missing application contract field' "$tmp/missing.tsv"
sed 's/^packaging	shared$/packaging	gradle/' "$contract" > "$tmp/bad-shape.tsv"
reject 'packaging must be shared or split' "$tmp/bad-shape.tsv"
sed 's/^arm64-v8a	supported$/arm64-v8a	PASS/' "$contract" > "$tmp/forged.tsv"
reject 'invalid arm64-v8a support decision' "$tmp/forged.tsv"
if sh "$root/android/plan-build.sh" "$contract" tablet "$ref" >/dev/null 2>&1; then
    echo 'tablet was silently used as a C67 request' >&2; exit 1
fi
if sh "$root/android/plan-build.sh" "$contract" phone main >/dev/null 2>&1; then
    echo 'moving application ref was accepted' >&2; exit 1
fi
printf '%s\n' 'Cat Food companion plan contract: PASS (synthetic only)'
