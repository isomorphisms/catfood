#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

fake_bin=$temporary/bin
mkdir -p "$fake_bin" "$temporary/home"
cat > "$fake_bin/uname" <<'EOF'
#!/bin/sh
[ "${1:-}" = -m ] || exit 2
printf '%s\n' "$CATFOOD_TEST_ARCH"
EOF
chmod 0755 "$fake_bin/uname"
cat > "$fake_bin/getprop" <<'EOF'
#!/bin/sh
case ${1:-} in
    ro.product.device) printf '%s\n' "${CATFOOD_TEST_DEVICE:-Other_AArch64}" ;;
    ro.product.model) printf '%s\n' "${CATFOOD_TEST_MODEL:-Other AArch64}" ;;
    ro.product.cpu.abi) printf '%s\n' "${CATFOOD_TEST_ABI:-arm64-v8a}" ;;
    ro.build.fingerprint) printf '%s\n' "${CATFOOD_TEST_FINGERPRINT:-fixture/fingerprint}" ;;
    ro.build.version.sdk) printf '%s\n' "${CATFOOD_TEST_SDK:-34}" ;;
    *) printf '\n' ;;
esac
EOF
chmod 0755 "$fake_bin/getprop"

assert_target() {
    expected=$1
    actual=$2
    if [ "$actual" != "$expected" ]; then
        printf 'expected target %s, found %s\n' "$expected" "$actual" >&2
        exit 1
    fi
}

assert_target phone "$(
    HOME=$temporary/home \
    PREFIX=/data/data/com.termux/files/usr \
    TERMUX_VERSION=0.118.3 \
    CATFOOD_TEST_ARCH=armv7l \
    PATH=$fake_bin:$PATH \
        sh "$root/catfood" --target
)"

assert_target c67 "$(
    HOME=$temporary/home \
    PREFIX=/data/data/com.termux/files/usr \
    TERMUX_VERSION=0.118.3 \
    CATFOOD_TEST_ARCH=aarch64 \
    CATFOOD_TEST_DEVICE=Miro_C67 \
    CATFOOD_TEST_MODEL='Miro C67' \
    PATH=$fake_bin:$PATH \
        sh "$root/catfood" --target
)"

assert_target tablet "$(
    HOME=$temporary/home \
    PREFIX=/data/data/com.termux/files/usr \
    TERMUX_VERSION=0.118.3 \
    CATFOOD_TEST_ARCH=aarch64 \
    CATFOOD_TEST_DEVICE=Other_AArch64 \
    CATFOOD_TEST_MODEL='Other AArch64' \
    PATH=$fake_bin:$PATH \
        sh "$root/catfood" --target
)"

assert_target termux "$(
    HOME=$temporary/home \
    PREFIX=/data/data/com.termux/files/usr \
    TERMUX_VERSION=0.118.3 \
    CATFOOD_TEST_ARCH=x86_64 \
    PATH=$fake_bin:$PATH \
        sh "$root/catfood" --target
)"

assert_target cloud "$(PREFIX= TERMUX_VERSION= sh "$root/catfood" --target)"
assert_target container "$(CATFOOD_TARGET=container sh "$root/catfood" --target)"
assert_target c67 "$(CATFOOD_TARGET=c67 sh "$root/catfood" --target)"
assert_target cloud "$(CATFOOD_TARGET=hetzner sh "$root/catfood" --target)"

if CATFOOD_TARGET=not-a-target sh "$root/catfood" --target >/dev/null 2>&1; then
    printf '%s\n' 'invalid target unexpectedly succeeded' >&2
    exit 1
fi

sh "$root/catfood" --help |
    grep -F 'phone|c67|tablet|container|cloud|termux|hetzner' >/dev/null

probe_root=$temporary/c67-probe
mkdir -p "$probe_root/bin" "$probe_root/receipts"
cat > "$probe_root/bin/jq" <<'EOF'
#!/bin/sh
[ "${1:-}" = --version ] && { printf '%s\n' 'jq-1.8.2'; exit 0; }
exit 2
EOF
chmod 0755 "$probe_root/bin/jq"
cat > "$probe_root/receipts/runtime-binary-linux-aarch64-jq.tsv" <<'EOF'
schema	catfood-runtime-binary-v1
platform	linux-aarch64
runtime_probe_result	PASS
EOF
cat > "$fake_bin/getconf" <<'EOF'
#!/bin/sh
[ "${1:-}" = PAGESIZE ] && { printf '%s\n' 4096; exit 0; }
exit 2
EOF
chmod 0755 "$fake_bin/getconf"
CATFOOD_ROOT=$probe_root \
CATFOOD_TEST_ARCH=aarch64 \
CATFOOD_TEST_DEVICE=Miro_C67 \
CATFOOD_TEST_MODEL='Miro C67' \
CATFOOD_TEST_ABI=arm64-v8a \
PATH=$fake_bin:$PATH \
    sh "$root/android/record-c67-runtime.sh" >/dev/null
grep -Fx 'target	c67' "$probe_root/receipts/c67-runtime.tsv" >/dev/null
grep -Fx 'delivery_target	tablet' "$probe_root/receipts/c67-runtime.tsv" >/dev/null
grep -Fx 'page_size_bytes	4096' "$probe_root/receipts/c67-runtime.tsv" >/dev/null
grep -Fx 'native_probe_result	PASS' "$probe_root/receipts/c67-runtime.tsv" >/dev/null

printf '%s\n' 'cat food target profiles pass'
