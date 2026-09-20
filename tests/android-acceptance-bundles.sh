#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

sh -n "$root/android/acceptance/run.sh"
sh -n "$root/android/acceptance/build-bundles.sh"

grep -Fq 'run_case catfood_legacy_migration' "$root/android/acceptance/run.sh"
grep -Fq 'run_case grease_readable_syntax' "$root/android/acceptance/run.sh"
grep -Fq 'run_case cloud_storage_help' "$root/android/acceptance/run.sh"
grep -Fq 'run_case ike_runtime' "$root/android/acceptance/run.sh"
grep -Fq 'run_case reddit_direct_dex_jni' "$root/android/acceptance/run.sh"
grep -Fq 'run_case powervr_vendor_driver' "$root/android/acceptance/run.sh"
grep -Fq 'GREASE_IB=1' "$root/android/acceptance/build-bundles.sh"
grep -Fq 'POWERVR_ENABLED=0' "$root/android/acceptance/build-bundles.sh"
grep -Fq 'POWERVR_ENABLED=1' "$root/android/acceptance/build-bundles.sh"

grep -Fq '5ff32e2208440ccfe02ee38c17e6626719bcaf87' "$root/android/acceptance/build-bundles.sh"
grep -Fq '9b3dc89048911bd0e23ee992fe00dcb3cd427f63' "$root/android/acceptance/build-bundles.sh"
grep -Fq '513d3515083edaf723a60292d8d333b7171469cb' "$root/android/acceptance/build-bundles.sh"
grep -Fq 'a92fe68bf8aad8dfcfe9f7a7abd84e07290f7fe0' "$root/android/acceptance/build-bundles.sh"

ike_ref=$(awk -F= '$1 == "IKE_REF" { print $2; exit }' "$root/android/acceptance/build-bundles.sh")
ike_phone_sha=$(awk -F= '$1 == "IKE_PHONE_SHA" { print $2; exit }' "$root/android/acceptance/build-bundles.sh")
ike_tablet_sha=$(awk -F= '$1 == "IKE_TABLET_SHA" { print $2; exit }' "$root/android/acceptance/build-bundles.sh")
[ -n "$ike_ref" ] && [ -n "$ike_phone_sha" ] && [ -n "$ike_tablet_sha" ]

package_ike_phone=$(awk -F '\t' '$1 == "ike-phone" { print $6 "\t" $7 "\t" $9 }' "$root/android/packages.tsv")
package_ike_tablet=$(awk -F '\t' '$1 == "ike-tablet" { print $6 "\t" $7 "\t" $9 }' "$root/android/packages.tsv")
expected_ike_phone=$(printf '%s\t%s\t%s' "$ike_ref" "$ike_ref" "$ike_phone_sha")
expected_ike_tablet=$(printf '%s\t%s\t%s' "$ike_ref" "$ike_ref" "$ike_tablet_sha")
[ "$package_ike_phone" = "$expected_ike_phone" ]
[ "$package_ike_tablet" = "$expected_ike_tablet" ]
grep -Fq '4be1d5a3d603154262f247581dcd76f6a4b317cd' "$root/android/acceptance/build-bundles.sh"
grep -Fq '7a2c75f1564dfe82fddee4e975367faf5a3720e4' "$root/android/acceptance/build-bundles.sh"

printf '%s\n' 'android acceptance bundle contract: PASS'
