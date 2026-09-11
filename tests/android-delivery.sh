#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

# The checked-in manifests must cover the whole current inventory, while
# readiness remains false until every intended Android runtime has a package.
sh "$root/android/check.sh" check >/dev/null
for target in phone tablet; do
    if sh "$root/android/check.sh" ready "$target" >/dev/null 2>&1; then
        printf 'checked-in %s inventory unexpectedly claimed whole-distribution readiness\n' "$target" >&2
        exit 1
    fi
done

# Inventory additions cannot disappear from Android delivery by omission.
cp "$root/tools.tsv" "$tmp/tools-drift.tsv"
cp "$root/android/delivery.tsv" "$tmp/delivery-drift.tsv"
cp "$root/android/packages.tsv" "$tmp/packages-drift.tsv"
printf '%s\n' 'new-runtime https://github.com/isomorphisms/new-runtime.git main none' >> "$tmp/tools-drift.tsv"
if CATFOOD_TOOLS="$tmp/tools-drift.tsv" \
   CATFOOD_ANDROID_DELIVERY="$tmp/delivery-drift.tsv" \
   CATFOOD_ANDROID_PACKAGES="$tmp/packages-drift.tsv" \
       sh "$root/android/check.sh" check >/dev/null 2>&1; then
    printf '%s\n' 'an unclassified inventory addition escaped Android coverage checking' >&2
    exit 1
fi

source_ref=1111111111111111111111111111111111111111
package_ref=2222222222222222222222222222222222222222
fixture=$tmp/release
bundle=$tmp/bundle
fake_bin=$tmp/bin
backend_log=$tmp/backend.log
app_log=$tmp/app.log
mkdir -p "$fixture" "$bundle/lib" "$fake_bin"
printf '%s\n' 'direct-dex-fixture' > "$bundle/classes.dex"
printf '%s\n' 'jni-fixture' > "$bundle/lib/libapp.so"
cat > "$bundle/catfood-package.tsv" <<EOF_RECEIPT
target	phone
abi	armeabi-v7a
source_ref	$source_ref
package_ref	$package_ref
EOF_RECEIPT
tar -C "$bundle" -czf "$fixture/app-phone.tar.gz" .
digest=$(sha256sum "$fixture/app-phone.tar.gz" | awk '{print $1}')

cat > "$fake_bin/curl" <<'EOF_CURL'
#!/bin/sh
set -eu
output=
url=
while [ "$#" -gt 0 ]; do
    case $1 in
        -o) shift; output=$1 ;;
        http://*|https://*) url=$1 ;;
    esac
    shift
done
[ -n "$output" ] && [ -n "$url" ]
case $url in
    https://example.invalid/app-phone.tar.gz) cp "$CATFOOD_TEST_RELEASE/app-phone.tar.gz" "$output" ;;
    *) printf 'unexpected fixture URL: %s\n' "$url" >&2; exit 22 ;;
esac
EOF_CURL

cat > "$fake_bin/idris-arm-backend" <<'EOF_BACKEND'
#!/bin/sh
printf '%s\n' called >> "$CATFOOD_BACKEND_LOG"
exit 99
EOF_BACKEND

cat > "$fake_bin/app_process" <<'EOF_APP_PROCESS'
#!/bin/sh
printf '%s\n' "$*" >> "$CATFOOD_APP_LOG"
exit 0
EOF_APP_PROCESS
chmod 0755 "$fake_bin/curl" "$fake_bin/idris-arm-backend" "$fake_bin/app_process"

# Establish a known-bad experimental backend, then prove package delivery does
# not invoke or depend on it.
if CATFOOD_BACKEND_LOG="$backend_log" "$fake_bin/idris-arm-backend" >/dev/null 2>&1; then
    printf '%s\n' 'known-bad backend fixture unexpectedly passed' >&2
    exit 1
fi
: > "$backend_log"

fixture_tools=$tmp/tools.tsv
fixture_delivery=$tmp/delivery.tsv
fixture_packages=$tmp/packages.tsv
cat > "$fixture_tools" <<'EOF_TOOLS'
app https://github.com/isomorphisms/app.git main none
idris-arm-backend https://github.com/isomorphisms/idris-arm-backend.git main none
EOF_TOOLS
cat > "$fixture_delivery" <<'EOF_DELIVERY'
# name	role	phone	tablet	note
grease	reference	n/a	n/a	fixture-not-under-test
app	runtime	package:app-phone	gap:not-published	fixture-runtime
idris-arm-backend	host	n/a	n/a	known-bad-experimental-backend
EOF_DELIVERY
cat > "$fixture_packages" <<EOF_PACKAGES
# package	target	abi	mode	source	source_ref	package_ref	url	sha256	command	entrypoint	main_class	jni_library	jni_property	install_requires	runtime_requires	package_requires
app-phone	phone	armeabi-v7a	dex-jni	isomorphisms/app	$source_ref	$package_ref	https://example.invalid/app-phone.tar.gz	$digest	app	classes.dex	org.isomorphisms.app.Main	lib/libapp.so	app.library	curl,sha256sum,tar	-	-
EOF_PACKAGES

CATFOOD_TOOLS="$fixture_tools" \
CATFOOD_ANDROID_DELIVERY="$fixture_delivery" \
CATFOOD_ANDROID_PACKAGES="$fixture_packages" \
    sh "$root/android/check.sh" ready phone >/dev/null

workspace=$tmp/workspace
cache=$tmp/cache
mkdir -p "$workspace" "$cache"
PATH="$fake_bin:$PATH" \
CATFOOD_TEST_RELEASE="$fixture" \
CATFOOD_BACKEND_LOG="$backend_log" \
CATFOOD_APP_LOG="$app_log" \
CATFOOD_APP_PROCESS="$fake_bin/app_process" \
CATFOOD_DEVICE_ABI=armeabi-v7a \
CATFOOD_TARGET=phone \
CATFOOD_ROOT="$workspace" \
CATFOOD_CACHE="$cache" \
CATFOOD_TOOLS="$fixture_tools" \
CATFOOD_ANDROID_DELIVERY="$fixture_delivery" \
CATFOOD_ANDROID_PACKAGES="$fixture_packages" \
    sh "$root/android/install.sh" >/dev/null

test -x "$workspace/bin/app"
test -f "$workspace/packages/app-phone/$package_ref/classes.dex"
test -f "$workspace/packages/app-phone/$package_ref/lib/libapp.so"
test -f "$workspace/receipts/phone-app-phone.tsv"
grep -F '# catfood android dex-jni wrapper' "$workspace/bin/app" >/dev/null
grep -F "source_ref	$source_ref" "$workspace/receipts/phone-app-phone.tsv" >/dev/null
grep -F "package_ref	$package_ref" "$workspace/receipts/phone-app-phone.tsv" >/dev/null
grep -F 'physical_device_execution	PENDING' "$workspace/receipts/phone-app-phone.tsv" >/dev/null
test ! -s "$backend_log"
CATFOOD_APP_LOG="$app_log" "$workspace/bin/app" fixture-argument
[ -s "$app_log" ]

# The normal device provisioner must enter the same runtime-only path. It must
# not install packages, clone sources, bootstrap a compiler, or use a backend.
for forbidden in git make clang cmake javac gradle d8; do
    cat > "$fake_bin/$forbidden" <<'EOF_FORBIDDEN'
#!/bin/sh
printf '%s\n' "$0 $*" >> "$CATFOOD_BACKEND_LOG"
exit 98
EOF_FORBIDDEN
    chmod 0755 "$fake_bin/$forbidden"
done
: > "$backend_log"
provision_workspace=$tmp/provision-workspace
PATH="$fake_bin:$PATH" \
CATFOOD_TEST_RELEASE="$fixture" \
CATFOOD_BACKEND_LOG="$backend_log" \
CATFOOD_APP_LOG="$app_log" \
CATFOOD_APP_PROCESS="$fake_bin/app_process" \
CATFOOD_DEVICE_ABI=armeabi-v7a \
CATFOOD_TARGET=phone \
CATFOOD_ROOT="$provision_workspace" \
CATFOOD_CACHE="$tmp/provision-cache" \
CATFOOD_TOOLS="$fixture_tools" \
CATFOOD_ANDROID_DELIVERY="$fixture_delivery" \
CATFOOD_ANDROID_PACKAGES="$fixture_packages" \
    sh "$root/provision.sh" >/dev/null
test -x "$provision_workspace/bin/app"
test ! -s "$backend_log"
if find "$provision_workspace" -type d -name .git -print -quit | grep . >/dev/null; then
    printf '%s\n' 'Android provisioner created a source checkout' >&2
    exit 1
fi

# A missing deliverable remains an explicit gap and blocks readiness, but the
# installer still refuses to repair it through a source build fallback.
missing_delivery=$tmp/missing-delivery.tsv
empty_packages=$tmp/empty-packages.tsv
cat > "$missing_delivery" <<'EOF_MISSING'
# name	role	phone	tablet	note
grease	reference	n/a	n/a	fixture-not-under-test
app	runtime	gap:not-published	gap:not-published	fixture-runtime
idris-arm-backend	host	n/a	n/a	known-bad-experimental-backend
EOF_MISSING
head -n 1 "$fixture_packages" > "$empty_packages"
if CATFOOD_TOOLS="$fixture_tools" \
   CATFOOD_ANDROID_DELIVERY="$missing_delivery" \
   CATFOOD_ANDROID_PACKAGES="$empty_packages" \
       sh "$root/android/check.sh" ready phone >/dev/null 2>&1; then
    printf '%s\n' 'missing runtime deliverable did not block readiness' >&2
    exit 1
fi
: > "$backend_log"
PATH="$fake_bin:$PATH" \
CATFOOD_BACKEND_LOG="$backend_log" \
CATFOOD_DEVICE_ABI=armeabi-v7a \
CATFOOD_TARGET=phone \
CATFOOD_ROOT="$tmp/missing-workspace" \
CATFOOD_CACHE="$tmp/missing-cache" \
CATFOOD_TOOLS="$fixture_tools" \
CATFOOD_ANDROID_DELIVERY="$missing_delivery" \
CATFOOD_ANDROID_PACKAGES="$empty_packages" \
    sh "$root/android/install.sh" > "$tmp/missing.out"
grep -F 'Whole-inventory readiness remains PENDING' "$tmp/missing.out" >/dev/null
grep -F 'No source build fallback was attempted' "$tmp/missing.out" >/dev/null
test ! -s "$backend_log"

# An invalid digest is a package failure, not a reason to build locally.
bad_packages=$tmp/bad-packages.tsv
sed "s/$digest/0000000000000000000000000000000000000000000000000000000000000000/" \
    "$fixture_packages" > "$bad_packages"
if PATH="$fake_bin:$PATH" \
   CATFOOD_TEST_RELEASE="$fixture" \
   CATFOOD_APP_PROCESS="$fake_bin/app_process" \
   CATFOOD_DEVICE_ABI=armeabi-v7a \
   CATFOOD_TARGET=phone \
   CATFOOD_ROOT="$tmp/bad-workspace" \
   CATFOOD_CACHE="$tmp/bad-cache" \
   CATFOOD_TOOLS="$fixture_tools" \
   CATFOOD_ANDROID_DELIVERY="$fixture_delivery" \
   CATFOOD_ANDROID_PACKAGES="$bad_packages" \
       sh "$root/android/install.sh" >/dev/null 2>&1; then
    printf '%s\n' 'bad package digest unexpectedly installed' >&2
    exit 1
fi

printf '%s\n' 'whole-inventory Android delivery architecture passes its fixtures'
