#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

fake_bin=$temporary/bin
mkdir -p "$fake_bin" "$temporary/home"
cat > "$fake_bin/uname" <<'EOF'
#!/bin/sh
case ${1:-} in
    -m) printf '%s\n' "$CATFOOD_TEST_ARCH" ;;
    -s) printf '%s\n' "$CATFOOD_TEST_SYSTEM" ;;
    -r) printf '%s\n' "${CATFOOD_TEST_RELEASE:-test-release}" ;;
    *) exit 2 ;;
esac
EOF
chmod 0755 "$fake_bin/uname"

debian_release=$temporary/debian-os-release
ubuntu_release=$temporary/ubuntu-os-release
other_release=$temporary/other-os-release
printf '%s\n' 'ID=debian' > "$debian_release"
printf '%s\n' 'ID="ubuntu"' > "$ubuntu_release"
printf '%s\n' 'ID=fedora' > "$other_release"

assert_target() {
    expected=$1
    actual=$2
    if [ "$actual" != "$expected" ]; then
        printf 'expected target %s, found %s\n' "$expected" "$actual" >&2
        exit 1
    fi
}

run_detect() {
    CATFOOD_TEST_SYSTEM=$1     CATFOOD_TEST_ARCH=$2     CATFOOD_OS_RELEASE=${3:-$debian_release}     HOME=$temporary/home     PREFIX= TERMUX_VERSION=     PATH=$fake_bin:$PATH         sh "$root/catfood" --target
}

assert_target phone "$(
    HOME=$temporary/home     PREFIX=/data/data/com.termux/files/usr     TERMUX_VERSION=0.118.3     CATFOOD_TEST_SYSTEM=Linux     CATFOOD_TEST_ARCH=armv7l     PATH=$fake_bin:$PATH         sh "$root/catfood" --target
)"

assert_target tablet "$(
    HOME=$temporary/home     PREFIX=/data/data/com.termux/files/usr     TERMUX_VERSION=0.118.3     CATFOOD_TEST_SYSTEM=Linux     CATFOOD_TEST_ARCH=aarch64     PATH=$fake_bin:$PATH         sh "$root/catfood" --target
)"

assert_target termux "$(
    HOME=$temporary/home     PREFIX=/data/data/com.termux/files/usr     TERMUX_VERSION=0.118.3     CATFOOD_TEST_SYSTEM=Linux     CATFOOD_TEST_ARCH=x86_64     PATH=$fake_bin:$PATH         sh "$root/catfood" --target
)"

assert_target netbsd "$(run_detect NetBSD amd64)"
assert_target netbsd "$(run_detect NetBSD x86_64)"
assert_target cloud "$(run_detect Linux x86_64 "$debian_release")"
assert_target cloud "$(run_detect Linux x86_64 "$ubuntu_release")"

if run_detect Linux x86_64 "$other_release" >/dev/null 2>&1; then
    printf '%s\n' 'unsupported Linux distribution unexpectedly selected a target' >&2
    exit 1
fi

if run_detect Darwin x86_64 >/dev/null 2>&1; then
    printf '%s\n' 'unknown non-Termux operating system unexpectedly selected a target' >&2
    exit 1
fi

if run_detect NetBSD aarch64 >/dev/null 2>&1; then
    printf '%s\n' 'unsupported NetBSD architecture unexpectedly selected a target' >&2
    exit 1
fi

assert_target container "$(CATFOOD_TARGET=container sh "$root/catfood" --target)"
assert_target cloud "$(CATFOOD_TARGET=hetzner sh "$root/catfood" --target)"
assert_target netbsd "$(CATFOOD_TARGET=netbsd sh "$root/catfood" --target)"
assert_target sdf "$(CATFOOD_TARGET=sdf sh "$root/catfood" --target)"

if HOME=$temporary/home PREFIX= TERMUX_VERSION= CATFOOD_TEST_SYSTEM=NetBSD CATFOOD_TEST_ARCH=amd64 PATH=$fake_bin:$PATH \
    sh "$root/catfood" >"$temporary/netbsd.out" 2>"$temporary/netbsd.err"; then
    printf '%s\n' 'generic NetBSD unexpectedly entered provisioning' >&2
    exit 1
fi
grep -F 'generic NetBSD host' "$temporary/netbsd.err" >/dev/null

if HOME=$temporary/home PREFIX= TERMUX_VERSION= CATFOOD_TEST_SYSTEM=NetBSD CATFOOD_TEST_ARCH=amd64 PATH=$fake_bin:$PATH \
    sh "$root/provision.sh" >"$temporary/netbsd-provision.out" 2>"$temporary/netbsd-provision.err"; then
    printf '%s\n' 'direct provision.sh unexpectedly provisioned generic NetBSD' >&2
    exit 1
fi
grep -F 'generic NetBSD host' "$temporary/netbsd-provision.err" >/dev/null

if CATFOOD_TARGET=not-a-target sh "$root/catfood" --target >/dev/null 2>&1; then
    printf '%s\n' 'invalid target unexpectedly succeeded' >&2
    exit 1
fi

sh "$root/catfood" --help |
    grep -F 'phone|tablet|container|cloud|termux|netbsd|sdf|hetzner' >/dev/null

printf '%s\n' 'cat food target profiles pass'
