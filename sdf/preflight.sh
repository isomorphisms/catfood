#!/bin/sh
# Read-only observation of the actual SDF login node. No package acquisition.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$root/android/target.sh"

catfood_verify_sdf_target || exit $?
printf 'schema\tcatfood-sdf-preflight-v1\n'
printf 'host\t%s\n' "$(hostname 2>/dev/null || printf unknown)"
printf 'os\t%s\n' "$(uname -s)"
printf 'release\t%s\n' "$(uname -r)"
printf 'machine\t%s\n' "$(uname -m)"
printf 'source_root\t%s\n' "${CATFOOD_ROOT:-$HOME/code}"
printf 'runtime_root\t%s\n' "${CATFOOD_SDF_RUNTIME_ROOT:-$HOME/opt}"
printf 'user_id\t%s\n' "$(id -u)"

for name in git cc gmake make tar curl wget sha256sum sha256 shasum \
    grease greasecpp scheme lua luac jq mlr R Rscript python python3 \
    python3.9 python3.10 python3.11 python3.12; do
    if path=$(command -v "$name" 2>/dev/null); then
        printf 'command:%s\tPRESENT\t%s\n' "$name" "$path"
    else
        printf 'command:%s\tMISSING\n' "$name"
    fi
done
for path in "$HOME/code" "$HOME/opt" "$HOME/opt/bin" \
    "$HOME/opt/packages" "$HOME/opt/receipts" "$HOME/Mail" "$HOME/mail"; do
    if [ -d "$path" ]; then
        printf 'directory\tPRESENT\t%s\n' "$path"
    else
        printf 'directory\tMISSING\t%s\n' "$path"
    fi
done
for name in python python3 python3.9 python3.10 python3.11 python3.12; do
    if command -v "$name" >/dev/null 2>&1; then
        version=$("$name" -V 2>&1 || printf 'VERSION_CHECK_FAILED')
        printf 'version:%s\t%s\n' "$name" "$version"
    fi
done

# Checking preconditions changes no installed program or personal file.
failed=0
for name in git cc gmake tar; do
    if ! command -v "$name" >/dev/null 2>&1; then
        printf 'required:%s\tBLOCKED\n' "$name" >&2
        failed=1
    fi
done
if ! command -v curl >/dev/null 2>&1 && \
   ! command -v wget >/dev/null 2>&1; then
    printf 'required:download\tBLOCKED (curl or wget required)\n' >&2
    failed=1
fi
if ! command -v sha256sum >/dev/null 2>&1 && \
   ! command -v sha256 >/dev/null 2>&1 && \
   ! command -v shasum >/dev/null 2>&1; then
    printf 'required:sha256\tBLOCKED (digest verification unavailable)\n' >&2
    failed=1
fi
if [ "$failed" -ne 0 ]; then
    printf '%s\n' 'SDF build preflight blocked; nothing was changed' >&2
    exit 1
fi
printf '%s\n' 'SDF build preflight passed; this does not prove any tool installed'
