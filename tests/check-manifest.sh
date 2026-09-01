#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
checker=$root/check-manifest.sh
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

good=$temporary/good.tsv
printf '%s\n' \
    '# fixture' \
    'one https://github.com/example/one.git main none' \
    'two https://github.com/example/two.git feature/branch recursive' \
    'three https://github.com/example/three.git Idriç none' \
    'four https://github.com/example/four.git how-long+how-wide none' \
    > "$good"
CATFOOD_MANIFEST=$good sh "$checker" >/dev/null

expect_failure() {
    name=$1
    shift
    fixture=$temporary/$name.tsv
    printf '%s\n' "$@" > "$fixture"
    if CATFOOD_MANIFEST=$fixture sh "$checker" >/dev/null 2>&1; then
        printf 'manifest fixture unexpectedly passed: %s\n' "$name" >&2
        exit 1
    fi
}

expect_failure fields \
    'one https://github.com/example/one.git main'
expect_failure unsafe-name \
    '../one https://github.com/example/one.git main none'
expect_failure parent-name \
    '.. https://github.com/example/one.git main none'
expect_failure repository \
    'one git@github.com:example/one.git main none'
expect_failure branch-colon \
    'one https://github.com/example/one.git bad:branch none'
expect_failure branch-dotdot \
    'one https://github.com/example/one.git bad..branch none'
expect_failure branch-reflog \
    'one https://github.com/example/one.git bad@{branch none'
expect_failure branch-lock \
    'one https://github.com/example/one.git bad.lock none'
expect_failure branch-hidden-component \
    'one https://github.com/example/one.git feature/.hidden none'
expect_failure submodules \
    'one https://github.com/example/one.git main sometimes'
expect_failure duplicate-name \
    'one https://github.com/example/one.git main none' \
    'one https://github.com/example/two.git main none'
expect_failure duplicate-repository \
    'one https://github.com/example/one.git main none' \
    'two https://github.com/example/one.git main none'

printf '%s\n' 'manifest failure fixtures passed'
