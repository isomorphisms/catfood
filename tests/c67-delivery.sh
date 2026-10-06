#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fake_bin=$tmp/bin
release=$tmp/release
bundle=$tmp/bundle
workspace=$tmp/workspace
cache=$tmp/cache
mkdir -p "$fake_bin" "$release" "$bundle/bin" "$workspace" "$cache"

cat > "$bundle/bin/c67-fixture" <<'EOF_FIXTURE'
#!/bin/sh
printf '%s\n' c67-pass
EOF_FIXTURE
chmod 0755 "$bundle/bin/c67-fixture"
tar -C "$bundle" -czf "$release/c67-fixture.tar.gz" .
digest=$(sha256sum "$release/c67-fixture.tar.gz" | awk '{print $1}')

cat > "$fake_bin/getprop" <<'EOF_GETPROP'
#!/bin/sh
case ${1:-} in
    ro.product.device) printf '%s\n' "${CATFOOD_TEST_DEVICE:-Miro_C67}" ;;
    ro.product.model) printf '%s\n' "${CATFOOD_TEST_MODEL:-Miro C67}" ;;
    ro.product.cpu.abi) printf '%s\n' arm64-v8a ;;
    ro.build.fingerprint) printf '%s\n' MIRO/C67/Miro_C67:14/fixture:user/release-keys ;;
    *) printf '\n' ;;
esac
EOF_GETPROP

cat > "$fake_bin/curl" <<'EOF_CURL'
#!/bin/sh
set -eu
output=
url=
while [ "$#" -gt 0 ]; do
    case $1 in
        -o) shift; output=$1 ;;
        https://*) url=$1 ;;
    esac
    shift
done
[ "$url" = https://example.invalid/c67-fixture.tar.gz ]
cp "$CATFOOD_TEST_RELEASE/c67-fixture.tar.gz" "$output"
EOF_CURL
chmod 0755 "$fake_bin/getprop" "$fake_bin/curl"

tools=$tmp/tools.tsv
delivery=$tmp/delivery.tsv
packages=$tmp/packages.tsv
source_ref=1111111111111111111111111111111111111111
package_ref=2222222222222222222222222222222222222222

cat > "$tools" <<'EOF_TOOLS'
fixture https://github.com/isomorphisms/fixture.git main none
EOF_TOOLS
cat > "$delivery" <<'EOF_DELIVERY'
# name	role	phone	tablet	note
grease	reference	n/a	n/a	fixture
fixture	runtime	gap:not-published	package:c67-fixture-arm64	fixture
EOF_DELIVERY
cat > "$packages" <<EOF_PACKAGES
# package	target	abi	mode	source	source_ref	package_ref	url	sha256	command	entrypoint	main_class	jni_library	jni_property	install_requires	termux_packages	runtime_requires	package_requires
c67-fixture-arm64	tablet	arm64-v8a	archive	isomorphisms/fixture	$source_ref	$package_ref	https://example.invalid/c67-fixture.tar.gz	$digest	c67-fixture	bin/c67-fixture	-	-	-	curl,tar	-	-	-
EOF_PACKAGES

CATFOOD_TOOLS="$tools" \
CATFOOD_ANDROID_DELIVERY="$delivery" \
CATFOOD_ANDROID_PACKAGES="$packages" \
    sh "$root/android/check.sh" ready c67 >/dev/null

PATH="$fake_bin:$PATH" \
CATFOOD_TEST_RELEASE="$release" \
CATFOOD_DEVICE_ABI=arm64-v8a \
CATFOOD_TARGET=c67 \
CATFOOD_ROOT="$workspace" \
CATFOOD_CACHE="$cache" \
CATFOOD_TOOLS="$tools" \
CATFOOD_ANDROID_DELIVERY="$delivery" \
CATFOOD_ANDROID_PACKAGES="$packages" \
    sh "$root/android/install.sh" >/dev/null

test "$("$workspace/bin/c67-fixture")" = c67-pass
receipt="$workspace/receipts/c67-c67-fixture-arm64.tsv"
test -f "$receipt"
grep -Fqx 'target	tablet' "$receipt"
grep -Fqx 'device_target	c67' "$receipt"
grep -Fqx 'device_product	Miro_C67' "$receipt"
grep -Fqx 'device_model	Miro C67' "$receipt"
grep -Fqx 'abi	arm64-v8a' "$receipt"
CATFOOD_TOOLS="$tools" \
CATFOOD_ANDROID_DELIVERY="$delivery" \
CATFOOD_ANDROID_PACKAGES="$packages" \
    sh "$root/android/check.sh" receipt "$receipt" >/dev/null

if PATH="$fake_bin:$PATH" \
   CATFOOD_TEST_DEVICE=Other_AArch64 \
   CATFOOD_TEST_MODEL='Other AArch64' \
   CATFOOD_DEVICE_ABI=arm64-v8a \
   CATFOOD_TARGET=c67 \
   CATFOOD_ROOT="$tmp/wrong-device" \
   CATFOOD_CACHE="$tmp/wrong-cache" \
   CATFOOD_TOOLS="$tools" \
   CATFOOD_ANDROID_DELIVERY="$delivery" \
   CATFOOD_ANDROID_PACKAGES="$packages" \
       sh "$root/android/install.sh" >/dev/null 2>&1; then
    printf '%s\n' 'C67 delivery accepted a non-C67 AArch64 device' >&2
    exit 1
fi

printf '%s\n' 'Cat Food C67 delivery target contract passes'
