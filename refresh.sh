#!/bin/sh
set -eu

catfood_locale=${CATFOOD_LOCALE:-C.UTF-8}
LANG=$catfood_locale
LC_ALL=$catfood_locale
export LANG LC_ALL

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
workspace=${CATFOOD_ROOT:-/opt}

if [ -n "${CATFOOD_PREFIX:-}" ]; then
    prefix=$CATFOOD_PREFIX
elif [ "$(id -u)" -eq 0 ]; then
    prefix=/usr/local
else
    prefix=$HOME/.local
fi

PATH=$prefix/bin:$workspace/bin:$PATH
export PATH

CATFOOD_ROOT=$workspace CATFOOD_DEPTH=${CATFOOD_DEPTH:-12} \
    sh "$root/bootstrap.sh"

# Ensure the stable shell paths prefer the installed native Oils release before
# project builds invoke any shell-dependent tooling.
CATFOOD_ROOT=$workspace CATFOOD_PREFIX=$prefix \
    sh "$root/activate.sh"

if [ "${CATFOOD_BUILD_TOOLS:-1}" != 0 ]; then
    CATFOOD_ROOT=$workspace CATFOOD_JOBS=${CATFOOD_JOBS:-2} \
        sh "$root/build-tools.sh"

    # Expose outputs produced by the build without another manifest fetch.
    if [ -x "$workspace/bin/grease" ] && \
       "$workspace/bin/grease" -c 'echo' >/dev/null 2>&1; then
        grease_runner=$workspace/bin/grease
    elif [ -x "$workspace/bin/ysh" ] && \
         "$workspace/bin/ysh" -c 'echo' >/dev/null 2>&1; then
        grease_runner=$workspace/bin/ysh
    else
        printf '%s\n' 'cat food cannot refresh links without Grease/YSH' >&2
        exit 1
    fi
    CATFOOD_ROOT=$workspace CATFOOD_LINKS_ONLY=1 \
        "$grease_runner" "$root/update-tools.ysh" \
            "$workspace" "${CATFOOD_DEPTH:-12}" "$root/tools.tsv" 1
fi

CATFOOD_ROOT=$workspace CATFOOD_PREFIX=$prefix \
    sh "$root/activate.sh"

if [ "${CATFOOD_BUILD_TOOLS:-1}" != 0 ]; then
    PATH=$prefix/bin:$workspace/bin:$PATH \
    CATFOOD_ROOT=$workspace CATFOOD_PREFIX=$prefix \
        sh "$root/doctor.sh"
else
    printf '%s\n' 'cat food source feed is current; core builds were skipped'
fi
