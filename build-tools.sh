#!/bin/sh
set -eu

workspace=${CATFOOD_ROOT:-/opt}
build_root=${CATFOOD_BUILD_ROOT:-$workspace/.build}
jobs=${CATFOOD_JOBS:-2}
stamps=$build_root/stamps

mkdir -p "$build_root" "$stamps"

revision() {
    git -C "$1" rev-parse HEAD
}

needs_build() {
    name=$1
    repo=$2
    stamp=$stamps/$name
    rev=$(revision "$repo")
    [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$rev" ]
}

mark_built() {
    name=$1
    repo=$2
    revision "$repo" > "$stamps/$name"
}

build_idric() {
    repo=$workspace/Idric
    output=$repo/build/exec/idris2
    [ -d "$repo/.git" ] || return 0

    if [ ! -x "$output" ] || needs_build idric "$repo"; then
        printf '%s\n' 'building Idriç'
        (
            cd "$repo"
            PATH="$repo/.tools/bin:$PATH" JOBS=$jobs sh ./edric all
        )
        mark_built idric "$repo"
    fi

    "$output" --version >/dev/null
}

build_ithon() {
    repo=$workspace/ithon
    build=$build_root/ithon
    output=$build/python
    [ -d "$repo/.git" ] || return 0

    if [ ! -x "$output" ] || needs_build ithon "$repo"; then
        printf '%s\n' 'building Ithon'
        rm -rf "$build"
        mkdir -p "$build"
        (
            cd "$build"
            "$repo/configure" --with-pydebug
            make -j"$jobs"
            ./python -m test -v test_ithon_syntax
        )
        mark_built ithon "$repo"
    fi

    "$output" -c 'x ← 42; assert x == 42'
}

build_ir() {
    repo=$workspace/ir
    build=$build_root/ir
    runtime=$workspace/r
    output=$runtime/bin/R
    library=$build_root/r-library
    [ -d "$repo/.git" ] || return 0

    if [ ! -x "$output" ] || needs_build ir "$repo"; then
        printf '%s\n' 'building IR'
        rm -rf "$build" "$runtime"
        mkdir -p "$build"
        (
            cd "$build"
            sh "$repo/code/configure" \
                --prefix="$runtime" \
                --with-x=no \
                --without-tcltk \
                --without-recommended-packages \
                --disable-java
            make -j"$jobs"
            make install
        )
        mark_built ir "$repo"
    fi

    mkdir -p "$library"
    R_LIBS_USER="$library" \
        "$output" --vanilla --slave \
        -e 'answer ← 8 ÷ 2; stopifnot((answer = 4))'
}

build_idric
build_ithon
build_ir

printf '%s\n' 'cat food core tools are built'
