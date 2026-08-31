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

build_grease() {
    checkout=$workspace/grease
    repo=$checkout/source
    grease_build=$build_root/grease
    python_source=$repo/Python-2.7.13
    python_build=$grease_build/python2
    python_prefix=$grease_build/python2-prefix
    python=$python_build/python
    output=$grease_build/bin/grease
    [ -e "$repo/.git" ] || return 0

    state="$(revision "$checkout") $(revision "$repo")"
    if [ ! -x "$output" ] || needs_state_build grease "$state"; then
        printf '%s\n' 'building Grease from its pinned source'
        rm -rf "$grease_build"
        mkdir -p "$grease_build/bin"
        cp -R "$python_source" "$python_build"

        (
            cd "$python_build"
            touch Include/Python-ast.h Python/Python-ast.c
            ./configure --prefix="$python_prefix" --without-ensurepip
            make -j"$jobs" python
            make -j"$jobs" sharedmods
            make inclinstall
        )
        ln -s "$python" "$grease_build/bin/python2"

        (
            cd "$repo"
            PATH="$grease_build/bin:$PATH"
            export PATH
            ./configure
            build/stamp.sh write-git-commit
            build/py.sh py-source
            build/py.sh pylibc
            build/py.sh posix_
            build/py.sh fanos
            build/py.sh fastfunc
        )

        {
            printf '%s\n' '#!/bin/sh'
            printf '%s\n' '# catfood Grease source launcher'
            printf 'PYTHONPATH="%s:%s/vendor"\n' "$repo" "$repo"
            printf 'export PYTHONPATH\n'
            printf 'exec "%s" "%s/bin/oils_for_unix.py" ysh "$@"\n' "$python" "$repo"
        } > "$output"
        chmod 0755 "$output"
        mark_state_built grease "$state"
    fi

    expected=grease=221
    actual=$($output -c 'var answer = 13 * 17; write -- "grease=$answer"')
    [ "$actual" = "$expected" ] || {
        printf 'Grease smoke returned:\n%s\n' "$actual" >&2
        return 1
    }
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

build_icu() {
    repo=$workspace/icu
    idric=$workspace/Idric
    compiler=$idric/build/exec/idris2
    output=$repo/build/exec/icu
    [ -d "$repo/.git" ] || return 0
    [ -x "$compiler" ] || {
        printf '%s\n' 'ICU needs the built Idriç compiler' >&2
        return 1
    }

    state="$(revision "$repo") $(revision "$idric")"
    if [ ! -x "$output" ] || needs_state_build icu "$state"; then
        printf '%s\n' 'building ICU'
        (
            cd "$repo"
            PATH="$idric/.tools/bin:$PATH" \
            IDRIS2_PREFIX="$idric/bootstrap-build" \
                make -j"$jobs" IDRIC="$compiler"
        )
        mark_state_built icu "$repo"
    fi

    [ -x "$output" ] || {
        printf '%s\n' 'ICU did not produce build/exec/icu' >&2
        return 1
    }
}

build_ib() {
    repo=$workspace/ib
    idric=$workspace/Idric
    compiler=$idric/build/exec/idris2
    output=$repo/src/build/exec/ib-smoke
    [ -d "$repo/.git" ] || return 0
    [ -x "$compiler" ] || {
        printf '%s\n' 'IB needs the built Idriç compiler' >&2
        return 1
    }

    state="$(revision "$repo") $(revision "$idric")"
    if [ ! -x "$output" ] || needs_state_build ib "$state"; then
        printf '%s\n' 'building IB'
        rm -rf "$repo/src/build"
        (
            cd "$repo/src"
            PATH="$idric/.tools/bin:$PATH" \
            IDRIS2_PREFIX="$idric/bootstrap-build" \
                "$compiler" Smoke.idric -o ib-smoke
        )
        mark_state_built ib "$repo"
    fi

    "$output" >/dev/null
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

    "$output" -c 'x ← 221; assert x == 221'
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

build_grease
build_idric
build_fieldmouse
build_icu
build_ib
build_ithon
build_ir

printf '%s\n' 'cat food core tools are built'
