#!/bin/sh
set -eu

root_script=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
. "$root_script/platform.sh"
. "$root_script/grease-package.conf"

CATFOOD_SDF_EXPECT_RELEASE=$GREASE_TARGET_RELEASE
export CATFOOD_SDF_EXPECT_RELEASE
catfood_sdf_require_platform

for command_name in awk cp ln mkdir mv rm tar; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'cat food sdf needs %s\n' "$command_name" >&2
        exit 127
    }
done

downloader=$(catfood_sdf_choose_downloader)
sha256_backend=$(catfood_sdf_sha256_backend)
empty_sha256=$(catfood_sdf_sha256 /dev/null)
expected_empty_sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
[ "$empty_sha256" = "$expected_empty_sha256" ] || {
    printf 'cat food sdf SHA-256 probe failed with %s: %s\n' "$sha256_backend" "$empty_sha256" >&2
    exit 1
}

root=${CATFOOD_ROOT:-"$HOME/opt"}
if ! mkdir -p "$root" "$root/receipts"; then
    printf 'cat food sdf cannot create install root: %s\n' "$root" >&2
    exit 1
fi
[ -d "$root" ] && [ -w "$root" ] || {
    printf 'cat food sdf install root is not writable: %s\n' "$root" >&2
    exit 1
}

printf 'system=%s\n' "$(catfood_sdf_system)"
printf 'release=%s\n' "$(catfood_sdf_release)"
printf 'machine=%s\n' "$(catfood_sdf_machine)"
printf 'root=%s\n' "$root"
printf 'downloader=%s\n' "$downloader"
printf 'sha256=%s\n' "$sha256_backend"
printf '%s\n' 'preflight=pass'
