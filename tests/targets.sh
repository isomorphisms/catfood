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

assert_target tablet "$(
    HOME=$temporary/home \
    PREFIX=/data/data/com.termux/files/usr \
    TERMUX_VERSION=0.118.3 \
    CATFOOD_TEST_ARCH=aarch64 \
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
assert_target cloud "$(CATFOOD_TARGET=hetzner sh "$root/catfood" --target)"

if CATFOOD_TARGET=not-a-target sh "$root/catfood" --target >/dev/null 2>&1; then
    printf '%s\n' 'invalid target unexpectedly succeeded' >&2
    exit 1
fi

sh "$root/catfood" --help |
    grep -F 'phone|tablet|container|cloud|termux|hetzner' >/dev/null

printf '%s\n' 'cat food target profiles pass'
