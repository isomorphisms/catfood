#!/bin/sh
set -eu

# Bounded native macOS workbench entrypoint. Linux/Termux package managers and
# the unqualified cross-platform core build never run here.
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$root/android/target.sh"
catfood_verify_macos_target

workspace=${CATFOOD_ROOT:-$HOME/opt}
case ${CATFOOD_MACOS_FEED:-0} in
    0|1) ;;
    *)
        printf '%s\n' 'CATFOOD_MACOS_FEED must be 0 or 1' >&2
        exit 2
        ;;
esac
if [ "${CATFOOD_BUILD_TOOLS:-0}" != 0 ]; then
    printf '%s\n' 'macOS core project builds are not yet qualified; CATFOOD_BUILD_TOOLS must be 0' >&2
    exit 2
fi

CATFOOD_ROOT=$workspace sh "$root/macos/host-smoke.sh"

if [ "${CATFOOD_MACOS_FEED:-0}" = 1 ]; then
    # Stage-zero Git feed reuses the canonical tool manifest. This is not
    # compilation, installation or runtime acceptance of the fetched tools.
    CATFOOD_ROOT=$workspace CATFOOD_DEPTH=${CATFOOD_DEPTH:-12} \
        sh "$root/bootstrap.sh"
    CATFOOD_ROOT=$workspace CATFOOD_NO_PROFILE=1 \
        sh "$root/activate.sh"
    printf '%s\n' 'macOS source feed finished; core project builds remain unqualified'
else
    printf '%s\n' 'macOS host smoke passed; source feed skipped (CATFOOD_MACOS_FEED=1 to opt in)'
fi
