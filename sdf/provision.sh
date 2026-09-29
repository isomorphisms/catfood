#!/bin/sh
set -eu

root_script=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

CATFOOD_ROOT=${CATFOOD_ROOT:-"$HOME/opt"}
export CATFOOD_ROOT

sh "$root_script/preflight.sh"
sh "$root_script/fetch-grease.sh"

printf 'cat food sdf runtime is current under %s\n' "$CATFOOD_ROOT"
