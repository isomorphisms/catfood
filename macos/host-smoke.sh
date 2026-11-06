#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$root/android/target.sh"
catfood_verify_macos_target

workspace=${CATFOOD_ROOT:-$HOME/opt}
for name in git xcrun sw_vers mktemp lipo; do
    command -v "$name" >/dev/null 2>&1 || {
        printf 'macOS host smoke needs %s\n' "$name" >&2
        exit 127
    }
done
[ -d "$root/.git" ] || [ -f "$root/.git" ] || {
    printf '%s\n' 'macOS host smoke needs a Git checkout of Cat Food' >&2
    exit 2
}
source_commit=$(git -C "$root" rev-parse --verify HEAD) || exit 2
if [ -n "$(git -C "$root" status --porcelain)" ]; then
    printf '%s\n' 'macOS host smoke requires a clean Cat Food source tree' >&2
    exit 2
fi

sdk_path=$(xcrun --sdk macosx --show-sdk-path) || {
    printf '%s\n' 'macOS SDK not available through selected developer directory' >&2
    exit 127
}
[ -d "$sdk_path" ] || {
    printf 'macOS SDK directory does not exist: %s\n' "$sdk_path" >&2
    exit 2
}
sdk_version=$(xcrun --sdk macosx --show-sdk-version)
compiler=$(xcrun --sdk macosx --find clang) || {
    printf '%s\n' 'Apple Clang is unavailable through xcrun' >&2
    exit 127
}
[ -x "$compiler" ] || {
    printf 'Apple Clang is not executable: %s\n' "$compiler" >&2
    exit 127
}
compiler_version=$("$compiler" --version | sed -n '1p')
os_version=$(sw_vers -productVersion)
os_build=$(sw_vers -buildVersion)
model=$(sysctl -n hw.model 2>/dev/null || printf '%s\n' unknown)

# Compile and execute a real ARM64 Mach-O linked against a macOS framework.
# Tool presence, successful compilation, and native execution are distinct.
scratch=$(mktemp -d "${TMPDIR:-/tmp}/catfood-macos.XXXXXXXX")
trap 'rm -rf "$scratch"' 0 HUP INT TERM
cat > "$scratch/main.c" <<'EOF_C'
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
int main(void) {
    if (CFStringGetLength(CFSTR("catfood")) != 7) return 3;
    printf("catfood-macos=%d\\n", 6 * 7);
    return 0;
}
EOF_C
"$compiler" -arch arm64 -isysroot "$sdk_path" -std=c11 -Wall -Wextra -Werror \
    "$scratch/main.c" -framework CoreFoundation -o "$scratch/native-smoke" || {
    printf '%s\n' 'macOS ARM64 CoreFoundation compile/link failed' >&2
    exit 3
}
binary_arch=$(lipo -archs "$scratch/native-smoke") || {
    printf '%s\n' 'macOS compiled binary architecture inspection failed' >&2
    exit 3
}
[ "$binary_arch" = arm64 ] || {
    printf 'macOS native smoke produced wrong Mach-O architecture: %s\n' "$binary_arch" >&2
    exit 3
}
runtime_output=$("$scratch/native-smoke") || {
    printf '%s\n' 'macOS native ARM64 execution failed' >&2
    exit 3
}
[ "$runtime_output" = catfood-macos=42 ] || {
    printf 'macOS native ARM64 smoke returned unexpected output: %s\n' "$runtime_output" >&2
    exit 3
}

umask 077
mkdir -p "$workspace/receipts"
receipt="$workspace/receipts/macos-host-smoke.tsv"
temporary="$receipt.tmp.$$"
trap 'rm -rf "$scratch"; rm -f "$temporary"' 0 HUP INT TERM
{
    printf 'schema\tcatfood-macos-host-smoke-v1\n'
    printf 'source_commit\t%s\n' "$source_commit"
    printf 'source_tree\tclean\n'
    printf 'host_os\tDarwin\n'
    printf 'host_architecture\tarm64\n'
    printf 'host_model\t%s\n' "$model"
    printf 'os_version\t%s\n' "$os_version"
    printf 'os_build\t%s\n' "$os_build"
    printf 'sdk_version\t%s\n' "$sdk_version"
    printf 'compiler_version\t%s\n' "$compiler_version"
    printf 'compile_link_result\tPASS\n'
    printf 'macho_architecture\t%s\n' "$binary_arch"
    printf 'native_execution_result\tPASS\n'
    printf 'native_execution_output\t%s\n' "$runtime_output"
} > "$temporary"
mv "$temporary" "$receipt"
printf 'macOS ARM64 host compile/link/execute smoke PASS (%s, SDK %s)\n' "$model" "$sdk_version"
printf 'receipt: %s\n' "$receipt"
