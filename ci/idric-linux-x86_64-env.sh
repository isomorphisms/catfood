#!/bin/sh
# Runtime launcher shipped inside the pinned Linux x86_64 Idriç archive.
set -eu

bundle=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
scheme="$bundle/chez-10.4.1/bin/scheme"
program="$bundle/compiler/build/exec/idris2_app/idris2.so"
[ -f "$program" ] || program="$bundle/compiler/build/exec/idris2_app/idris2.ss"

[ -x "$scheme" ] || { echo 'idric: bundled Chez Scheme is missing' >&2; exit 1; }
[ -f "$program" ] || { echo 'idric: compiled Idriç program is missing' >&2; exit 1; }

scheme_boot=$(find "$bundle/chez-10.4.1" -type f -name scheme.boot -print -quit)
[ -n "$scheme_boot" ] || { echo 'idric: bundled Chez boot files are missing' >&2; exit 1; }
SCHEMEHEAPDIRS=$(dirname -- "$scheme_boot")
export SCHEMEHEAPDIRS

# These are the exact directories used by the successful source acceptance,
# relocated beneath this archive rather than restored from a GitHub cache.
IDRIS2_PATH=''
for library in prelude base linear network contrib test; do
    path="$bundle/compiler/libs/$library/build/ttc"
    [ -d "$path" ] || { echo "idric: missing $library TTC library" >&2; exit 1; }
    if [ -z "$IDRIS2_PATH" ]; then IDRIS2_PATH=$path; else IDRIS2_PATH="$IDRIS2_PATH:$path"; fi
done
IDRIS2_DATA="$bundle/compiler/support"
IDRIS2_LIBS="$bundle/compiler/support/c"
LD_LIBRARY_PATH="$bundle/compiler/build/exec/idris2_app:$IDRIS2_LIBS${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
CHEZ=$scheme
IDRIS2_INC_SRC="$bundle/compiler/build/exec/idris2_app"
PATH="$bundle/bin:$PATH"
export IDRIS2_PATH IDRIS2_DATA IDRIS2_LIBS IDRIS2_INC_SRC LD_LIBRARY_PATH CHEZ PATH

case "${0##*/}" in
    idric|idris2)
        exec "$scheme" --program "$program" "$@"
        ;;
    idric-env)
        [ "$#" -gt 0 ] || { echo 'usage: idric-env COMMAND [ARG ...]' >&2; exit 2; }
        exec "$@"
        ;;
    *) echo 'idric: unknown launch entrypoint' >&2; exit 2 ;;
esac
