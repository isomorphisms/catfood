#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

workspace=$temporary/workspace
fake_bin=$temporary/bin
pkg_log=$temporary/pkg.log
mkdir -p "$workspace/bin" "$fake_bin"

cat > "$workspace/bin/ysh" <<'EOF_YSH'
#!/bin/sh
exec sh "$@"
EOF_YSH
chmod 0755 "$workspace/bin/ysh"

cat > "$fake_bin/pkg" <<'EOF_PKG'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$CATFOOD_PKG_LOG"
EOF_PKG
chmod 0755 "$fake_bin/pkg"

cat > "$fake_bin/curl" <<'EOF_CURL'
#!/bin/sh
exit 22
EOF_CURL
cat > "$fake_bin/jq" <<'EOF_JQ'
#!/bin/sh
exit 99
EOF_JQ
chmod 0755 "$fake_bin/curl" "$fake_bin/jq"

PATH="$fake_bin:$PATH" \
CATFOOD_PKG_LOG="$pkg_log" \
CATFOOD_ROOT="$workspace" \
    sh "$root/android/install-local-clients.sh" >/dev/null

test -x "$workspace/bin/gopeed"
test -L "$workspace/bin/gdl"
test -L "$workspace/bin/go_down_load"
test "$(readlink "$workspace/bin/gdl")" = gopeed
test "$(readlink "$workspace/bin/go_down_load")" = gopeed
grep -F "# Cat Food's small command-line client for the local Gopeed REST service." \
    "$workspace/bin/gopeed" >/dev/null
grep -Fx 'install -y curl jq' "$pkg_log" >/dev/null
PATH="$workspace/bin:$fake_bin:$PATH" "$workspace/bin/gdl" --help | grep -F 'go_down_load' >/dev/null
if PREFIX=/data/data/com.termux/files/usr PATH="$workspace/bin:$fake_bin:$PATH" \
   "$workspace/bin/gopeed" info >"$temporary/gopeed-info.out" 2>"$temporary/gopeed-info.err"; then
    printf '%s\n' 'unreachable Gopeed fixture unexpectedly passed' >&2
    exit 1
fi
grep -F 'select TCP and use 127.0.0.1:9999' "$temporary/gopeed-info.err" >/dev/null
grep -F 'does not rewrite Gopeed app-private settings' "$temporary/gopeed-info.err" >/dev/null

# Re-feeding may refresh Cat Food's own files, but must not overwrite a user's
# unrelated command occupying one of the stable names.
rm -f "$workspace/bin/gdl"
printf '%s\n' '#!/bin/sh' > "$workspace/bin/gdl"
chmod 0755 "$workspace/bin/gdl"
if PATH="$fake_bin:$PATH" \
   CATFOOD_PKG_LOG="$pkg_log" \
   CATFOOD_ROOT="$workspace" \
       sh "$root/android/install-local-clients.sh" >/dev/null 2>&1; then
    printf '%s\n' 'Android local-client feed overwrote an unrelated gdl command' >&2
    exit 1
fi

grep -Fx '#!/bin/sh' "$workspace/bin/gdl" >/dev/null
printf '%s\n' 'cat food Android local-client feed passes'
