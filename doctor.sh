#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
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

check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        printf '%-22s ok\n' "$1"
    else
        printf '%-22s missing\n' "$1" >&2
        failures=1
    fi
}

for command_name in git curl jq ysh az abe catfood-update catfood-doctor; do
    check_command "$command_name"
done

if command -v ysh >/dev/null 2>&1 && ! ysh -c ':' >/dev/null 2>&1; then
    printf '%-22s not runnable\n' ysh >&2
    failures=1
fi

while read -r name repository branch submodules || [ -n "${name:-}" ]; do
    case ${name:-} in
        ''|'#'*) continue ;;
    esac

    if [ -e "$workspace/$name/.git" ]; then
        printf '%-22s present\n' "$name"
    else
        printf '%-22s missing checkout\n' "$name" >&2
        failures=1
    fi
done < "$manifest"

if command -v az >/dev/null 2>&1; then
    if ! az link B000000000 >/dev/null 2>&1; then
        printf '%-22s public link smoke failed\n' az >&2
        failures=1
    fi
fi

if command -v abe >/dev/null 2>&1; then
    if ! abe link 'https://www.abebooks.com/servlet/BookDetailsPL?bi=1' >/dev/null 2>&1; then
        printf '%-22s public link smoke failed\n' abe >&2
        failures=1
    fi
fi

config_home=${XDG_CONFIG_HOME:-$HOME/.config}
if [ ! -f "$config_home/az/amazon-secret" ]; then
    printf '%s\n' 'amazon Creators credentials: not configured (public az link still works)'
fi
if [ ! -f "$config_home/az/abebooks-impact" ]; then
    printf '%s\n' 'AbeBooks client key: not configured (abe link still works)'
fi

if [ "$failures" -ne 0 ]; then
    printf '%s\n' 'cat food workbench has failures' >&2
    exit 1
fi

printf '%s\n' 'cat food workbench is ready'
