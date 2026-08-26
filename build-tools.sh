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
rm -f "$build_root/receipts/core-build.tsv"

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

build_icu() {
    repo=$workspace/icu
    idric=$workspace/Idric
    compiler=$idric/build/exec/idris2
    output=$repo/build/exec/icu
    test_output=$repo/build/exec/icu-http-tests
    [ -d "$repo/.git" ] || return 0
    [ -x "$compiler" ] || {
        printf '%s\n' 'ICU needs the built Idriç compiler' >&2
        return 1
    }

    state="$(revision "$repo") $(revision "$idric")"
    if [ ! -x "$output" ] || [ ! -x "$test_output" ] || \
       needs_state_build icu "$state"; then
        printf '%s\n' 'building ICU'
        rm -rf "$repo/build" "$repo/libicu_transport.so"
        (
            cd "$repo"
            PATH="$idric/.tools/bin:$PATH"
            export PATH
            make check-native
            IDRIS2_PREFIX="$idric/bootstrap-build" \
                make IDRIC="$compiler" -j"$jobs"
            IDRIS2_PREFIX="$idric/bootstrap-build" \
                "$compiler" tests/HttpTests.idric -o icu-http-tests
            "$test_output"
        )
        mark_state_built icu "$state"
    fi

    PATH="$idric/.tools/bin:$PATH" "$test_output" >/dev/null
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
    actual=$(PATH="$idric/.tools/bin:$PATH" \
        "$output" -e 'var total = 0; var i = 1; while (i <= 4) { total = total + i; i = i + 1; } console.log("sum", total); if (total === 10) console.log("ok");')
    [ "$actual" = "$expected" ] || {
        printf 'Fieldmouse smoke returned:\n%s\n' "$actual" >&2
        return 1
    }
}

build_ib() {
    repo=$workspace/ib
    idric=$workspace/Idric
    compiler=$idric/build/exec/idris2
    output_dir=$repo/src/build/exec
    [ -d "$repo/.git" ] || return 0
    [ -x "$compiler" ] || {
        printf '%s\n' 'IB needs the built Idriç compiler' >&2
        return 1
    }

    state="$(revision "$repo") $(revision "$idric")"
    if [ ! -x "$output_dir/ib-smoke" ] || \
       [ ! -x "$output_dir/ib-information-smoke" ] || \
       [ ! -x "$output_dir/ib-workbench" ] || \
       [ ! -x "$output_dir/ib-arxiv-prepaint" ] || \
       needs_state_build ib "$state"; then
        printf '%s\n' 'building IB'
        rm -rf "$repo/src/build"
        (
            cd "$repo/src"
            PATH="$idric/.tools/bin:$PATH"
            export PATH
            for source_output in \
                'Smoke.idric ib-smoke' \
                'InformationSmoke.idric ib-information-smoke' \
                'Workbench.idric ib-workbench' \
                'ArxivPrepaint.idric ib-arxiv-prepaint'
            do
                set -- $source_output
                IDRIS2_PREFIX="$idric/bootstrap-build" \
                    "$compiler" "$1" -o "$2"
            done

            ./build/exec/ib-smoke >/dev/null
            ./build/exec/ib-information-smoke >/dev/null
            ./build/exec/ib-workbench >/dev/null
        )
        mark_state_built ib "$state"
    fi

    (
        cd "$repo/src"
        PATH="$idric/.tools/bin:$PATH"
        export PATH
        ./build/exec/ib-smoke >/dev/null
        ./build/exec/ib-information-smoke >/dev/null
        ./build/exec/ib-workbench >/dev/null
    )
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
    source=$build_root/ir-source
    build=$source/code
    runtime=$workspace/r
    output=$runtime/bin/R
    library=$build_root/r-library
    [ -d "$repo/.git" ] || return 0

    if [ ! -x "$output" ] || needs_build ir "$repo"; then
        printf '%s\n' 'building IR'
        rm -rf "$source" "$runtime"
        mkdir -p "$source"

        # Build a committed snapshot in place.  IR's configured base-package
        # DESCRIPTION files declare UTF-8; keeping them beside the Rd sources
        # lets the bootstrap documentation parser honor that declaration while
        # leaving the live checkout clean for future refreshes.
        git -C "$repo" archive HEAD code |
            tar --no-same-owner -x -C "$source"

        (
            cd "$build"
            sh ./configure \
                --prefix="$runtime" \
                --with-x=no \
                --without-tcltk \
                --without-recommended-packages \
                --disable-java
            grep -Fx 'Encoding: UTF-8' src/library/base/DESCRIPTION >/dev/null
            grep -Fx 'Encoding: UTF-8' src/library/stats/DESCRIPTION >/dev/null
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

tree_state() {
    relevant_changes=$(git -C "$1" status --porcelain | awk '
        $2 == "libicu_transport.so" { next }
        $2 ~ /^build\// { next }
        $2 ~ /^src\/build\// { next }
        { print }
    ')
    if [ -n "$relevant_changes" ]; then
        printf '%s\n' dirty
    else
        printf '%s\n' clean
    fi
}

write_core_receipt() {
    receipt_dir=$build_root/receipts
    receipt=$receipt_dir/core-build.tsv
    temporary=$receipt.tmp
    idric_sha=$(revision "$workspace/Idric")

    mkdir -p "$receipt_dir"
    printf 'project\tproject_sha\tcompiler\tcompiler_sha\tbackend\ttree\tstatus\n' > "$temporary"
    printf 'Idric\t%s\tIdric\t%s\tchez\t%s\tpassed\n' \
        "$idric_sha" "$idric_sha" "$(tree_state "$workspace/Idric")" >> "$temporary"
    for project in icu fieldmouse ib; do
        printf '%s\t%s\tIdric\t%s\tchez\t%s\tpassed\n' \
            "$project" "$(revision "$workspace/$project")" "$idric_sha" \
            "$(tree_state "$workspace/$project")" >> "$temporary"
    done
    printf 'ithon\t%s\t-\t-\tnative-c\t%s\tpassed\n' \
        "$(revision "$workspace/ithon")" "$(tree_state "$workspace/ithon")" >> "$temporary"
    mv "$temporary" "$receipt"
    printf 'core build receipt: %s\n' "$receipt"
}

build_idric
build_icu
build_fieldmouse
build_ib
build_ithon
build_ir
write_core_receipt

printf '%s\n' 'cat food core tools are built'
