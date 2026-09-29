#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/catfood-sdf-test.$$
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/package" "$tmp/home" "$tmp/state" "$tmp/bin"

real_system=$(uname -s 2>/dev/null || printf '%s\n' unknown)
real_release=$(uname -r 2>/dev/null || printf '%s\n' unknown)
if [ "$real_system" = NetBSD ] && [ "$real_release" = 9.3 ]; then
    test_path=$PATH
else
    cat > "$tmp/bin/uname" <<'EOF'
#!/bin/sh
case ${1:-} in
    -s) printf '%s\n' NetBSD ;;
    -m) printf '%s\n' amd64 ;;
    -r) printf '%s\n' "${CATFOOD_TEST_RELEASE:-9.3}" ;;
    -n) printf '%s\n' catfood-sdf-test ;;
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

cat > "$tmp/package/greasecpp" <<'EOF'
#!/bin/sh
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
exec "$here/oils-for-unix" ysh "$@"
EOF
chmod +x "$tmp/package/greasecpp"
ln -s greasecpp "$tmp/package/grease"

tar -C "$tmp/package" -czf "$tmp/grease.tar.gz" .

PATH=$test_path
export PATH
. "$root/sdf/platform.sh"
sha=$(catfood_sdf_sha256 "$tmp/grease.tar.gz")
printf '%s  %s\n' "$sha" grease-netbsd-9.3-amd64.tar.gz > "$tmp/grease.tar.gz.sha256"

# Local fixture bytes intentionally override the production archive pin.
# The fetch path must still reject a checksum file that disagrees with its
# independent configured pin, so generate a test-only config copy.
sed "s/^GREASE_SHA256=.*/GREASE_SHA256=$sha/" "$root/sdf/grease-package.conf" > "$tmp/grease-package.conf"
# Point the scripts at a temporary copy of the SDF directory so production
# package metadata in the checkout is never rewritten by the test.
mkdir -p "$tmp/sdf"
for file in platform.sh preflight.sh fetch-grease.sh install-grease.sh provision.sh; do
    cp "$root/sdf/$file" "$tmp/sdf/$file"
done
cp "$tmp/grease-package.conf" "$tmp/sdf/grease-package.conf"
mkdir -p "$tmp/vendor/ai-ci/host-context"
cp "$root/vendor/ai-ci/host-context/execute.sh" "$tmp/vendor/ai-ci/host-context/execute.sh"

HOME="$tmp/home" CATFOOD_ROOT="$tmp/home/opt" CATFOOD_GREASE_URL="file://$tmp/grease.tar.gz" CATFOOD_GREASE_SHA256_URL="file://$tmp/grease.tar.gz.sha256" PATH=$test_path \
    sh "$tmp/sdf/provision.sh" > "$tmp/provision.out"

grep -F 'preflight=pass' "$tmp/provision.out" >/dev/null
grep -F 'greasecpp-sdf-ready' "$tmp/provision.out" >/dev/null
grep -F 'grease-sdf-ready' "$tmp/provision.out" >/dev/null
grep -F 'cat food sdf runtime is current' "$tmp/provision.out" >/dev/null
test -x "$tmp/home/opt/bin/grease"
test -x "$tmp/home/opt/bin/greasecpp"
"$tmp/home/opt/bin/grease" -c 'echo installed-grease-works' |
    grep -Fx 'installed-grease-works' >/dev/null
package_receipt="$tmp/home/opt/receipts/grease-netbsd-9.3-amd64-60641ddd99844655c0788f790cd3a8a14c7166fd.tsv"
grep -F 'repository_revision' "$package_receipt" >/dev/null
grep -F "pinned_sha256	$sha" "$package_receipt" >/dev/null
test -d "$tmp/home/opt/packages/grease-netbsd-9.3-amd64-60641ddd99844655c0788f790cd3a8a14c7166fd"

set -- "$tmp/home/opt/receipts"/sdf-provision.*.preflight.tsv
[ -f "$1" ]
grep -F 'final	outcome	succeeded' "$1" >/dev/null
set -- "$tmp/home/opt/receipts"/sdf-provision.*.fetch.tsv
[ -f "$1" ]
grep -F 'final	outcome	succeeded' "$1" >/dev/null

cat > "$tmp/mailbox" <<'EOF'
From example
To: SPEC-LIST@example.org
Cc: other@example.org
Cc: SPEC-LIST@example.org
EOF

HOME="$tmp/home" MAILBOX="$tmp/mailbox" GREASE="$tmp/home/opt/bin/grease" BASELINE_SHELL=/bin/sh CATFOOD_SDF_STATE="$tmp/state" \
    sh "$root/sdf/benchmark-grep.sh" > "$tmp/benchmark.out"
grep -F 'PASS: baseline and Grease output match' "$tmp/benchmark.out" >/dev/null

if HOME="$tmp/home" CATFOOD_ROOT="$tmp/home/opt-bad" CATFOOD_SDF_DOWNLOADER=definitely-not-valid PATH=$test_path \
    sh "$tmp/sdf/preflight.sh" >/dev/null 2>&1; then
    printf '%s\n' 'preflight accepted an unsupported downloader name' >&2
    exit 1
fi

mkdir -p "$tmp/wrong-bin"
cat > "$tmp/wrong-bin/uname" <<'EOF'
#!/bin/sh
case ${1:-} in
    -s) printf '%s\n' NetBSD ;;
    -m) printf '%s\n' amd64 ;;
    -r) printf '%s\n' 11.0 ;;
    -n) printf '%s\n' catfood-wrong-release-test ;;
    *) exit 2 ;;
esac
EOF
chmod +x "$tmp/wrong-bin/uname"
wrong_release_path=$tmp/wrong-bin:$PATH

if HOME="$tmp/home" CATFOOD_ROOT="$tmp/home/opt-release" PATH=$wrong_release_path \
    sh "$tmp/sdf/provision.sh" >"$tmp/wrong-release.out" 2>"$tmp/wrong-release.err"; then
    printf '%s\n' 'SDF provision accepted the wrong NetBSD release' >&2
    exit 1
fi
grep -F 'HC-RELEASE' "$tmp/wrong-release.err" >/dev/null
test ! -e "$tmp/home/opt-release/downloads/grease-netbsd-9.3-amd64.tar.gz"

printf '%s\n' 'PASS sdf NetBSD 9.3 mediated preflight, fetch, install, and benchmark harness'
