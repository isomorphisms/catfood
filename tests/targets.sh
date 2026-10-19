#!/bin/sh
set -eu
root=${CATFOOD_TEST_SUBJECT_ROOT:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
mkdir -p "$temporary/bin" "$temporary/home"
fake_bin=$temporary/bin
cp "$root/tests/android-properties.sh" "$fake_bin/getprop"
cat > "$fake_bin/uname" <<'EOF'
#!/bin/sh
case $1 in
    -m) printf '%s\n' "${CATFOOD_TEST_ARCH:-aarch64}" ;;
    -s) printf '%s\n' "${CATFOOD_TEST_SYSTEM:-Linux}" ;;
    *) exit 2 ;;
esac
EOF
chmod +x "$fake_bin/getprop" "$fake_bin/uname"
probe() {
    env HOME="$temporary/home" PREFIX=/data/data/com.termux/files/usr TERMUX_VERSION=0.118.3 \
        PATH="$fake_bin:$PATH" CATFOOD_TARGET=auto "$@" sh "$root/catfood" --target
}
expect() {
    expected=$1; shift
    actual=$(probe "$@")
    [ "$actual" = "$expected" ] || { printf 'expected %s, found %s\n' "$expected" "$actual" >&2; exit 1; }
}
reject() {
    diagnostic=$1; shift
    if probe "$@" >"$temporary/out" 2>"$temporary/err"; then
        printf '%s\n' 'inconsistent identity unexpectedly accepted' >&2; exit 1
    fi
    grep -F "$diagnostic" "$temporary/err" >/dev/null
}
expect phone CATFOOD_TEST_ARCH=armv7l CATFOOD_TEST_DEVICE= CATFOOD_TEST_MODEL='MIRO A1' CATFOOD_TEST_ABI=armeabi-v7a
expect c67 CATFOOD_TEST_ARCH=aarch64 CATFOOD_TEST_DEVICE=Miro_C67 CATFOOD_TEST_MODEL='Miro C67' CATFOOD_TEST_ABI=arm64-v8a
expect tablet CATFOOD_TEST_ARCH=aarch64 CATFOOD_TEST_DEVICE=TAB_P10_ROW CATFOOD_TEST_MODEL=TAB_P10 CATFOOD_TEST_ABI=arm64-v8a
expect termux CATFOOD_TEST_ARCH=aarch64 CATFOOD_TEST_DEVICE=Other CATFOOD_TEST_MODEL=Other CATFOOD_TEST_ABI=arm64-v8a
expect termux CATFOOD_TEST_ARCH=armv7l CATFOOD_TEST_DEVICE=Other CATFOOD_TEST_MODEL=Other CATFOOD_TEST_ABI=armeabi-v7a
expect termux CATFOOD_TEST_ARCH=aarch64 CATFOOD_TEST_DEVICE= CATFOOD_TEST_MODEL= CATFOOD_TEST_ABI=
reject 'conflicting Android identity' CATFOOD_TEST_DEVICE=Miro_C67 CATFOOD_TEST_MODEL=TAB_P10 CATFOOD_TEST_ABI=arm64-v8a
reject 'conflicting Android identity' CATFOOD_TEST_DEVICE=Miro_C67 CATFOOD_TEST_MODEL=Unknown CATFOOD_TEST_ABI=arm64-v8a
reject 'identity/ABI mismatch' CATFOOD_TEST_DEVICE=Miro_C67 CATFOOD_TEST_MODEL='Miro C67' CATFOOD_TEST_ABI=armeabi-v7a
reject 'target mismatch' CATFOOD_TARGET=tablet CATFOOD_TEST_DEVICE=Miro_C67 CATFOOD_TEST_MODEL='Miro C67' CATFOOD_TEST_ABI=arm64-v8a
reject 'target mismatch' CATFOOD_TARGET=c67 CATFOOD_TEST_DEVICE=TAB_P10_ROW CATFOOD_TEST_MODEL=TAB_P10 CATFOOD_TEST_ABI=arm64-v8a
reject 'unknown Android identity' CATFOOD_TARGET=tablet CATFOOD_TEST_DEVICE=Other CATFOOD_TEST_MODEL=Other CATFOOD_TEST_ABI=arm64-v8a
reject 'cannot be selected as a build workbench' CATFOOD_TARGET=cloud
expect c67 CATFOOD_TARGET=c67 CATFOOD_TEST_DEVICE=Miro_C67 CATFOOD_TEST_MODEL='Miro C67' CATFOOD_TEST_ABI=arm64-v8a
# Explicit host planning selections work; host absence never proves cloud.
[ "$(CATFOOD_TARGET=container sh "$root/catfood" --target)" = container ]
[ "$(CATFOOD_TARGET=hetzner sh "$root/catfood" --target)" = cloud ]
if PREFIX= TERMUX_VERSION= CATFOOD_TEST_SYSTEM=NetBSD PATH="$fake_bin:$PATH" sh "$root/catfood" --target >"$temporary/out" 2>"$temporary/err"; then exit 1; fi
grep -F 'unsupported automatic Cat Food host' "$temporary/err" >/dev/null
if CATFOOD_TARGET=termux CATFOOD_ROOT="$temporary/untouched" sh "$root/provision.sh" >"$temporary/out" 2>"$temporary/err"; then exit 1; fi
grep -F 'Generic Termux' "$temporary/err" >/dev/null
[ ! -e "$temporary/untouched" ]
printf '%s\n' 'Cat Food device classification and contradictory-override probes pass (synthetic)'

# The C67 support-runtime observation binds the executable digest, not just
# a jq-looking version string or a stale platform receipt.
probe_root=$temporary/c67-probe
mkdir -p "$probe_root/bin" "$probe_root/receipts"
cat > "$probe_root/bin/jq" <<'EOF_JQ'
#!/bin/sh
printf '%s\n' jq-synthetic
EOF_JQ
chmod +x "$probe_root/bin/jq"
probe_sha=$(sha256sum "$probe_root/bin/jq" | awk '{print $1}')
printf 'jq\tfixture/jq\tsynthetic\tlinux-aarch64\tfile\thttps://example.invalid/jq\t%s\t-\t--version\tsynthetic\n' "$probe_sha" > "$temporary/binaries.tsv"
printf 'schema\tcatfood-runtime-binary-v1\nplatform\tlinux-aarch64\nruntime_probe_result\tPASS\n' > "$probe_root/receipts/runtime-binary-linux-aarch64-jq.tsv"
CATFOOD_TARGET=c67 CATFOOD_ROOT="$probe_root" CATFOOD_DEVICE_ID=synthetic-c67 \
    CATFOOD_BINARY_MANIFEST="$temporary/binaries.tsv" PATH="$fake_bin:$PATH" \
    sh "$root/android/record-c67-runtime.sh" >/dev/null
grep -Fqx 'package_lane	arm64-v8a' "$probe_root/receipts/c67-runtime.tsv"
grep -Fqx "native_probe_sha256$(printf '\t')$probe_sha" "$probe_root/receipts/c67-runtime.tsv"
printf '\n# changed executable\n' >> "$probe_root/bin/jq"
if CATFOOD_TARGET=c67 CATFOOD_ROOT="$probe_root" CATFOOD_DEVICE_ID=synthetic-c67 \
    CATFOOD_BINARY_MANIFEST="$temporary/binaries.tsv" PATH="$fake_bin:$PATH" \
    sh "$root/android/record-c67-runtime.sh" >"$temporary/digest.out" 2>&1; then
    printf '%s\n' 'C67 runtime observation accepted a changed executable' >&2; exit 1
fi
grep -F 'did NOT match' "$temporary/digest.out" >/dev/null
