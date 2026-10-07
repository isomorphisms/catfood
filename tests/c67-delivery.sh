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
c67-fixture-arm64	arm64-v8a	arm64-v8a	archive	isomorphisms/fixture	$source_ref	$package_ref	https://example.invalid/c67-fixture.tar.gz	$digest	c67-fixture	bin/c67-fixture	-	-	-	curl,tar	-	-	-
EOF_PACKAGES

CATFOOD_TOOLS="$tools" \
CATFOOD_ANDROID_DELIVERY="$delivery" \
CATFOOD_ANDROID_PACKAGES="$packages" \
    sh "$root/android/check.sh" ready c67 >/dev/null

PATH="$fake_bin:$PATH" \
CATFOOD_TEST_RELEASE="$release" \
CATFOOD_DEVICE_ID=synthetic-c67 \
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
grep -Fqx 'target	c67' "$receipt"
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

# Identical archive bytes reused for TAB_P10, with separate instance/target
# records. Every "physical" result below is a synthetic validator fixture.
cp "$root/tests/android-properties.sh" "$fake_bin/getprop"
chmod +x "$fake_bin/getprop"
export CATFOOD_TOOLS="$tools" CATFOOD_ANDROID_DELIVERY="$delivery" CATFOOD_ANDROID_PACKAGES="$packages"
PATH="$fake_bin:$PATH" CATFOOD_TEST_RELEASE="$release" CATFOOD_TARGET=tablet \
    CATFOOD_DEVICE_ID=synthetic-tablet CATFOOD_ROOT="$workspace" CATFOOD_CACHE="$cache" \
    sh "$root/android/install.sh" >/dev/null
tablet_receipt="$workspace/receipts/tablet-c67-fixture-arm64.tsv"
test -f "$receipt"
test -f "$tablet_receipt"
grep -Fqx "sha256$(printf '\t')$digest" "$receipt"
grep -Fqx "sha256$(printf '\t')$digest" "$tablet_receipt"
grep -Fqx 'package_lane	arm64-v8a' "$receipt"
grep -Fqx 'package_lane	arm64-v8a' "$tablet_receipt"

promote_fixture() {
    awk -F '\t' -v OFS='\t' '
        $1 ~ /^(launch|runtime|physical_device)_result$/ {$2="PASS"}
        $1 ~ /^(launch|runtime|physical_device)_evidence$/ {$2="synthetic-validator-fixture"}
        {print}
    ' "$1" > "$2"
}
promote_fixture "$receipt" "$tmp/c67-physical.tsv"
promote_fixture "$tablet_receipt" "$tmp/tablet-physical.tsv"
sh "$root/android/check.sh" schema "$tmp/c67-physical.tsv" c67 synthetic-c67 >/dev/null
sh "$root/android/check.sh" schema "$tmp/tablet-physical.tsv" tablet synthetic-tablet >/dev/null
reject_receipt() {
    diagnostic=$1; shift
    validator=receipt
    # Identity negatives exercise the schema boundary itself, so unrelated
    # execution-evidence rejection cannot conceal a removed identity guard.
    case $diagnostic in
        *target*|*instance*|*identity*|*device*|*fingerprint*) validator=schema ;;
    esac
    if sh "$root/android/check.sh" "$validator" "$@" >"$tmp/rejected.out" 2>&1; then
        printf '%s\n' 'cross-device or malformed receipt accepted' >&2; exit 1
    fi
    grep -F "$diagnostic" "$tmp/rejected.out" >/dev/null
}
reject_receipt 'another target' "$tmp/c67-physical.tsv" tablet
reject_receipt 'unverified execution claim' "$tmp/c67-physical.tsv" c67 synthetic-c67
reject_receipt 'unverified execution claim' "$tmp/tablet-physical.tsv" tablet synthetic-tablet
reject_receipt 'another target' "$tmp/tablet-physical.tsv" c67
reject_receipt 'another target' "$tmp/c67-physical.tsv" phone
reject_receipt 'another device instance' "$tmp/c67-physical.tsv" c67 another-c67
sed 's/^device_model	.*/device_model	TAB_P10/' "$tmp/c67-physical.tsv" > "$tmp/spoof.tsv"
reject_receipt 'conflicting Android identity' "$tmp/spoof.tsv"
sed '/^device_target	/d' "$tmp/c67-physical.tsv" > "$tmp/missing-identity.tsv"
reject_receipt 'missing required field: device_target' "$tmp/missing-identity.tsv"
sed -e 's/^target	c67/target	tablet/' -e 's/^device_target	c67/device_target	tablet/' \
    -e 's/^device_class	phone/device_class	tablet/' "$tmp/c67-physical.tsv" > "$tmp/relabel.tsv"
reject_receipt 'identity does not match target' "$tmp/relabel.tsv"
# A copied receipt at the expected filename must be replaced, not treated as
# current merely because the ABI and archive are identical.
cp "$receipt" "$tablet_receipt"
PATH="$fake_bin:$PATH" CATFOOD_TEST_RELEASE="$release" CATFOOD_TARGET=tablet \
    CATFOOD_DEVICE_ID=synthetic-tablet CATFOOD_ROOT="$workspace" CATFOOD_CACHE="$cache" \
    sh "$root/android/install.sh" >"$tmp/reinstall.out"
grep -Fqx 'target	tablet' "$tablet_receipt"
grep -Fqx 'physical_device_result	NOT_VERIFIED' "$tablet_receipt"
printf '%s\n' 'Shared ARM64 bytes retain independent C67/tablet acceptance identities (synthetic)'

# A valid ABI is insufficient for a package with a device-specific contract.
restrictions=$tmp/restrictions.tsv
printf 'c67-fixture-arm64\ttablet\tMali-only-fixture\tsynthetic\n' > "$restrictions"
export CATFOOD_ANDROID_RESTRICTIONS="$restrictions"
reject_receipt 'restricted to another device' "$tmp/c67-physical.tsv"
sh "$root/android/check.sh" schema "$tmp/tablet-physical.tsv" tablet synthetic-tablet >/dev/null
sh "$root/android/check.sh" gaps c67 | grep -F 'gap:package-not-compatible-with-device' >/dev/null
if sh "$root/android/check.sh" ready c67 >"$tmp/restricted-ready.out" 2>&1; then exit 1; fi
PATH="$fake_bin:$PATH" CATFOOD_TEST_RELEASE="$release" CATFOOD_TARGET=c67 \
    CATFOOD_DEVICE_ID=synthetic-c67 CATFOOD_ROOT="$tmp/restricted-workspace" CATFOOD_CACHE="$cache" \
    sh "$root/android/install.sh" >"$tmp/restricted-install.out"
test ! -e "$tmp/restricted-workspace/bin/c67-fixture"
grep -F 'not compatible with device target c67' "$tmp/restricted-install.out" >/dev/null
printf '%s\n' 'Device-specific package restriction passes positive and negative controls'

# Producer policy must not silently demote A1 or treat native ARM32 on C67 as A1.
policy_root=$tmp/policy
mkdir -p "$policy_root/android"
cp "$root/android/check.sh" "$root/android/content.sh" "$root/android/target.sh" "$root/android/application-targets.tsv" \
    "$root/android/conversation-targets.tsv" "$root/android/package-restrictions.tsv" "$policy_root/android/"
sed 's/primary/paired/' "$root/android/application-targets.tsv" > "$policy_root/android/application-targets.tsv"
if sh "$policy_root/android/check.sh" check >"$tmp/policy.out" 2>&1; then exit 1; fi
grep -F 'A1-primary/C67-paired producer policy mismatch' "$tmp/policy.out" >/dev/null
cp "$root/android/application-targets.tsv" "$policy_root/android/application-targets.tsv"
sed 's/arm64-v8a/armeabi-v7a/' "$root/android/conversation-targets.tsv" > "$policy_root/android/conversation-targets.tsv"
if sh "$policy_root/android/check.sh" check >"$tmp/policy.out" 2>&1; then exit 1; fi
grep -F 'A1-primary/C67-paired producer policy mismatch' "$tmp/policy.out" >/dev/null
