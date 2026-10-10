#!/bin/sh
# Synthetic test double verifies installer boundaries, not Grease semantics.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d) || exit 1
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
workspace=$temporary/workspace
mkdir -p "$workspace"

# Local exact-Gitlink fixture. No network, deployment, or published artifact.
mkdir "$temporary/oils"
git -C "$temporary/oils" init -q
git -C "$temporary/oils" -c user.name=Test -c user.email=test@example.invalid \
    commit --allow-empty -q -m 'fixture source'
mkdir "$workspace/grease"
git -C "$workspace/grease" init -q
git -C "$workspace/grease" -c protocol.file.allow=always submodule add -q "$temporary/oils" source
git -C "$workspace/grease" -c user.name=Test -c user.email=test@example.invalid \
    commit -q -m 'fixture Grease gitlink'
grease_sha=$(git -C "$workspace/grease" rev-parse HEAD)
source_sha=$(git -C "$workspace/grease" rev-parse HEAD:source)

# This is not a Grease implementation and provides no production qualification.
# A small compiled C fixture tests only interpreter/ELF selection and receipts.
cat > "$temporary/native-fixture.c" <<'EOF_C'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[1], "-c") == 0 && strstr(argv[2], "grease=$answer")) {
        puts("grease=42");
        return 0;
    }
    if (argc == 2 && strstr(argv[1], "grease-alias.ysh")) {
        puts("alias-ok");
        puts(getenv("CATFOOD_TEST_BAD_ALIAS") ? "status=0" : "status=1");
        return 0;
    }
    return 98;
}
EOF_C
${CC:-cc} -std=c99 -Wall -Wextra -Werror "$temporary/native-fixture.c" -o "$temporary/native-grease"
digest=$(sha256sum "$temporary/native-grease" | awk '{print $1}')

try_native() {
    CATFOOD_ROOT="$workspace" \
    CATFOOD_GREASE_NATIVE="$temporary/native-grease" \
    CATFOOD_GREASE_NATIVE_SHA256="$digest" \
    CATFOOD_GREASE_NATIVE_GREASE_SHA="$grease_sha" \
    CATFOOD_GREASE_NATIVE_SOURCE_SHA="$source_sha" \
        sh "$root/install-grease-native.sh"
}

# Static guard for the Grease-owned YSH feed. It must never be run using sh:
# integration of this YSH script requires an independently qualified native
# Grease runner, which this synthetic ELF fixture is not.
grep -F 'link_first grease "$workspace/.build/grease-native/bin/grease"' "$root/update-tools.ysh" >/dev/null

# Default build-tools path must select native Grease without calling Python 2.
mkdir "$temporary/forbidden-bin"
cat > "$temporary/forbidden-bin/python2" <<'EOF_PYTHON'
#!/bin/sh
printf '%s\n' 'Python 2 was called in the native runtime lane' >> "$CATFOOD_TEST_PYTHON2_LOG"
exit 99
EOF_PYTHON
chmod +x "$temporary/forbidden-bin/python2"
CATFOOD_TEST_PYTHON2_LOG=$temporary/python2-called
CATFOOD_ROOT="$workspace" \
CATFOOD_GREASE_NATIVE="$temporary/native-grease" \
CATFOOD_GREASE_NATIVE_SHA256="$digest" \
CATFOOD_GREASE_NATIVE_GREASE_SHA="$grease_sha" \
CATFOOD_GREASE_NATIVE_SOURCE_SHA="$source_sha" \
CATFOOD_TEST_PYTHON2_LOG="$CATFOOD_TEST_PYTHON2_LOG" \
PATH="$temporary/forbidden-bin:$PATH" \
    sh "$root/build-tools.sh" > "$temporary/build.out"
test ! -e "$CATFOOD_TEST_PYTHON2_LOG"
test -x "$workspace/.build/grease-native/bin/grease"
grep -F 'runtime_arithmetic' "$workspace/.build/grease-native/receipt.tsv" | grep -F 'PASS' >/dev/null
grep -F 'runtime_alias_unalias' "$workspace/.build/grease-native/receipt.tsv" | grep -F 'PASS' >/dev/null
grep -F 'legacy_full_test_suite' "$workspace/.build/grease-native/receipt.tsv" | grep -F 'NOT_RUN' >/dev/null
grep -F 'producer_independent_acceptance' "$workspace/.build/grease-native/receipt.tsv" | grep -F 'NOT_VERIFIED' >/dev/null

test "$("$workspace/.build/grease-native/bin/grease" -c 'var answer = 6 * 7; write -- "grease=$answer"')" = grease=42

# Negative: the inherited source launcher cannot qualify as a native ELF.
cat > "$temporary/legacy-launcher" <<'EOF_LEGACY'
#!/bin/sh
exec python2 /missing/oils_for_unix.py "$@"
EOF_LEGACY
chmod +x "$temporary/legacy-launcher"
if CATFOOD_ROOT="$workspace" \
    CATFOOD_GREASE_NATIVE="$temporary/legacy-launcher" \
    CATFOOD_GREASE_NATIVE_SHA256="$(sha256sum "$temporary/legacy-launcher" | awk '{print $1}')" \
    CATFOOD_GREASE_NATIVE_GREASE_SHA="$grease_sha" \
    CATFOOD_GREASE_NATIVE_SOURCE_SHA="$source_sha" \
        sh "$root/install-grease-native.sh" >"$temporary/legacy.out" 2>&1; then
    echo 'FAIL: Python 2 launcher accepted as native Grease' >&2; exit 1
fi
grep -F 'must be an ELF' "$temporary/legacy.out" >/dev/null

# Negative: missing producer metadata fails closed.
if CATFOOD_ROOT="$workspace" sh "$root/install-grease-native.sh" >"$temporary/missing.out" 2>&1; then
    echo 'FAIL: missing verified native artifact accepted' >&2; exit 1
fi
grep -F 'compiled engine unavailable' "$temporary/missing.out" >/dev/null

# Negative: existing correct installation must not authorize wrong new bytes.
if CATFOOD_ROOT="$workspace" CATFOOD_GREASE_NATIVE="$temporary/native-grease" \
    CATFOOD_GREASE_NATIVE_SHA256="$(printf '%064d' 0)" \
    CATFOOD_GREASE_NATIVE_GREASE_SHA="$grease_sha" \
    CATFOOD_GREASE_NATIVE_SOURCE_SHA="$source_sha" \
       sh "$root/install-grease-native.sh" >"$temporary/digest.out" 2>&1; then
    echo 'FAIL: mismatched digest accepted' >&2; exit 1
fi
grep -F 'digest mismatch' "$temporary/digest.out" >/dev/null

# Negative: the declared producer source must match the checked-out gitlink.
if CATFOOD_ROOT="$workspace" CATFOOD_GREASE_NATIVE="$temporary/native-grease" \
    CATFOOD_GREASE_NATIVE_SHA256="$digest" \
    CATFOOD_GREASE_NATIVE_GREASE_SHA="$grease_sha" \
    CATFOOD_GREASE_NATIVE_SOURCE_SHA="$(printf '%040d' 0)" \
       sh "$root/install-grease-native.sh" >"$temporary/source.out" 2>&1; then
    echo 'FAIL: incorrect source gitlink accepted' >&2; exit 1
fi
grep -F 'source revision does not match' "$temporary/source.out" >/dev/null

# Negative: executable/hash alone do not prove semantic acceptability.
if CATFOOD_TEST_BAD_ALIAS=1 try_native >"$temporary/alias.out" 2>&1; then
    echo 'FAIL: incorrect alias result accepted' >&2; exit 1
fi
grep -F 'alias/unalias output mismatch' "$temporary/alias.out" >/dev/null

# A rejected candidate leaves the previously accepted bytes intact.
test "$(sha256sum "$workspace/.build/grease-native/bin/ysh" | awk '{print $1}')" = "$digest"
test ! -e "$CATFOOD_TEST_PYTHON2_LOG"
printf '%s\n' 'Cat Food native Grease selection: PASS (synthetic fixture, not actual Grease)'
