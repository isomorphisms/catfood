#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' 0 HUP INT TERM
mkdir -p "$temporary/bin"
cat > "$temporary/bin/uname" <<'EOF_UNAME'
#!/bin/sh
case ${1:-} in
    -s) printf '%s\n' "${CATFOOD_TEST_SYSTEM:-Darwin}" ;;
    -m) printf '%s\n' "${CATFOOD_TEST_ARCH:-arm64}" ;;
    *) exit 2 ;;
esac
EOF_UNAME
chmod 0755 "$temporary/bin/uname"

# These are synthetic selection tests, not observed Darwin acceptance.
probe() {
    env PREFIX= TERMUX_VERSION= CATFOOD_TARGET=auto \
        PATH="$temporary/bin:$PATH" "$@" sh "$root/catfood" --target
}
expect() {
    expected=$1; shift
    actual=$(probe "$@") || {
        printf 'macOS target unexpectedly rejected: %s\n' "$expected" >&2
        exit 1
    }
    [ "$actual" = "$expected" ] || {
        printf 'expected %s, got %s\n' "$expected" "$actual" >&2
        exit 1
    }
}
reject() {
    diagnostic=$1; shift
    if probe "$@" >"$temporary/out" 2>"$temporary/err"; then
        printf 'incorrect host accepted: %s\n' "$diagnostic" >&2
        exit 1
    fi
    grep -F "$diagnostic" "$temporary/err" >/dev/null || {
        cat "$temporary/err" >&2; exit 1
    }
}
expect macos-arm64 CATFOOD_TEST_SYSTEM=Darwin CATFOOD_TEST_ARCH=arm64
expect macos-arm64 CATFOOD_TEST_SYSTEM=Darwin CATFOOD_TEST_ARCH=arm64 CATFOOD_TARGET=macos-arm64
reject 'unsupported macOS Cat Food host architecture' CATFOOD_TEST_SYSTEM=Darwin CATFOOD_TEST_ARCH=x86_64
reject 'requires observed native Darwin/arm64' CATFOOD_TEST_SYSTEM=Linux CATFOOD_TEST_ARCH=aarch64 CATFOOD_TARGET=macos-arm64
reject 'requires observed native Darwin/arm64' CATFOOD_TEST_SYSTEM=Darwin CATFOOD_TEST_ARCH=x86_64 CATFOOD_TARGET=macos-arm64
reject 'requires observed Debian/Ubuntu Linux host' CATFOOD_TEST_SYSTEM=Darwin CATFOOD_TEST_ARCH=arm64 CATFOOD_TARGET=cloud
reject 'requires observed Debian/Ubuntu Linux host' CATFOOD_TEST_SYSTEM=Darwin CATFOOD_TEST_ARCH=arm64 CATFOOD_TARGET=container
reject 'unsupported automatic Cat Food host' CATFOOD_TEST_SYSTEM=FreeBSD CATFOOD_TEST_ARCH=arm64
reject 'Android/Termux identity cannot select a macOS build host' \
    CATFOOD_TEST_SYSTEM=Darwin CATFOOD_TEST_ARCH=arm64 CATFOOD_TARGET=macos-arm64 \
    PREFIX=/data/data/com.termux/files/usr TERMUX_VERSION=0.118.3

# Invalid direct-provision configurations fail before creating a workbench.
if CATFOOD_TARGET=macos-arm64 CATFOOD_TEST_SYSTEM=Darwin CATFOOD_TEST_ARCH=x86_64 \
    CATFOOD_ROOT="$temporary/invalid" PATH="$temporary/bin:$PATH" \
    sh "$root/provision.sh" >"$temporary/out" 2>"$temporary/err"; then
    printf '%s\n' 'wrong-architecture provisioning succeeded' >&2
    exit 1
fi
grep -F 'requires observed native Darwin/arm64' "$temporary/err" >/dev/null
[ ! -e "$temporary/invalid" ]

if CATFOOD_TARGET=macos-arm64 CATFOOD_TEST_SYSTEM=Darwin CATFOOD_TEST_ARCH=arm64 \
    CATFOOD_ROOT="$temporary/invalid-feed" CATFOOD_MACOS_FEED=garbage \
    PATH="$temporary/bin:$PATH" sh "$root/provision.sh" \
    >"$temporary/out" 2>"$temporary/err"; then
    printf '%s\n' 'invalid feed policy succeeded' >&2
    exit 1
fi
grep -F 'CATFOOD_MACOS_FEED must be 0 or 1' "$temporary/err" >/dev/null
[ ! -e "$temporary/invalid-feed" ]

if CATFOOD_TARGET=macos-arm64 CATFOOD_TEST_SYSTEM=Darwin CATFOOD_TEST_ARCH=arm64 \
    CATFOOD_ROOT="$temporary/invalid-build" CATFOOD_BUILD_TOOLS=1 \
    PATH="$temporary/bin:$PATH" sh "$root/provision.sh" \
    >"$temporary/out" 2>"$temporary/err"; then
    printf '%s\n' 'unqualified core build accepted' >&2
    exit 1
fi
grep -F 'core project builds are not yet qualified' "$temporary/err" >/dev/null
[ ! -e "$temporary/invalid-build" ]

printf '%s\n' 'macOS ARM64 target and provisioning negative controls PASS (synthetic)'
