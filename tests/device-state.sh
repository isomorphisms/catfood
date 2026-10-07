#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fake_bin=$tmp/bin
home=$tmp/home
workspace=$tmp/workspace
manager=$tmp/manager
state=$tmp/state
mkdir -p "$fake_bin" "$home" "$workspace/receipts" \
    "$workspace/packages/app-phone/1111111111111111111111111111111111111111" \
    "$workspace/packages/helper-phone/2222222222222222222222222222222222222222" \
    "$workspace/packages/old-phone/9999999999999999999999999999999999999999"

cat > "$fake_bin/getprop" <<'EOF'
#!/bin/sh
case "$1" in
    ro.product.cpu.abi) printf '%s\n' "${CATFOOD_DEVICE_ABI:-armeabi-v7a}" ;;
    ro.product.manufacturer) printf '%s\n' Foxx ;;
    ro.product.brand) printf '%s\n' MIRO ;;
    ro.product.model) printf '%s\n' "${CATFOOD_TEST_MODEL:-MIRO A1}" ;;
    ro.build.version.release) printf '%s\n' 14 ;;
    ro.build.version.sdk) printf '%s\n' 34 ;;
esac
EOF
cat > "$fake_bin/pm" <<'EOF'
#!/bin/sh
[ "$1 $2 $3" = 'list packages -3' ] || exit 2
printf '%s\n' package:com.example.reader package:com.example.maps
EOF
cat > "$fake_bin/dpkg-query" <<'EOF'
#!/bin/sh
printf 'curl\t8.0\ntermux-api\t1.0\n'
EOF
chmod 0755 "$fake_bin/getprop" "$fake_bin/pm" "$fake_bin/dpkg-query"

cat > "$workspace/receipts/phone-app-phone.tsv" <<'EOF'
package	app-phone
package_ref	1111111111111111111111111111111111111111
installation_result	PASS
EOF
cat > "$workspace/receipts/phone-old-phone.tsv" <<'EOF'
package	old-phone
package_ref	9999999999999999999999999999999999999999
installation_result	PASS
EOF

packages=$tmp/packages.tsv
cat > "$packages" <<'EOF'
# package	target	abi	mode	source	source_ref	package_ref	url	sha256	command	entrypoint	main_class	jni_library	jni_property	install_requires	termux_packages	runtime_requires	package_requires
app-phone	armeabi-v7a	armeabi-v7a	file	fixture/app	aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa	1111111111111111111111111111111111111111	https://example.invalid/app	0000000000000000000000000000000000000000000000000000000000000000	app	bin/app	-	-	-	-	-	-	-
helper-phone	armeabi-v7a	armeabi-v7a	file	fixture/helper	aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa	2222222222222222222222222222222222222222	https://example.invalid/helper	0000000000000000000000000000000000000000000000000000000000000000	helper	bin/helper	-	-	-	-	-	-	-
missing-phone	armeabi-v7a	armeabi-v7a	file	fixture/missing	aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa	3333333333333333333333333333333333333333	https://example.invalid/missing	0000000000000000000000000000000000000000000000000000000000000000	missing	bin/missing	-	-	-	-	-	-	-
EOF

common() {
    PATH="$fake_bin:$PATH" \
    HOME="$home" \
    XDG_STATE_HOME="$state" \
    CATFOOD_ROOT="$workspace" \
    CATFOOD_ANDROID_PACKAGES="$packages" \
    CATFOOD_MANAGER_STATE="$manager" \
    CATFOOD_DEVICE_ID=miro-a1-fixture \
    CATFOOD_DEVICE_NAME=main-a1 \
        "$@"
}

android_packages_sha256=$(printf '%s\n' com.example.maps com.example.reader | LC_ALL=C sort -u | sha256sum | awk '{ print $1 }')
termux_packages_sha256=$(printf 'curl\t8.0\ntermux-api\t1.0\n' | LC_ALL=C sort -u | sha256sum | awk '{ print $1 }')

common sh "$root/catfood" inspect > "$tmp/inventory.tsv"
grep -Fx 'meta	device_id	miro-a1-fixture	local-state' "$tmp/inventory.tsv" >/dev/null
grep -Fx 'meta	model	MIRO A1	getprop' "$tmp/inventory.tsv" >/dev/null
grep -Fx 'android_package	com.example.reader	-	pm-user' "$tmp/inventory.tsv" >/dev/null
grep -Fx 'termux_package	curl	8.0	dpkg-query' "$tmp/inventory.tsv" >/dev/null
grep -Fx "meta	android_packages_sha256	$android_packages_sha256	pm-user+sha256" "$tmp/inventory.tsv" >/dev/null
grep -Fx "meta	termux_packages_sha256	$termux_packages_sha256	dpkg-query+sha256" "$tmp/inventory.tsv" >/dev/null

common sh "$root/catfood" packages > "$tmp/package-list.tsv"
grep -Fx 'android_package	com.example.reader	-	pm-user' "$tmp/package-list.tsv" >/dev/null
grep -Fx 'termux_package	termux-api	1.0	dpkg-query' "$tmp/package-list.tsv" >/dev/null
test -f "$state/catfood/device/inventory.tsv"
test "$(find "$state/catfood/device/inspections" -type f | wc -l | tr -d ' ')" -eq 1

common sh "$root/catfood" record "$tmp/inventory.tsv" > "$tmp/record.out"
grep -F 'miro-a1-fixture	phone	' "$tmp/record.out" >/dev/null
test -f "$manager/register.tsv"
test -f "$manager/devices/miro-a1-fixture/inventory.tsv"

common sh "$root/catfood" compare miro-a1-fixture > "$tmp/compare.tsv"
grep -Fx 'unconfirmed	app-phone	1111111111111111111111111111111111111111	1111111111111111111111111111111111111111	receipt:NOT_VERIFIED' "$tmp/compare.tsv" >/dev/null
grep -Fx 'unrecorded	helper-phone	2222222222222222222222222222222222222222	2222222222222222222222222222222222222222	package-directory' "$tmp/compare.tsv" >/dev/null
grep -Fx 'missing	missing-phone	-	3333333333333333333333333333333333333333	not-observed' "$tmp/compare.tsv" >/dev/null
grep -Fx 'undeclared	old-phone	9999999999999999999999999999999999999999	-	receipt:NOT_VERIFIED' "$tmp/compare.tsv" >/dev/null

common sh "$root/catfood" report > "$tmp/report.tsv"
grep -F "miro-a1-fixture	main-a1	MIRO A1	phone	" "$tmp/report.tsv" |
    grep -F "	$android_packages_sha256	$termux_packages_sha256	0	1	0	1	1	1	0" >/dev/null

# Re-evaluate the saved observation against changed repository intent without
# asking the phone to inspect itself again.
packages_v2=$tmp/packages-v2.tsv
sed 's/1111111111111111111111111111111111111111/4444444444444444444444444444444444444444/g' \
    "$packages" > "$packages_v2"
PATH="$fake_bin:$PATH" \
HOME="$home" \
XDG_STATE_HOME="$state" \
CATFOOD_ROOT="$workspace" \
CATFOOD_ANDROID_PACKAGES="$packages_v2" \
CATFOOD_MANAGER_STATE="$manager" \
    sh "$root/catfood" report > "$tmp/report-v2.tsv"
grep -F "miro-a1-fixture	main-a1	MIRO A1	phone	" "$tmp/report-v2.tsv" |
    grep -F "	$android_packages_sha256	$termux_packages_sha256	0	1	1	0	1	1	1" >/dev/null

# Inspection, recording, comparison, and reporting never remove observed state.
test -d "$workspace/packages/old-phone/9999999999999999999999999999999999999999"


# C67 inventory retains physical identity while comparing the shared tablet
# package lane. A non-C67 model must fail before an inventory is recorded.
cp "$workspace/receipts/phone-app-phone.tsv" "$workspace/receipts/c67-app-phone.tsv"
common env CATFOOD_TARGET=c67 CATFOOD_DEVICE_ABI=arm64-v8a \
    CATFOOD_TEST_MODEL='Miro C67' CATFOOD_DEVICE_ID=c67-fixture \
    sh "$root/catfood" inspect > "$tmp/c67.tsv"
grep -Fx 'meta	target	c67	detected' "$tmp/c67.tsv" >/dev/null
grep -Fx 'meta	model	Miro C67	getprop' "$tmp/c67.tsv" >/dev/null
tablet_packages=$tmp/tablet-packages.tsv
sed 's/	armeabi-v7a	/	arm64-v8a	/g' "$packages" > "$tablet_packages"
common env CATFOOD_ANDROID_PACKAGES="$tablet_packages" \
    sh "$root/catfood" compare "$tmp/c67.tsv" > "$tmp/c67-compare.tsv"
grep -Fx 'unconfirmed	app-phone	1111111111111111111111111111111111111111	1111111111111111111111111111111111111111	receipt:NOT_VERIFIED' "$tmp/c67-compare.tsv" >/dev/null
if common env CATFOOD_TARGET=c67 CATFOOD_DEVICE_ABI=arm64-v8a \
    CATFOOD_TEST_MODEL=TAB_P10 sh "$root/catfood" inspect > "$tmp/wrong-c67.tsv" 2> "$tmp/wrong-c67.err"; then
    printf '%s\n' 'non-C67 inventory was accepted as c67' >&2
    exit 1
fi
grep -F 'Android target mismatch' "$tmp/wrong-c67.err" >/dev/null
test ! -s "$tmp/wrong-c67.tsv"

printf '%s\n' 'Cat Food device inventory, Manager record, comparison, and report pass'
