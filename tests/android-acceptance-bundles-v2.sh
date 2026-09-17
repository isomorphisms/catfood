#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
runner="$root/android/acceptance/run-v2.sh"
builder="$root/android/acceptance/build-bundles-v2.sh"

sh -n "$runner"
sh -n "$builder"

grep -Fq 'parser_mode=osh' "$runner"
grep -Fq 'parser_mode=ysh' "$runner"
grep -Fq 'ln -sf ysh' "$runner"
grep -Fq 'chmod 0444 "$dex" "$library"' "$runner"
grep -Fq '# catfood aa wrapper' "$runner"
grep -Fq 'run_case grease_readable_osh' "$runner"
grep -Fq 'run_case grease_ib_ysh_mapped_index' "$runner"
grep -Fq 'run_case cloud_storage_osh_help' "$runner"

grep -Fq 'c5b69d7fa0ea7672c9b9bf5dbce5367cee31325f' "$builder"
grep -Fq 'a9212ae25d7498ac080ad40e6cadd5b192e596dfdfc726c8f6492ba5c71f780c' "$builder"
grep -Fq 'run-v2.sh' "$builder"

printf '%s\n' 'corrected Android acceptance bundle contract: PASS'
