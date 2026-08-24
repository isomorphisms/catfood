#!/bin/sh
set -eu

build_locale=${CATFOOD_LOCALE:-C.UTF-8}
LANG=$build_locale
LC_ALL=$build_locale
export LANG LC_ALL

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

needs_state_build() {
    name=$1
    state=$2
    stamp=$stamps/$name
    [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$state" ]
}

mark_state_built() {
    name=$1
    state=$2
    printf '%s\n' "$state" > "$stamps/$name"
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

build_fieldmouse() {
    repo=$workspace/fieldmouse
    idric=$workspace/Idric
    compiler=$idric/build/exec/idris2
    output=$repo/build/exec/fieldmouse
    [ -d "$repo/.git" ] || return 0
    [ -x "$compiler" ] || {
        printf '%s\n' 'Fieldmouse needs the built Idriç compiler' >&2
        return 1
    }

    state="$(revision "$repo") $(revision "$idric")"
    if [ ! -x "$output" ] || needs_state_build fieldmouse "$state"; then
        printf '%s\n' 'building Fieldmouse'
        rm -rf "$repo/build"
        (
            cd "$repo"
            PATH="$idric/.tools/bin:$PATH" \
            IDRIS2_PREFIX="$idric/bootstrap-build" \
                "$compiler" --build fieldmouse.ipkg
        )
        mark_state_built fieldmouse "$state"
    fi

    expected=$(printf 'sum 10.0\nok')
    actual=$("$output" -e 'var total = 0; var i = 1; while (i <= 4) { total = total + i; i = i + 1; } console.log("sum", total); if (total === 10) console.log("ok");')
    [ "$actual" = "$expected" ] || {
        printf 'Fieldmouse smoke returned:\n%s\n' "$actual" >&2
        return 1
    }
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

            # IR's Unicode operators also occur in base Rd pages.  Its
            # bootstrap parser treats those pages as native ASCII, so
            # declare their encoding in the generated build makefile.
            # Keep the upstream checkout clean for the next refresh.
            rd_makefile=src/library/Makefile
            rd_makefile_patched=$rd_makefile.catfood
            sed '/install_package_Rd_objects/{n;s/)" |/, encoding = \\"UTF-8\\")" |/;}' \
                "$rd_makefile" > "$rd_makefile_patched"
            grep -F 'encoding = \"UTF-8\"' "$rd_makefile_patched" >/dev/null
            mv "$rd_makefile_patched" "$rd_makefile"

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
build_fieldmouse
build_ithon
build_ir

printf '%s\n' 'cat food core tools are built'
