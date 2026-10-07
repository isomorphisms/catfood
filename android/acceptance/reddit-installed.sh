#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
target=${CATFOOD_TARGET:-}
. "$root/android/target.sh"
catfood_android_require_device "$target"
device_id=$(catfood_android_device_id)
workspace=${CATFOOD_ROOT:-"$HOME/opt"}

case "$target" in
    phone)
        expected_abi=armeabi-v7a
        package=reddit-phone
        ;;
    c67|tablet)
        expected_abi=arm64-v8a
        package=reddit-tablet
        ;;
    *)
        printf 'usage: CATFOOD_TARGET=phone|c67|tablet %s\n' "$0" >&2
        exit 2
        ;;
esac

if [ -t 1 ]; then
    cyan='\033[36m'
    yellow='\033[33m'
    green='\033[32m'
    red='\033[31m'
    reset='\033[0m'
else
    cyan=
    yellow=
    green=
    red=
    reset=
fi

section() {
    printf '\n%b== %s ==%b\n' "$cyan" "$1" "$reset"
}

action() {
    printf '%b%s%b\n' "$yellow" "$1" "$reset"
}

pass() {
    printf '%bPASS%b %s\n' "$green" "$reset" "$1"
}

fail() {
    printf '%bFAIL%b %s\n' "$red" "$reset" "$1" >&2
    exit 1
}

getprop_command=${CATFOOD_GETPROP:-/system/bin/getprop}
[ -x "$getprop_command" ] || fail "Android getprop is unavailable: $getprop_command"

reddit="$workspace/bin/reddit"
install_receipt="$workspace/receipts/$target-$package.tsv"
[ -x "$reddit" ] || fail "installed Reddit command is missing: $reddit"
[ -f "$install_receipt" ] || fail "installation receipt is missing: $install_receipt"

sh "$root/android/check.sh" authorize "$install_receipt" "$target" "$device_id" installation >/dev/null ||
    fail "installation receipt does not match the current Cat Food package manifest"

stamp=$(date -u '+%Y%m%dT%H%M%SZ' 2>/dev/null || printf unknown)
evidence_dir=${CATFOOD_REDDIT_EVIDENCE:-"$workspace/receipts/reddit-$target-$stamp"}
mkdir "$evidence_dir" || fail 'evidence attempt already exists; refusing replacement'

device_log="$evidence_dir/device.tsv"
url_log="$evidence_dir/reddit-url.log"
runtime_log="$evidence_dir/reddit-runtime.log"
physical_receipt="$evidence_dir/$target-reddit-physical.tsv"

section "Device identity"
abi=$("$getprop_command" ro.product.cpu.abi 2>/dev/null | tr -d '\r')
sdk=$("$getprop_command" ro.build.version.sdk 2>/dev/null | tr -d '\r')
model=$("$getprop_command" ro.product.model 2>/dev/null | tr -d '\r')
fingerprint=$("$getprop_command" ro.build.fingerprint 2>/dev/null | tr -d '\r')
{
    printf 'target\t%s\n' "$target"
    printf 'expected_abi\t%s\n' "$expected_abi"
    printf 'device_abi\t%s\n' "$abi"
    printf 'sdk\t%s\n' "$sdk"
    printf 'model\t%s\n' "$model"
    printf 'fingerprint\t%s\n' "$fingerprint"
} > "$device_log"
cat "$device_log"
[ "$abi" = "$expected_abi" ] || fail "device ABI $abi does not match $expected_abi"
pass "observed target identity matches $target"

section "Reddit DEX/JNI launch"
action "Run the installed stable reddit command through app_process"
if ! "$reddit" url 'computer science degree regret' >"$url_log" 2>&1; then
    cat "$url_log"
    fail "reddit url command did not launch successfully"
fi
cat "$url_log"
grep -Fq 'q=computer%20science%20degree%20regret' "$url_log" ||
    fail "reddit url output did not contain the expected encoded query"
pass "installed Reddit DEX/JNI command launched and returned the expected URL"

section "Reddit runtime boundary"
action "Verify the native search boundary rejects a missing access token"
if REDDIT_ACCESS_TOKEN='' "$reddit" search 'computer science degree regret' >"$runtime_log" 2>&1; then
    cat "$runtime_log"
    fail "reddit search unexpectedly succeeded without REDDIT_ACCESS_TOKEN"
fi
cat "$runtime_log"
grep -Fq 'reddit: missing REDDIT_ACCESS_TOKEN' "$runtime_log" ||
    fail "missing-token diagnostic did not come from the Reddit runtime"
pass "installed command returned the expected runtime-boundary diagnostic"

# Revalidate after execution: a launcher, DEX, JNI library, dependency or device
# fact changed during the run must not publish a successful observation.
sh "$root/android/check.sh" authorize "$install_receipt" "$target" "$device_id" installation >/dev/null ||
    fail 'installed bytes or device facts changed during execution'
. "$root/android/content.sh"
scope=$(cf_field "$install_receipt" evidence_scope)
{
    printf 'schema\tcatfood-execution-observation-v1\n'
    printf 'scope\t%s\n' "$scope"
    printf 'kind\tfresh-reddit-procedure\n'
    printf 'procedure_sha256\t%s\n' "$(cf_hash "$0")"
    printf 'installation_receipt_sha256\t%s\n' "$(cf_hash "$install_receipt")"
    printf 'launch_log_sha256\t%s\n' "$(cf_hash "$url_log")"
    printf 'runtime_log_sha256\t%s\n' "$(cf_hash "$runtime_log")"
    printf 'device_log_sha256\t%s\n' "$(cf_hash "$device_log")"
    printf 'launch_observation\tPASS\nruntime_observation\tPASS\nacceptance_authorization\tNOT_VERIFIED\n'
} > "$evidence_dir/execution.tsv"

# Local unsigned logs cannot authenticate their own execution. Retain the
# installation receipt unchanged and keep this fresh observation separate.
cp "$install_receipt" "$physical_receipt"

sh "$root/android/check.sh" receipt "$physical_receipt" "$target" "$device_id" >/dev/null ||
    fail "retained installation receipt failed Cat Food validation"

section "Receipt"
cat "$physical_receipt"
pass "fresh Reddit observation ($scope): $evidence_dir/execution.tsv; acceptance NOT_VERIFIED"
