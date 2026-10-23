#!/bin/sh
# Read-only Cat Food SDF report. Presence, compilation, and acceptance differ.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$root/android/target.sh"
. "$root/ci/repositories.sh"
catfood_verify_sdf_target || exit $?

source_root=${CATFOOD_ROOT:-$HOME/code}
runtime_root=${CATFOOD_SDF_RUNTIME_ROOT:-$HOME/opt}
mode=${1:-core}
case "$mode" in core|full) ;; *)
    printf 'usage: catfood-doctor [core|full]\n' >&2; exit 2 ;;
esac
printf 'schema\tcatfood-sdf-doctor-v1\n'
printf 'host\t%s\n' "$(hostname 2>/dev/null || printf unknown)"
printf 'platform\t%s\t%s\n' "$(uname -s)" "$(uname -m)"
printf 'sources\t%s\n' "$source_root"
printf 'runtime\t%s\n' "$runtime_root"

core_failure=0
full_gaps=0
bin=$runtime_root/bin
check_stable() {
    name=$1
    if [ -x "$bin/$name" ]; then
        printf 'stable:%s\tPRESENT_UNTESTED\t%s\n' "$name" "$bin/$name"
    elif command -v "$name" >/dev/null 2>&1; then
        printf 'stable:%s\tHOST_ONLY\t%s\n' "$name" "$(command -v "$name")"
        full_gaps=$((full_gaps + 1))
    else
        printf 'stable:%s\tMISSING\n' "$name"
        full_gaps=$((full_gaps + 1))
    fi
}

# These are Cat Food's intended command entrypoints, not assertions that
# every program has a qualified NetBSD producer.
for name in grease greasecpp greased edric idris2 fieldmouse icu ib-smoke \
    ithon ick osh ysh lua luac R Rscript jq mlr az abe aa \
    gopeed gdl go_down_load fdroid-deploy fdroid-check-deployed \
    catfood-update catfood-doctor catfood-import-config; do
    check_stable "$name"
done

if [ -x "$bin/grease" ]; then
    smoke=$("$bin/grease" -c 'var answer = 6 * 7; write -- "grease=$answer"' 2>/dev/null || :)
    if [ "$smoke" = grease=42 ]; then
        printf 'smoke:grease\tPASS\n'
    else
        printf 'smoke:grease\tFAIL\n'
        core_failure=1
    fi
else
    printf 'smoke:grease\tBLOCKED (stable command missing)\n'
    core_failure=1
fi

compiler=$source_root/Idric/_/build/exec/idris2
chez=$source_root/Idric/_/.tools/bin/scheme
receipt=$runtime_root/receipts/idric-netbsd-amd64.tsv

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v sha256 >/dev/null 2>&1; then
        sha256 -q "$1"
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        return 1
    fi
}

if [ -x "$compiler" ] && [ -x "$chez" ] && [ -x "$bin/edric" ] && \
   [ -x "$bin/idris2" ] && [ -f "$receipt" ] && \
   [ -e "$source_root/Idric/.git" ] && \
   "$compiler" --version >/dev/null 2>&1; then
    source_sha=$(git -C "$source_root/Idric" rev-parse HEAD)
    expected_source=$(awk -F '\t' '$1 == "source_sha" {print $2}' "$receipt")
    expected_digest=$(awk -F '\t' '$1 == "compiler_sha256" {print $2}' "$receipt")
    actual_digest=$(sha256_file "$compiler" || :)
    machine=$(printf '(display (machine-type))\n(newline)\n' | "$chez" --quiet 2>/dev/null | tail -n 1)
    threaded=$(printf '(display (threaded?))\n(newline)\n' | "$chez" --quiet 2>/dev/null | tail -n 1)
    if [ "$source_sha" = "$expected_source" ] && \
       [ -n "$actual_digest" ] && [ "$actual_digest" = "$expected_digest" ] && \
       [ "$machine" = ta6nb ] && [ "$threaded" = '#t' ]; then
        printf 'compiler:idric\tPASS\t%s\t%s\n' "$source_sha" "$actual_digest"
    else
        printf 'compiler:idric\tSTALE_OR_INCONSISTENT\n'
        core_failure=1
    fi
else
    printf 'compiler:idric\tNOT_BUILT_OR_UNVERIFIED\n'
    core_failure=1
fi

# --full checks the whole feed independently of the runnable-command matrix.
if [ "$mode" = full ]; then
    while read -r name repository branch submodules || [ -n "${name:-}" ]; do
        case ${name:-} in ''|\#*) continue ;; esac
        checkout=$source_root/$name
        if [ -e "$checkout/.git" ]; then
            origin=$(git -C "$checkout" remote get-url origin 2>/dev/null || :)
            if same_repository_url "$origin" "$repository"; then
                printf 'source:%s\tPRESENT\t%s\n' "$name" \
                    "$(git -C "$checkout" rev-parse HEAD)"
            else
                printf 'source:%s\tORIGIN_MISMATCH\n' "$name"
                full_gaps=$((full_gaps + 1))
            fi
        else
            printf 'source:%s\tMISSING\n' "$name"
            full_gaps=$((full_gaps + 1))
        fi
    done < "$root/tools.tsv"
fi

if [ "$core_failure" -ne 0 ]; then
    printf 'status\tBLOCKED_CORE\n'
    exit 1
fi
if [ "$mode" = full ] && [ "$full_gaps" -ne 0 ]; then
    printf 'status\tINCOMPLETE_FULL\t%d\n' "$full_gaps"
    exit 1
fi
if [ "$mode" = full ]; then
    printf 'status\tPRESENT_NOT_ALL_VERIFIED\n'
else
    printf 'status\tCORE_COMPILER_VERIFIED; OTHER_TOOLS_UNVERIFIED\n'
fi
