#!/bin/sh
# Verify the installed Cat Food AZ CLI on the physical MIRO C67.
# It does not provision packages, contact Amazon or test the ChatGPT bridge.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
workspace=${CATFOOD_ROOT:-"$HOME/opt"}
tab=$(printf '\t')
fail() { printf 'FAIL Cat Food C67 AZ: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS Cat Food C67 AZ: %s\n' "$*"; }

command -v getprop >/dev/null 2>&1 || fail 'Android getprop is unavailable'
model=$(getprop ro.product.model)
device=$(getprop ro.product.device)
abi=$(getprop ro.product.cpu.abi)
[ "$device" = Miro_C67 ] && [ "$model" = 'Miro C67' ] &&
    [ "$abi" = arm64-v8a ] || fail "wrong physical device: model=$model device=$device abi=$abi"
pass "physical device identity $model ($abi)"

row=$(awk -F '\t' '$1 == "az-tablet" { print; found++ } END { if (found != 1) exit 1 }' \
    "$root/android/packages.tsv") || fail 'exactly one az-tablet package row required'
IFS="$tab" read -r package lane package_abi mode origin source_ref package_ref url digest \
    command entrypoint main_class jni_library jni_property install_requires \
    termux_packages runtime_requires package_requires <<EOF_ROW
$row
EOF_ROW
[ "$lane" = arm64-v8a ] && [ "$package_abi" = arm64-v8a ] &&
    [ "$mode" = file ] && [ "$origin" = Ashtray-Archer/az ] &&
    [ "$source_ref" = "$package_ref" ] &&
    [ "$command" = az ] && [ "$entrypoint" = bin/az ] ||
    fail 'AZ package lane, source, mode or command is inconsistent'
[ "$url" = "https://raw.githubusercontent.com/Ashtray-Archer/az/$source_ref/bin/az" ] ||
    fail 'AZ URL does not name the pinned canonical source'

expected="$workspace/packages/$package/$package_ref/$entrypoint"
stable="$workspace/bin/az"
[ -f "$expected" ] && [ -x "$expected" ] && [ -e "$stable" ] ||
    fail 'AZ is not installed at the expected Cat Food package and stable command paths'
command -v readlink >/dev/null 2>&1 || fail 'readlink is unavailable'
actual_path=$(readlink -f "$stable") || fail 'cannot resolve stable AZ command'
expected_path=$(readlink -f "$expected") || fail 'cannot resolve declared AZ package'
[ "$actual_path" = "$expected_path" ] || fail 'stable az does not resolve to the pinned package'
if command -v sha256sum >/dev/null 2>&1; then
    actual_digest=$(sha256sum "$expected" | awk '{print $1}')
elif [ -x /system/bin/toybox ]; then
    actual_digest=$(/system/bin/toybox sha256sum "$expected" | awk '{print $1}')
else
    fail 'no SHA-256 implementation available'
fi
[ "$actual_digest" = "$digest" ] || fail 'installed AZ source bytes differ from packages.tsv'
receipt="$workspace/receipts/c67-az-tablet.tsv"
[ -f "$receipt" ] || fail 'C67 installation receipt is absent'
sh "$root/android/check.sh" receipt "$receipt" c67 >/dev/null ||
    fail 'Cat Food rejected the C67 installation receipt'
grep -Fx "installation_result${tab}PASS" "$receipt" >/dev/null ||
    fail 'installer did not record a successful C67 installation'
pass "immutable AZ package $source_ref sha256=$digest"

tmp=$(mktemp -d "${TMPDIR:-${HOME}/.cache}/catfood-az-c67.XXXXXX") ||
    fail 'cannot create private fixture directory'
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
cat > "$tmp/curl" <<'EOF_CURL'
#!/bin/sh
for arg in "$@"; do
    case $arg in
        'https://www.amazon.com/s?k=catfood%20contract')
            cat "$CATFOOD_AZ_PAGE"
            exit 0
            ;;
    esac
done
printf 'unexpected offline curl request: %s\n' "$*" >&2
exit 22
EOF_CURL
chmod 0700 "$tmp/curl"
cat > "$tmp/page.html" <<'EOF_PAGE'
<html><body><div data-component-type="s-search-result" data-asin="B000CCFXYY"></div></body></html>
EOF_PAGE
export CATFOOD_AZ_PAGE="$tmp/page.html"
export AZ_SEARCH_STATUS_FILE="$tmp/status.tsv"
export AZ_SECRET_FILE="$tmp/no-secret"
export AZ_CONFIG_DIR="$tmp"
export AZ_PARTNER_TAG=macguyver03-20
export PATH="$tmp:$workspace/bin:$PATH"
link=$("$stable" link B000CCFXYY) || fail 'native AZ link invocation failed'
[ "$link" = 'https://www.amazon.com/dp/B000CCFXYY?tag=macguyver03-20' ] ||
    fail 'native AZ generated an incorrect affiliate link'
pass 'native AZ affiliate link'
"$stable" search 'catfood contract' > "$tmp/search.tsv" ||
    fail 'native AZ search fixture failed'
grep -Fx "$(printf 'status\tEXTRACTED_UNVERIFIED')" "$AZ_SEARCH_STATUS_FILE" >/dev/null ||
    fail 'search did not mark extracted ASIN candidates unverified'
grep -F 'B000CCFXYY' "$tmp/search.tsv" >/dev/null ||
    fail 'search omitted the fixture candidate'
pass 'native AZ search TSV and unverified status'
cat > "$tmp/page.html" <<'EOF_CHALLENGE'
<html><title>Robot Check</title><body>Enter the characters you see below</body></html>
EOF_CHALLENGE
if "$stable" search 'catfood contract' > "$tmp/challenge.stdout" 2> "$tmp/challenge.stderr"; then
    fail 'AZ accepted a robot challenge as search results'
else
    code=$?
fi
[ "$code" -eq 5 ] || fail "AZ challenge exit status $code, expected 5"
grep -Fx "$(printf 'status\tCHALLENGE')" "$AZ_SEARCH_STATUS_FILE" >/dev/null ||
    fail 'AZ did not record challenge refusal'
pass 'native AZ refuses a challenged search'

# Separate runtime-smoke observation: do not fabricate or rewrite the installer
# receipt's build, publication, emulator or physical-device fields.
observation="$workspace/receipts/c67-az-command-smoke.tsv"
umask 077
temp_observation="$observation.tmp.$$"
trap 'rm -rf "$tmp" "$temp_observation"' EXIT HUP INT TERM
{
    printf 'schema\tcatfood-az-command-smoke-v1\n'
    printf 'target\tc67\n'
    printf 'model\t%s\n' "$model"
    printf 'abi\t%s\n' "$abi"
    printf 'package\t%s\nsource_ref\t%s\nsha256\t%s\n' "$package" "$source_ref" "$digest"
    printf 'installed_receipt\t%s\n' "$receipt"
    printf 'native_link\tPASS\nnative_search_fixture\tPASS\nchallenge_refusal\tPASS\n'
    printf 'live_amazon\tNOT_RUN\nchatgpt_bridge\tNOT_VERIFIED\n'
    printf 'recorded_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$temp_observation"
mv "$temp_observation" "$observation"
pass "physical C67 command smoke recorded: $observation"
