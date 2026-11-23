#!/bin/sh
# Host fixtures for android/acceptance/icu-c67.sh. No physical acceptance claims.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
script="$root/android/acceptance/icu-c67.sh"
sh -n "$script"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/repo/android/acceptance" "$tmp/home" "$tmp/workspace"
cp "$script" "$tmp/repo/android/acceptance/icu-c67.sh"

cat > "$tmp/repo/android/target.sh" <<'EOF_TARGET'
catfood_android_require_device() {
    [ "${FAKE_DEVICE:-c67}" = "$1" ] || { printf 'wrong device\n' >&2; exit 2; }
}
catfood_android_getprop() {
    case "$1" in
        ro.product.model) echo 'Miro C67' ;;
        ro.product.device) echo Miro_C67 ;;
        ro.product.cpu.abi) echo arm64-v8a ;;
        ro.build.version.sdk) echo 34 ;;
        *) echo '-' ;;
    esac
}
catfood_android_device_id() { echo simulated; }
EOF_TARGET
cat > "$tmp/repo/android/check.sh" <<'EOF_CHECK'
#!/bin/sh
exit "${FAKE_CHECK_RESULT:-0}"
EOF_CHECK
printf 'icu\truntime\tgap:android-package-missing\tgap:android-package-missing\tstable-runtime-command\n' > "$tmp/repo/android/delivery.tsv"
printf '# no packages\n' > "$tmp/repo/android/packages.tsv"

expect_exit() {
    expected=$1
    shift
    code=0
    "$@" > "$tmp/output" 2>&1 || code=$?
    [ "$code" -eq "$expected" ] || {
        cat "$tmp/output" >&2
        printf 'expected exit %s; found %s\n' "$expected" "$code" >&2
        exit 1
    }
}

expect_exit 3 env CATFOOD_ROOT="$tmp/workspace" HOME="$tmp/home" sh "$tmp/repo/android/acceptance/icu-c67.sh"
grep -Fq 'BLOCKED icu_publication:' "$tmp/output"
find "$tmp/workspace/receipts" -name summary.tsv -exec grep -F 'icu_publication' {} \; | grep -Fq BLOCKED
[ ! -e "$tmp/workspace/bin/icu" ]
printf 'PASS no verified artifact => BLOCKED, without fabricated command\n'

expect_exit 2 env FAKE_DEVICE=tablet CATFOOD_ROOT="$tmp/workspace" HOME="$tmp/home" sh "$tmp/repo/android/acceptance/icu-c67.sh"
printf 'PASS wrong device refused\n'

expect_exit 4 env FAKE_CHECK_RESULT=1 CATFOOD_ROOT="$tmp/workspace" HOME="$tmp/home" sh "$tmp/repo/android/acceptance/icu-c67.sh"
printf 'PASS invalid manifest refused\n'

printf 'icu\truntime\tgap:android-package-missing\tpackage:icu-c67\tstable-runtime-command\n' > "$tmp/repo/android/delivery.tsv"
expect_exit 3 env CATFOOD_ROOT="$tmp/workspace" HOME="$tmp/home" sh "$tmp/repo/android/acceptance/icu-c67.sh"
grep -Fq 'missing ARM64 dex-jni' "$tmp/output"
printf 'PASS declared ICU without arm64 DEX/JNI row refused\n'
