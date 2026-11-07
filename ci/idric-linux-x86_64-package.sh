#!/bin/sh
# Produce a source-pinned, host-ABI-specific compiler archive; does not publish it.
set -eu

usage() {
    echo 'usage: sh ci/idric-linux-x86_64-package.sh IDRIC_CHECKOUT OUTPUT_DIRECTORY' >&2
    exit 2
}
[ "$#" -eq 2 ] || usage
source=$1
output=$2

expected=94dfd99bd3e376507fedc8611053b7173b2519f0
[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || {
    echo 'Idriç bundle: only Linux x86_64 is supported' >&2; exit 1;
}
[ "$(git -C "$source" rev-parse HEAD)" = "$expected" ] || {
    echo 'Idriç bundle: incorrect compiler revision' >&2; exit 1;
}

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
name="idric-linux-x86_64-${expected}"
mkdir -p "$output"
output=$(CDPATH= cd -- "$output" && pwd -P)
bundle="$output/$name"
[ ! -e "$bundle" ] || { echo 'Idriç bundle: destination already exists' >&2; exit 1; }

private="$source/_"
require_executable() {
    [ -x "$1" ] || { printf 'Idriç bundle: missing executable: %s\n' "$1" >&2; exit 1; }
}
require_file() {
    [ -f "$1" ] || { printf 'Idriç bundle: missing file: %s\n' "$1" >&2; exit 1; }
}
require_dir() {
    [ -d "$1" ] || { printf 'Idriç bundle: missing directory: %s\n' "$1" >&2; exit 1; }
}
require_executable "$private/build/exec/idris2"
if [ ! -f "$private/build/exec/idris2_app/idris2.so" ] && [ ! -f "$private/build/exec/idris2_app/idris2.ss" ]; then
    printf 'Idriç bundle: final compiler program missing; generated app directory:\n' >&2
    ls -la "$private/build/exec/idris2_app" >&2 || :
    exit 1
fi
require_file "$private/support/c/libidris2_support.so"
if [ ! -x "$private/.tools/chez-10.4.1/bin/scheme" ]; then
    printf 'Idriç bundle: Chez executable missing at pinned prefix; installer layout:\n' >&2
    find "$private/.tools" -maxdepth 5 -name scheme -print >&2 || :
    exit 1
fi

mkdir -p "$bundle/bin" "$bundle/compiler/build" "$bundle/compiler/libs" "$bundle/receipts"
cp -a "$private/.tools/chez-10.4.1" "$bundle/chez-10.4.1"
cp -a "$private/build/exec" "$bundle/compiler/build/exec"
cp -a "$private/support" "$bundle/compiler/support"
for library in prelude base linear network contrib test; do
    require_dir "$private/libs/$library/build/ttc"
    mkdir -p "$bundle/compiler/libs/$library/build"
    cp -a "$private/libs/$library/build/ttc" "$bundle/compiler/libs/$library/build/ttc"
done
cp "$root/ci/idric-linux-x86_64-env.sh" "$bundle/bin/idric"
chmod 0755 "$bundle/bin/idric"
ln -s idric "$bundle/bin/idris2"
ln -s idric "$bundle/bin/idric-env"
ln -s ../chez-10.4.1/bin/scheme "$bundle/bin/scheme"

# ABI and shared-library claims must be checked on the actual producer.
for target in chez idric-support; do
    case "$target" in
        chez) path="$bundle/chez-10.4.1/bin/scheme" ;;
        *) path="$bundle/compiler/support/c/libidris2_support.so" ;;
    esac
    details=$(file -Lb "$path")
    printf '%s\n' "$details" > "$bundle/receipts/$target.elf.txt"
    case "$details" in
        *'ELF 64-bit'*'x86-64'*) : ;;
        *) printf 'Idriç bundle: incorrect native ABI for %s: %s\n' "$path" "$details" >&2; exit 1 ;;
    esac
done
ldd "$bundle/chez-10.4.1/bin/scheme" > "$bundle/receipts/chez.ldd.txt"
ldd "$bundle/compiler/support/c/libidris2_support.so" > "$bundle/receipts/idric-support.ldd.txt"
if grep -q 'not found' "$bundle/receipts/chez.ldd.txt" "$bundle/receipts/idric-support.ldd.txt"; then
    echo 'Idriç bundle: unresolved host shared library' >&2; exit 1
fi

cat > "$bundle/receipts/identity.txt" <<RECEIPT
schema=catfood-idric-host-bundle-v1
compiler_repository=https://github.com/isomorphisms/Idric
compiler_commit=$expected
host_os=linux
host_arch=x86_64
chez_version=10.4.1
runner_os=$(uname -s)
runner_arch=$(uname -m)
workflow_run=${GITHUB_RUN_ID:-unverified-local}
workflow_attempt=${GITHUB_RUN_ATTEMPT:-unverified-local}
RECEIPT

(cd "$bundle" && find . -type f ! -name 'payload.sha256' -print | LC_ALL=C sort | while IFS= read -r file_path; do sha256sum "$file_path"; done) > "$bundle/payload.sha256"
(cd "$bundle" && sha256sum --status -c payload.sha256)
printf 'Idriç bundle: payload checksums verified\n'
tar --no-same-owner -czf "$output/$name.tar.gz" -C "$output" "$name"
(cd "$output" && sha256sum "$name.tar.gz" > "$name.tar.gz.sha256")
printf 'archive=%s\nsha256=%s\n' "$output/$name.tar.gz" "$(sha256sum "$output/$name.tar.gz" | awk '{print $1}')"
