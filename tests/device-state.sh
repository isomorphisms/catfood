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
if [ "${CATFOOD_TEST_PACKAGE_FAILURE:-0}" = 1 ]; then
    printf '%s\n' package:com.example.partial
    exit 1
fi
[ "$1 $2 $3" = 'list packages -3' ] || exit 2
printf '%s\n' package:com.example.reader package:com.example.maps
EOF
cat > "$fake_bin/dpkg-query" <<'EOF'
#!/bin/sh
[ "${CATFOOD_TEST_PACKAGE_FAILURE:-0}" != 1 ] || exit 1
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

# Tablet hardware/storage reconciliation stays observational. No phone path,
# successful package command, or empty Android service response can stand in
# for current tablet mount or runtime evidence.
mkdir -p "$home/storage" "$tmp/shared downloads" "$tmp/card root"
ln -s "$tmp/shared downloads" "$home/storage/downloads"
ln -s "$tmp/missing-card" "$home/storage/external-1"
printf '%s\n' retain-this-data > "$tmp/card root/keep.txt"
mounts=$tmp/mounts
escaped_downloads=$(printf '%s' "$tmp/shared downloads" | sed 's/ /\\040/g')
escaped_card=$(printf '%s' "$tmp/card root" | sed 's/ /\\040/g')
{
    printf 'rootfs / rootfs rw 0 0\n'
    printf '/dev/fuse %s fuse rw,noexec,nosuid 0 0\n' "$escaped_downloads"
} > "$mounts"
cat > "$fake_bin/dumpsys" <<'EOF'
#!/bin/sh
printf '%s\n' 'Permission Denial: shell authority required'
EOF
cat > "$fake_bin/sm" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$fake_bin/wm" <<'EOF'
#!/bin/sh
printf '%s\n' 'Physical size: 1280x800'
EOF
chmod 0755 "$fake_bin/dumpsys" "$fake_bin/sm" "$fake_bin/wm"
for forbidden in adb pkg cc clang gcc make cmake gradle javac; do
    cat > "$fake_bin/$forbidden" <<'EOF'
#!/bin/sh
printf '%s\n' "$0" >> "$CATFOOD_TEST_FORBIDDEN"
exit 99
EOF
    chmod 0755 "$fake_bin/$forbidden"
done
tablet_inspect() {
    common env CATFOOD_TARGET=tablet CATFOOD_DEVICE_ABI=arm64-v8a \
        CATFOOD_TEST_MODEL=TAB_P10 CATFOOD_DEVICE_ID=tablet-fixture \
        CATFOOD_INSPECT_MOUNTS="$mounts" CATFOOD_TEST_FORBIDDEN="$tmp/forbidden" \
        "$@" sh "$root/catfood" inspect
}
tablet_inspect > "$tmp/tablet.tsv"
grep -Fx "storage_resolved	downloads	$tmp/shared downloads	readlink-f" "$tmp/tablet.tsv" >/dev/null
grep -Fx 'storage_execution	downloads	BLOCKED	mount-noexec' "$tmp/tablet.tsv" >/dev/null
grep -Fx 'storage_status	external_1	NOT_VERIFIED	dangling-or-inaccessible-link' "$tmp/tablet.tsv" >/dev/null
grep -Fx 'storage	public_volume_mounts	NOT_OBSERVED	supplied-mount-table:visible-namespace-only' "$tmp/tablet.tsv" >/dev/null
grep -Fx 'storage	sd_card_presence	UNKNOWN	no-physical-media-inference' "$tmp/tablet.tsv" >/dev/null
grep -Fx 'probe_status	sensors	DENIED	exit:0' "$tmp/tablet.tsv" >/dev/null
grep -Fx 'probe_status	volumes	EMPTY	exit:0' "$tmp/tablet.tsv" >/dev/null
grep -Fx 'acceptance	physical_runtime	NOT_VERIFIED	observation-is-not-runtime-acceptance' "$tmp/tablet.tsv" >/dev/null
test ! -e "$tmp/forbidden"

# A real mount-table row is required; a directory/symlink cannot invent one.
rm "$home/storage/external-1"
ln -s "$tmp/card root" "$home/storage/external-1"
tablet_inspect > "$tmp/unmounted-directory.tsv"
grep -Fx 'storage	public_volume_mounts	NOT_OBSERVED	supplied-mount-table:visible-namespace-only' "$tmp/unmounted-directory.tsv" >/dev/null
printf '/dev/fuse /storage/ABCD-0123 fuse rw,noexec 0 0\n' >> "$mounts"
printf '/dev/fuse %s fuse rw,noexec 0 0\n' "$escaped_card" >> "$mounts"
tablet_inspect > "$tmp/mounted.tsv"
grep -Fx 'storage	public_volume_mounts	OBSERVED	supplied-mount-table:count=1' "$tmp/mounted.tsv" >/dev/null
grep -Fx 'storage_execution	external_1	BLOCKED	mount-noexec' "$tmp/mounted.tsv" >/dev/null
grep -Fx 'storage	sd_card_presence	UNKNOWN	no-physical-media-inference' "$tmp/mounted.tsv" >/dev/null
test "$(cat "$tmp/card root/keep.txt")" = retain-this-data

# Partial stdout from a failed package query must not be hashed as a complete
# package inventory. Successful empty service output also remains distinct.
tablet_inspect CATFOOD_TEST_PACKAGE_FAILURE=1 > "$tmp/query-failed.tsv"
grep -Fx 'meta	android_packages_sha256	-	pm-failed' "$tmp/query-failed.tsv" >/dev/null
grep -Fx 'meta	termux_packages_sha256	-	dpkg-query-failed' "$tmp/query-failed.tsv" >/dev/null
if grep -E '^(android_package|termux_package)	' "$tmp/query-failed.tsv"; then
    printf '%s\n' 'failed package query became observed package rows' >&2
    exit 1
fi

cat > "$fake_bin/timeout" <<'EOF'
#!/bin/sh
exit 124
EOF
chmod 0755 "$fake_bin/timeout"
tablet_inspect > "$tmp/timed-out.tsv"
grep -Fx 'probe_status	sensors	TIMED_OUT	exit:124' "$tmp/timed-out.tsv" >/dev/null
rm "$fake_bin/dumpsys"
tablet_inspect > "$tmp/missing-command.tsv"
grep -Fx 'probe_status	sensors	NOT_VERIFIED	command-unavailable' "$tmp/missing-command.tsv" >/dev/null

# Preserve every completed inspection even when observations share a clock
# second. Refuse a host with only a planning target before writing any state.
history_before=$(find "$state/catfood/device/inspections" -type f | wc -l)
tablet_inspect > /dev/null
tablet_inspect > /dev/null
history_after=$(find "$state/catfood/device/inspections" -type f | wc -l)
test "$history_after" -eq "$((history_before + 2))"
cat > "$fake_bin/no-getprop" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 0755 "$fake_bin/no-getprop"
if common env CATFOOD_GETPROP="$fake_bin/no-getprop" CATFOOD_TARGET=tablet \
    CATFOOD_DEVICE_STATE="$tmp/host-state" sh "$root/catfood" inspect > "$tmp/host.tsv" 2> "$tmp/host.err"; then
    printf '%s\n' 'host planning override was accepted as physical inventory' >&2
    exit 1
fi
test ! -e "$tmp/host-state"
test ! -s "$tmp/host.tsv"
test ! -e "$tmp/forbidden"
printf '%s\n' 'Cat Food device inventory, hardware/storage observations, Manager record, comparison, and report pass'
