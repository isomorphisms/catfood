#!/bin/sh
set -eu

catfood_locale=${CATFOOD_LOCALE:-C.UTF-8}
LANG=$catfood_locale
LC_ALL=$catfood_locale
export LANG LC_ALL

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
workspace=${CATFOOD_ROOT:-/opt}
manifest=${CATFOOD_MANIFEST:-$root/tools.tsv}
failures=0

if [ -n "${CATFOOD_PREFIX:-}" ]; then
    prefix=$CATFOOD_PREFIX
elif [ "$(id -u)" -eq 0 ]; then
    prefix=/usr/local
else
    prefix=$HOME/.local
fi

PATH=$prefix/bin:$workspace/bin:$PATH
export PATH

CATFOOD_MANIFEST=$manifest sh "$root/check-manifest.sh" || failures=1

check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        printf '%-22s ok\n' "$1"
    else
        printf '%-22s missing\n' "$1" >&2
        failures=1
    fi
}

check_stable() {
    name=$1
    if [ -x "$workspace/bin/$name" ]; then
        printf '%-22s stable\n' "$name"
    else
        printf '%-22s missing stable command\n' "$name" >&2
        failures=1
    fi
}

for command_name in git curl jq R Rscript grease edric idris2 fieldmouse icu ib-smoke ithon osh ysh az abe fdroid-deploy fdroid-check-deployed catfood-update catfood-doctor catfood-import-config; do
    check_command "$command_name"
done

for stable_name in R Rscript grease edric idris2 fieldmouse icu ib-smoke ithon osh ysh az abe fdroid-deploy fdroid-check-deployed catfood-update catfood-doctor catfood-import-config; do
    check_stable "$stable_name"
done

if [ -x "$workspace/bin/osh" ] && ! "$workspace/bin/osh" -c 'echo' >/dev/null 2>&1; then
    printf '%-22s stable command not runnable\n' osh >&2
    failures=1
fi
if [ -x "$workspace/bin/ysh" ] && ! "$workspace/bin/ysh" -c 'echo' >/dev/null 2>&1; then
    printf '%-22s stable command not runnable\n' ysh >&2
    failures=1
fi
if [ -x "$workspace/bin/grease" ]; then
    output=$("$workspace/bin/grease" -c 'var answer = 6 * 7; write -- "grease=$answer"' 2>/dev/null || true)
    if [ "$output" != grease=42 ]; then
        printf '%-22s source interpreter smoke failed\n' grease >&2
        failures=1
    fi
fi
if [ -x "$workspace/bin/idris2" ] && ! "$workspace/bin/idris2" --version >/dev/null 2>&1; then
    printf '%-22s stable command not runnable\n' idris2 >&2
    failures=1
fi
if [ -x "$workspace/bin/fieldmouse" ]; then
    output=$("$workspace/bin/fieldmouse" -e 'console.log("catfood-fieldmouse");' 2>/dev/null || true)
    if [ "$output" != catfood-fieldmouse ]; then
        printf '%-22s interpreter smoke failed\n' fieldmouse >&2
        failures=1
    fi
fi
if [ -x "$workspace/bin/ithon" ] && ! "$workspace/bin/ithon" -c 'x ← 42; assert x == 42' >/dev/null 2>&1; then
    printf '%-22s arrow syntax smoke failed\n' ithon >&2
    failures=1
fi
if [ -x "$workspace/bin/ib-smoke" ] && ! "$workspace/bin/ib-smoke" >/dev/null 2>&1; then
    printf '%-22s executable smoke failed\n' ib-smoke >&2
    failures=1
fi
if [ -x "$workspace/bin/fdroid-deploy" ] && ! "$workspace/bin/fdroid-deploy" --help >/dev/null 2>&1; then
    printf '%-22s help smoke failed\n' fdroid-deploy >&2
    failures=1
fi
if [ -x "$workspace/bin/fdroid-check-deployed" ] && ! "$workspace/bin/fdroid-check-deployed" --help >/dev/null 2>&1; then
    printf '%-22s help smoke failed\n' fdroid-check-deployed >&2
    failures=1
fi
if [ -x "$workspace/bin/R" ]; then
    mkdir -p "$workspace/.build/r-library"
    if ! R_LIBS_USER="$workspace/.build/r-library" \
        "$workspace/bin/R" --vanilla --slave \
        -e 'answer ← 8 ÷ 2; stopifnot((answer = 4))' >/dev/null 2>&1; then
        printf '%-22s glyph syntax smoke failed\n' R >&2
        failures=1
    fi
fi

while read -r name repository branch submodules || [ -n "${name:-}" ]; do
    case ${name:-} in
        ''|'#'*) continue ;;
    esac

    checkout=$workspace/$name
    if [ -e "$checkout/.git" ]; then
        printf '%-22s present\n' "$name"

        has_submodules=0
        if [ -f "$checkout/.gitmodules" ]; then
            if ! git -C "$checkout" config -f .gitmodules --list >/dev/null 2>&1; then
                printf '%-22s malformed .gitmodules\n' "$name" >&2
                failures=1
            elif git -C "$checkout" config -f .gitmodules \
                --get-regexp '^submodule[.].*[.]path$' >/dev/null 2>&1; then
                has_submodules=1
            fi
        fi

        if [ "$has_submodules" -eq 1 ] && [ "$submodules" != recursive ]; then
            printf '%-22s has untracked submodule policy\n' "$name" >&2
            failures=1
        elif [ "$has_submodules" -eq 0 ] && [ "$submodules" = recursive ]; then
            printf '%-22s marked recursive without .gitmodules\n' "$name" >&2
            failures=1
        elif [ "$has_submodules" -eq 1 ]; then
            submodule_status=$(git -C "$checkout" submodule status --recursive 2>/dev/null || true)
            if printf '%s\n' "$submodule_status" | grep '^[+U-]' >/dev/null 2>&1; then
                printf '%-22s submodules are not at recorded commits\n' "$name" >&2
                failures=1
            fi
        fi
    else
        printf '%-22s missing checkout\n' "$name" >&2
        failures=1
    fi
done < "$manifest"

config_home=${XDG_CONFIG_HOME:-$HOME/.config}
amazon_secret=$config_home/az/amazon-secret
abebooks_secret=$config_home/az/abebooks-impact

if [ -x "$workspace/bin/az" ]; then
    if ! "$workspace/bin/az" link B000000000 >/dev/null 2>&1; then
        printf '%-22s public link smoke failed\n' az >&2
        failures=1
    fi
    if ! "$workspace/bin/az" doctor >/dev/null 2>&1; then
        printf '%-22s dependency doctor failed\n' az >&2
        failures=1
    fi
fi

if [ -x "$workspace/bin/abe" ]; then
    if ! "$workspace/bin/abe" link 'https://www.abebooks.com/servlet/BookDetailsPL?bi=1' >/dev/null 2>&1; then
        printf '%-22s public link smoke failed\n' abe >&2
        failures=1
    fi
    if [ -f "$abebooks_secret" ] && ! "$workspace/bin/abe" doctor >/dev/null 2>&1; then
        printf '%-22s configured provider doctor failed\n' abe >&2
        failures=1
    fi
fi

if [ -f "$amazon_secret" ]; then
    printf '%-22s configured\n' 'Amazon Creators'
else
    printf '%s\n' 'Amazon Creators credentials: not configured (public az link still works)'
fi
if [ -f "$abebooks_secret" ]; then
    printf '%-22s configured\n' 'AbeBooks search'
else
    printf '%s\n' 'AbeBooks client key: not configured (abe link still works)'
fi

if [ "$failures" -ne 0 ]; then
    printf '%s\n' 'cat food workbench has failures' >&2
    exit 1
fi

printf '%s\n' 'cat food workbench is ready'
