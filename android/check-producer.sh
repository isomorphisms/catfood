#!/bin/sh
set -eu

usage() {
    printf 'usage: %s [--require-update] PRODUCER_RECEIPT APK\n' "$0" >&2
    exit 2
}

require_update=0
if [ "${1:-}" = "--require-update" ]; then
    require_update=1
    shift
fi
[ "$#" -eq 2 ] || usage
receipt=$1
apk=$2

[ -f "$receipt" ] || { printf 'missing AICI producer receipt: %s\n' "$receipt" >&2; exit 1; }
[ -f "$apk" ] || { printf 'missing APK: %s\n' "$apk" >&2; exit 1; }

value() {
    key=$1
    awk -F '\t' -v key="$key" '
        $1 == key { count++; value=$2 }
        END {
            if (count != 1) exit 2
            print value
        }
    ' "$receipt" || {
        printf '%s must contain exactly one %s field\n' "$receipt" "$key" >&2
        exit 1
    }
}

schema=$(value schema)
result=$(value result)
policy_commit=$(value policy_commit)
packager_commit=$(value packager_commit)
package=$(value package)
version_code=$(value version_code)
abi=$(value abi)
signer=$(value signer_cert_sha256)
declared_sha=$(value apk_sha256)
update_result=$(value update_identity_result)

[ "$schema" = "aici-android-producer-v1" ] || {
    printf 'unsupported AICI producer receipt schema: %s\n' "$schema" >&2
    exit 1
}
[ "$result" = PASS ] || {
    printf 'AICI producer result is not PASS: %s\n' "$result" >&2
    exit 1
}
case $policy_commit in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*)
        [ "${#policy_commit}" -eq 40 ] || { echo "invalid AICI policy commit" >&2; exit 1; }
        ;;
    *) echo "invalid AICI policy commit" >&2; exit 1 ;;
esac
case $packager_commit in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*)
        [ "${#packager_commit}" -eq 40 ] || { echo "invalid android-NDK packager commit" >&2; exit 1; }
        ;;
    *) echo "invalid android-NDK packager commit" >&2; exit 1 ;;
esac
[ -n "$package" ] || { echo "producer package is empty" >&2; exit 1; }
[ -n "$abi" ] || { echo "producer ABI is empty" >&2; exit 1; }
case $version_code in *[!0-9]*|'') echo "invalid producer versionCode: $version_code" >&2; exit 1 ;; esac
case $signer in
    [0-9a-f]*) [ "${#signer}" -eq 64 ] || { echo "invalid signer digest" >&2; exit 1; } ;;
    *) echo "invalid signer digest" >&2; exit 1 ;;
esac
case $declared_sha in
    [0-9a-f]*) [ "${#declared_sha}" -eq 64 ] || { echo "invalid APK digest" >&2; exit 1; } ;;
    *) echo "invalid APK digest" >&2; exit 1 ;;
esac

actual_sha=$(sha256sum "$apk" | awk '{print $1}')
[ "$actual_sha" = "$declared_sha" ] || {
    printf 'APK digest does not match AICI producer receipt: %s != %s\n' "$actual_sha" "$declared_sha" >&2
    exit 1
}

case $update_result in
    PASS|NOT_VERIFIED) ;;
    *) printf 'invalid update_identity_result: %s\n' "$update_result" >&2; exit 1 ;;
esac
if [ "$require_update" -eq 1 ] && [ "$update_result" != PASS ]; then
    printf 'update continuity is not verified: %s\n' "$update_result" >&2
    exit 1
fi

printf 'CATFOOD_ANDROID_PRODUCER\tPASS\n'
printf 'PACKAGE\t%s\n' "$package"
printf 'VERSION_CODE\t%s\n' "$version_code"
printf 'ABI\t%s\n' "$abi"
printf 'APK_SHA256\t%s\n' "$actual_sha"
printf 'SIGNER_SHA256\t%s\n' "$signer"
printf 'UPDATE_IDENTITY\t%s\n' "$update_result"
