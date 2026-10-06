#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

apk=$tmp/app.apk
receipt=$tmp/producer.tsv
printf 'fixture APK bytes\n' > "$apk"
sha=$(sha256sum "$apk" | awk '{print $1}')
policy=1111111111111111111111111111111111111111
packager=2222222222222222222222222222222222222222
signer=3333333333333333333333333333333333333333333333333333333333333333

write_receipt() {
    update=$1
    digest=$2
    cat > "$receipt" <<EOF
schema	aici-android-producer-v1
result	PASS
policy_commit	$policy
packager_commit	$packager
package	org.isomorphisms.fixture
version_code	2
abi	armeabi-v7a
signing_lane	test
signer_cert_sha256	$signer
apk_sha256	$digest
prior_apk_sha256	-
update_identity_result	$update
EOF
}

write_receipt NOT_VERIFIED "$sha"
sh "$root/android/check-producer.sh" "$receipt" "$apk" >/dev/null
if sh "$root/android/check-producer.sh" --require-update "$receipt" "$apk" >"$tmp/not-verified.out" 2>&1; then
    echo "NOT_VERIFIED update continuity unexpectedly passed --require-update" >&2
    exit 1
fi
grep -Fq 'update continuity is not verified: NOT_VERIFIED' "$tmp/not-verified.out"

write_receipt PASS "$sha"
sh "$root/android/check-producer.sh" --require-update "$receipt" "$apk" >/dev/null

write_receipt PASS 0000000000000000000000000000000000000000000000000000000000000000
if sh "$root/android/check-producer.sh" "$receipt" "$apk" >"$tmp/bad-digest.out" 2>&1; then
    echo "wrong APK digest unexpectedly passed" >&2
    exit 1
fi
grep -Fq 'APK digest does not match AICI producer receipt' "$tmp/bad-digest.out"

write_receipt PASS "$sha"
printf 'result	PASS\n' >> "$receipt"
if sh "$root/android/check-producer.sh" "$receipt" "$apk" >"$tmp/duplicate.out" 2>&1; then
    echo "duplicate producer receipt field unexpectedly passed" >&2
    exit 1
fi
grep -Fq 'must contain exactly one result field' "$tmp/duplicate.out"

printf 'Cat Food AICI Android producer receipt tests: PASS\n'
