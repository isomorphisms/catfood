#!/bin/sh
# Stage zero only. Cat Food owns discovery, acquisition and command exposure.
set -eu
umask 077
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$root/android/target.sh"
fail() { printf '\033[31mFAIL Cat Food Grease: %s\033[0m\n' "$*" >&2; exit 2; }
target=$(catfood_detect_android_target)
case $target in phone|c67|tablet) ;; *) fail 'known Android device identity required';; esac
if [ -n "${CATFOOD_TARGET:-}" ] && [ "$CATFOOD_TARGET" != "$target" ]; then fail 'requested target differs from observed device'; fi
catfood_android_require_device "$target"
sh "$root/android/ensure-transfer-support.sh"
case ${PREFIX:-} in /data/data/com.termux/files/usr) ;; *) fail 'ordinary Termux context required';; esac
case ${CATFOOD_ROOT:-$HOME/opt} in /*) ;; *) fail 'installation root must be absolute';; esac
workspace=${CATFOOD_ROOT:-$HOME/opt}
mkdir -p "$workspace"
workspace=$(CDPATH='' cd -- "$workspace" && pwd -P)
case $workspace in /data/data/com.termux/files/*) ;; *) fail 'runtime root must resolve to Termux-private storage';; esac
for utility in awk grep od xargs readlink mktemp timeout; do
    command -v "$utility" >/dev/null 2>&1 || fail "missing stage-zero utility: $utility"
done
case $target in phone) package=grease-phone;; *) package=grease-tablet;; esac
package_ref=$(awk -F '\t' -v p="$package" '$1==p && $10=="grease"{print $7}' "$root/android/packages.tsv")
package_dir=$workspace/packages/$package/$package_ref
mkdir -p "$workspace/bin" "$workspace/receipts" "$workspace/packages"
lock=$workspace/receipts/grease-provision.lock
mkdir "$lock" 2>/dev/null || fail "another or interrupted provision owns $lock; inspect it before retrying"
trap 'rmdir "$lock"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
action=reuse
prior_command=$(command -v grease || :)
check_command_ownership() {
    for name in grease ysh; do
        destination=$workspace/bin/$name
        if [ -e "$destination" ] || [ -L "$destination" ]; then
            [ -L "$destination" ] || fail "unowned command preserved: $destination"
            [ ! -d "$destination" ] || fail "command points to a directory: $destination"
            existing=$(readlink "$destination")
            case $existing in "$workspace/packages/grease-phone/"*|"$workspace/packages/grease-tablet/"*) ;; *) fail "unowned command link preserved: $destination";; esac
        fi
    done
}
# No installer may replace an unrelated command before this check or expose a
# package that has not yet passed the actual native execution probe below.
check_command_ownership
if [ -d "$package_dir" ]; then
    sh "$root/android/verify-grease-package.sh" "$package_dir" "$package" >&2 || fail 'installed package is corrupt or incompatible; preserved for diagnosis'
else
    printf '\033[33mACTION acquire pinned %s runtime through Cat Food\033[0m\n' "$package" >&2
    CATFOOD_TARGET=$target CATFOOD_ROOT=$workspace CATFOOD_ANDROID_ONLY=$package CATFOOD_ANDROID_DEFER_COMMANDS=1 \
        sh "$root/android/install.sh" >&2
    action=acquire
fi
sh "$root/android/verify-grease-package.sh" "$package_dir" "$package" >&2
# The package launcher locates its sibling engine. Invoke the verified package
# pathname, not a symlink to that launcher in a different directory.
chmod u+x "$package_dir/bin/grease" "$package_dir/bin/ysh"
probe=$(mktemp "$workspace/receipts/.grease-probe.XXXXXX")
if timeout 15 "$package_dir/bin/grease" -c 'var answer = 6 * 7; if (answer !== 42) { exit 8 }; write -- "grease=42"' > "$probe" 2> "$probe.stderr"; then
    [ "$(cat "$probe")" = grease=42 ] || fail "unexpected runtime behavior; retained $probe"
else
    cat "$probe.stderr" >&2
    fail "native runtime cannot execute; retained $probe"
fi
# Preflight both destinations before changing either. The packaged launcher
# invokes sibling ysh, so repairing only grease is insufficient.
check_command_ownership
for name in ysh grease; do
    destination=$workspace/bin/$name
    if [ "$(readlink "$destination" 2>/dev/null || :)" != "$package_dir/bin/$name" ]; then
        temporary_link=$lock/$name
        ln -s "$package_dir/bin/$name" "$temporary_link"
        mv -f "$temporary_link" "$destination"
        if [ "$action" = reuse ]; then action=expose; fi
    fi
done
# The returned verified package path works even with no Cat Food PATH entry.
runtime=$package_dir/bin/grease
device_id=$(catfood_android_device_id)
receipt=$(mktemp "$workspace/receipts/$target-grease-runtime.XXXXXX.tsv")
if [ "$action" = reuse ] && [ "$(readlink -f "${prior_command:-/nonexistent}" 2>/dev/null || :)" != "$runtime" ]; then action=expose; fi
{
    printf 'schema\tcatfood-grease-runtime-v1\n'
    printf 'target\t%s\ndevice_id\t%s\n' "$target" "$device_id"
    printf 'model\t%s\nabi\t%s\n' "$(catfood_android_getprop ro.product.model)" "$(catfood_android_getprop ro.product.cpu.abi)"
    printf 'package\t%s\npackage_ref\t%s\n' "$package" "$package_ref"
    printf 'package_dir\t%s\nruntime\t%s\npath_prefix\t%s\n' "$package_dir" "$runtime" "$package_dir/bin"
    printf 'previous_command\t%s\naction\t%s\n' "${prior_command:--}" "$action"
    printf 'path_before\t%s\n' "$PATH"
    printf 'payload_verification\tPASS\nruntime_probe\tPASS\nphysical_acceptance\tNOT_VERIFIED\n'
} > "$receipt"
chmod 0444 "$receipt" "$probe" "$probe.stderr"
# Single path on stdout is the machine contract; diagnostics stay on stderr.
printf '\033[32mPASS native Grease %s; receipt %s\033[0m\n' "$action" "$receipt" >&2
printf '%s\n' "$runtime"
