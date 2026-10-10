#!/bin/sh
set -eu

# Execute the public host and Android entrypoints with an inert, isolated
# build/device fixture. No user checkout, package, or real Android device is
# modified. Actual shipped Grease ELF inspection is a separate acceptance step.
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

host="$tmp/host with spaces"
log="$tmp/commands.log"
fakebin="$tmp/bin"
mkdir -p "$host/grease/source/.git" "$host/grease/.git" \
    "$host/grease/source/Python-2.7.13/Include" \
    "$host/grease/source/Python-2.7.13/Python" "$fakebin"
: > "$log"

# Do not depend on a real Grease repository or build a Python 2 interpreter.
# The fake git answers only the revision query exercised by build-tools.sh.
cat > "$fakebin/git" <<'EOF_GIT'
#!/bin/sh
[ "$#" -eq 4 ] && [ "$1" = -C ] && [ "$3" = rev-parse ] && [ "$4" = HEAD ] || exit 98
printf '%s\n' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
EOF_GIT
chmod +x "$fakebin/git"
cat > "$host/grease/source/Python-2.7.13/configure" <<'EOF_CONF'
#!/bin/sh
printf '%s\n' legacy-python2-configure >> "$CATFOOD_TEST_LOG"
exit 61
EOF_CONF
chmod +x "$host/grease/source/Python-2.7.13/configure"

CATFOOD_ROOT="$host" CATFOOD_TEST_LOG="$log" PATH="$fakebin:$PATH" \
    sh "$root/build-tools.sh" > "$tmp/host-default.out"
grep -F 'Grease Python 2 source bootstrap skipped' "$tmp/host-default.out" >/dev/null
test ! -e "$host/.build/grease/python2"
test ! -s "$log"

# Invalid opt-in values must stop before a source build.
if CATFOOD_ROOT="$host" CATFOOD_TEST_LOG="$log" PATH="$fakebin:$PATH" \
    CATFOOD_GREASE_LEGACY_PYTHON2=yes sh "$root/build-tools.sh" \
    > "$tmp/invalid.out" 2>&1; then
    printf '%s\n' 'invalid Python 2 opt-in unexpectedly passed' >&2
    exit 1
fi
grep -F 'must be 0 or 1' "$tmp/invalid.out" >/dev/null
test ! -s "$log"

# Deliberate negative control: opt-in reaches the legacy source configure,
# whose fixture rejects real compilation.
if CATFOOD_ROOT="$host" CATFOOD_TEST_LOG="$log" PATH="$fakebin:$PATH" \
    CATFOOD_GREASE_LEGACY_PYTHON2=1 sh "$root/build-tools.sh" \
    > "$tmp/legacy.out" 2>&1; then
    printf '%s\n' 'legacy configure blocker unexpectedly passed' >&2
    exit 1
fi
grep -Fx 'legacy-python2-configure' "$log" >/dev/null

# An older Cat Food run may have left a stable symlink to Python 2. Its
# symlink is under Cat Food ownership; do not destroy the interpreter bytes.
mkdir -p "$host/.build/grease/bin" "$host/bin"
cat > "$host/.build/grease/bin/grease" <<'EOF_GREASE'
#!/bin/sh
printf '%s\n' legacy-run >> "$CATFOOD_TEST_LOG"
exit 87
EOF_GREASE
chmod +x "$host/.build/grease/bin/grease"
ln -s "$host/.build/grease/bin/grease" "$host/bin/grease"
printf '%s\n' '# isolated links-only manifest' > "$tmp/empty.tsv"
CATFOOD_ROOT="$host" PATH="$fakebin:$PATH" \
    sh "$root/update-tools.ysh" "$host" 1 "$tmp/empty.tsv" 1 0 >/dev/null
test ! -L "$host/bin/grease"
test -x "$host/.build/grease/bin/grease"
! grep -Fx legacy-run "$log" >/dev/null

# Explicit opt-in restores only the legacy-development link.
CATFOOD_ROOT="$host" PATH="$fakebin:$PATH" \
    sh "$root/update-tools.ysh" "$host" 1 "$tmp/empty.tsv" 1 1 >/dev/null
test "$(readlink "$host/bin/grease")" = "$host/.build/grease/bin/grease"
CATFOOD_ROOT="$host" PATH="$fakebin:$PATH" \
    sh "$root/update-tools.ysh" "$host" 1 "$tmp/empty.tsv" 1 0 >/dev/null
test ! -L "$host/bin/grease"

# A stale source-stage shell must not sneak Python 2 back in *before*
# activate.sh runs. Exercise bootstrap.sh itself, with the repository fetch
# and nested update command replaced by harmless local effects.
stage="$tmp/stage-zero"
stagebin="$tmp/stage-bin"
mkdir -p "$stage/ci" "$stagebin" "$host/grease/source/bin"
cp "$root/bootstrap.sh" "$stage/bootstrap.sh"
cat > "$stage/ci/repositories.sh" <<'EOF_REPOS'
same_repository_url() { :; }
EOF_REPOS
cat > "$stage/check-manifest.sh" <<'EOF_CHECK'
#!/bin/sh
exit 0
EOF_CHECK
cat > "$stage/update-tools.ysh" <<'EOF_UPDATE'
#!/bin/sh
printf '%s\\n' stage-zero-update >> "$CATFOOD_TEST_LOG"
EOF_UPDATE
cat > "$stagebin/git" <<'EOF_STAGE_GIT'
#!/bin/sh
[ "${1:-}" = -C ] || exit 98
case ${3:-} in
    remote) printf '%s\\n' https://github.com/dilapidated-shed/grease.git ;;
    fetch|checkout|merge|submodule|show-ref|status) exit 0 ;;
    *) exit 97 ;;
esac
EOF_STAGE_GIT
cat > "$host/grease/source/bin/ysh" <<'EOF_SOURCE_YSH'
#!/bin/sh
printf '%s\\n' legacy-ysh-run >> "$CATFOOD_TEST_LOG"
[ "${1:-}" = -c ] && exit 0
exec sh "$@"
EOF_SOURCE_YSH
chmod +x "$stagebin/git" "$host/grease/source/bin/ysh"
ln -s "$host/grease/source/bin/ysh" "$stagebin/ysh"
ln -s "$host/grease/source/bin/ysh" "$host/bin/ysh"
: > "$log"
CATFOOD_ROOT="$host" CATFOOD_MANIFEST="$tmp/empty.tsv" \\
    CATFOOD_TEST_LOG="$log" CATFOOD_YSH= \\
    CATFOOD_GREASE_LEGACY_PYTHON2=0 PATH="$stagebin:$PATH" \\
    sh "$stage/bootstrap.sh" > "$tmp/bootstrap-default.out"
grep -F 'no runnable YSH yet' "$tmp/bootstrap-default.out" >/dev/null
grep -Fx stage-zero-update "$log" >/dev/null
! grep -Fx legacy-ysh-run "$log" >/dev/null

: > "$log"
CATFOOD_ROOT="$host" CATFOOD_MANIFEST="$tmp/empty.tsv" \\
    CATFOOD_TEST_LOG="$log" CATFOOD_YSH= \\
    CATFOOD_GREASE_LEGACY_PYTHON2=1 PATH="$stagebin:$PATH" \\
    sh "$stage/bootstrap.sh" > "$tmp/bootstrap-legacy.out"
grep -Fx legacy-ysh-run "$log" >/dev/null
: > "$log"

# A Grease-native candidate can be linked without the legacy interpreter.
mkdir -p "$host/grease/source/_bin/cxx-sh"
cat > "$host/grease/source/_bin/cxx-sh/ysh" <<'EOF_NATIVE'
#!/bin/sh
exit 0
EOF_NATIVE
chmod +x "$host/grease/source/_bin/cxx-sh/ysh"
CATFOOD_ROOT="$host" PATH="$fakebin:$PATH" \
    sh "$root/update-tools.ysh" "$host" 1 "$tmp/empty.tsv" 1 0 >/dev/null
test "$(readlink "$host/bin/grease")" = "$host/grease/source/_bin/cxx-sh/ysh"
# The old Cat Food-owned Python 2 stable YSH link is also cleared.
test ! -L "$host/bin/ysh"
! grep -Fx legacy-ysh-run "$log" >/dev/null

# Test refresh.sh's real native-runner selection against the known-bad
# already-linked legacy executable, without cloning or compiling anything.
control="$tmp/refresh-control"
mkdir -p "$control"
cp "$root/refresh.sh" "$control/refresh.sh"
for helper in bootstrap.sh activate.sh build-tools.sh doctor.sh update-tools.ysh; do
    cat > "$control/$helper" <<'EOF_HELPER'
#!/bin/sh
printf '%s\n' "control:$(basename "$0")" >> "$CATFOOD_TEST_LOG"
EOF_HELPER
done
cat > "$host/bin/ysh" <<'EOF_YSH'
#!/bin/sh
[ "${1:-}" = -c ] && exit 0
printf '%s\n' native-stage-one >> "$CATFOOD_TEST_LOG"
exec sh "$@"
EOF_YSH
chmod +x "$host/bin/ysh"
rm -f "$host/bin/grease"
ln -s "$host/.build/grease/bin/grease" "$host/bin/grease"
CATFOOD_ROOT="$host" CATFOOD_TEST_LOG="$log" CATFOOD_NO_PROFILE=1 \
    CATFOOD_PREFIX="$tmp/prefix" sh "$control/refresh.sh" >/dev/null
grep -Fx native-stage-one "$log" >/dev/null
! grep -Fx legacy-run "$log" >/dev/null

# Exercise provision.sh itself, with harmless child scripts and synthetic
# device classification. The default must not launch csvkit's Python installer.
device="$tmp/device-control"
mkdir -p "$device/android"
cp "$root/provision.sh" "$device/provision.sh"
cat > "$device/android/target.sh" <<'EOF_TARGET'
catfood_android_require_device() { :; }
catfood_detect_target() { printf '%s\n' phone; }
EOF_TARGET
for helper in android/preserve-shizuku.sh install-binaries.sh install-lua.sh \
    android/install.sh android/install-crawlspace-bootstrap.sh \
    android/install-local-clients.sh android/install-csvkit.sh; do
    mkdir -p "$device/$(dirname "$helper")"
    cat > "$device/$helper" <<'EOF_HELPER'
#!/bin/sh
printf '%s\n' "$(basename "$0")" >> "$CATFOOD_TEST_LOG"
EOF_HELPER
done
: > "$log"
CATFOOD_TARGET=phone CATFOOD_ROOT="$tmp/device-workspace" \
    CATFOOD_TEST_LOG="$log" CATFOOD_CONFIG_DIR= \
    sh "$device/provision.sh" >/dev/null
grep -Fx 'install.sh' "$log" >/dev/null
! grep -Fx 'install-csvkit.sh' "$log" >/dev/null

: > "$log"
CATFOOD_TARGET=phone CATFOOD_ROOT="$tmp/device-workspace" \
    CATFOOD_TEST_LOG="$log" CATFOOD_CONFIG_DIR= CATFOOD_INSTALL_CSVKIT=1 \
    sh "$device/provision.sh" >/dev/null
test "$(grep -Fxc install-csvkit.sh "$log")" -eq 1

: > "$log"
if CATFOOD_TARGET=phone CATFOOD_ROOT="$tmp/device-workspace" \
    CATFOOD_TEST_LOG="$log" CATFOOD_INSTALL_CSVKIT=maybe \
    sh "$device/provision.sh" > "$tmp/invalid-csvkit.out" 2>&1; then
    printf '%s\n' 'invalid csvkit opt-in unexpectedly passed' >&2
    exit 1
fi
grep -F 'CATFOOD_INSTALL_CSVKIT must be 0 or 1' "$tmp/invalid-csvkit.out" >/dev/null
test ! -s "$log"

printf '%s\n' 'Cat Food Python dependency defaults pass (synthetic host/device fixtures)'
