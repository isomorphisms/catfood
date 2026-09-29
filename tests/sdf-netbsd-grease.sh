#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/catfood-sdf-test.$$
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/package" "$tmp/home" "$tmp/state"

cat > "$tmp/package/oils-for-unix" <<'EOF'
#!/bin/sh
if [ "$1" = ysh ]; then
    shift
fi
exec /bin/sh "$@"
EOF
chmod +x "$tmp/package/oils-for-unix"

cat > "$tmp/package/grease" <<'EOF'
#!/bin/sh
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
exec "$here/oils-for-unix" ysh "$@"
EOF
chmod +x "$tmp/package/grease"

tar -C "$tmp/package" -czf "$tmp/grease.tar.gz" .

HOME="$tmp/home" CATFOOD_ROOT="$tmp/home/opt"     sh "$root/sdf/install-grease.sh" "$tmp/grease.tar.gz"

cat > "$tmp/mailbox" <<'EOF'
From example
To: SPEC-LIST@example.org
Cc: other@example.org
Cc: SPEC-LIST@example.org
EOF

HOME="$tmp/home" MAILBOX="$tmp/mailbox" GREASE="$tmp/home/opt/bin/grease" BASELINE_SHELL=/bin/sh CATFOOD_SDF_STATE="$tmp/state"     sh "$root/sdf/benchmark-grep.sh" > "$tmp/benchmark.out"

grep -F 'PASS: baseline and Grease output match' "$tmp/benchmark.out" >/dev/null
printf '%s\n' 'PASS sdf NetBSD Grease install and benchmark harness'
