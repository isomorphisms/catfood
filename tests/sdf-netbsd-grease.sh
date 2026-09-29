#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/catfood-sdf-test.$$
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/package" "$tmp/home" "$tmp/state" "$tmp/bin"

real_system=$(uname -s 2>/dev/null || printf '%s\n' unknown)
if [ "$real_system" = NetBSD ]; then
    test_path=$PATH
else
    cat > "$tmp/bin/uname" <<'EOF'
#!/bin/sh
case ${1:-} in
    -s) printf '%s\n' NetBSD ;;
    -m) printf '%s\n' amd64 ;;
    -r) printf '%s\n' 11.0-test ;;
    *) exit 2 ;;
esac
EOF
    chmod +x "$tmp/bin/uname"
    test_path=$tmp/bin:$PATH
fi

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

PATH=$test_path
export PATH
. "$root/sdf/platform.sh"
sha=$(catfood_sdf_sha256 "$tmp/grease.tar.gz")
printf '%s  %s\n' "$sha" grease-netbsd-11-amd64.tar.gz > "$tmp/grease.tar.gz.sha256"

HOME="$tmp/home" CATFOOD_ROOT="$tmp/home/opt" CATFOOD_GREASE_URL="file://$tmp/grease.tar.gz" CATFOOD_GREASE_SHA256_URL="file://$tmp/grease.tar.gz.sha256" PATH=$test_path     sh "$root/sdf/provision.sh" > "$tmp/provision.out"

grep -F 'preflight=pass' "$tmp/provision.out" >/dev/null
grep -F 'grease-sdf-ready' "$tmp/provision.out" >/dev/null
grep -F 'cat food sdf runtime is current' "$tmp/provision.out" >/dev/null
test -x "$tmp/home/opt/bin/grease"
"$tmp/home/opt/bin/grease" -c 'echo installed-grease-works' |
    grep -Fx 'installed-grease-works' >/dev/null
grep -F 'repository_revision' "$tmp/home/opt/receipts/grease-netbsd-11-amd64.tsv" >/dev/null

cat > "$tmp/mailbox" <<'EOF'
From example
To: SPEC-LIST@example.org
Cc: other@example.org
Cc: SPEC-LIST@example.org
EOF

HOME="$tmp/home" MAILBOX="$tmp/mailbox" GREASE="$tmp/home/opt/bin/grease" BASELINE_SHELL=/bin/sh CATFOOD_SDF_STATE="$tmp/state"     sh "$root/sdf/benchmark-grep.sh" > "$tmp/benchmark.out"

grep -F 'PASS: baseline and Grease output match' "$tmp/benchmark.out" >/dev/null

if HOME="$tmp/home" CATFOOD_ROOT="$tmp/home/opt-bad" CATFOOD_SDF_DOWNLOADER=definitely-not-valid PATH=$test_path     sh "$root/sdf/preflight.sh" >/dev/null 2>&1; then
    printf '%s\n' 'preflight accepted an unsupported downloader name' >&2
    exit 1
fi

printf '%s\n' 'PASS sdf NetBSD Grease preflight, fetch, install, and benchmark harness'
