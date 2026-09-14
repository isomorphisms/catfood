#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
workspace=${CATFOOD_ROOT:-"$HOME/opt"}
client=$root/gopeed.ysh
bin=$workspace/bin
marker="# Cat Food's small command-line client for the local Gopeed REST service."

command -v pkg >/dev/null 2>&1 || {
    printf '%s\n' 'Cat Food Android local clients need the Termux pkg command' >&2
    exit 127
}

[ -f "$client" ] || {
    printf 'Cat Food Gopeed client is missing: %s\n' "$client" >&2
    exit 3
}

mkdir -p "$bin"
pkg install -y curl jq

if [ ! -x "$bin/ysh" ] && ! command -v ysh >/dev/null 2>&1; then
    printf '%s\n' 'Cat Food Gopeed client needs YSH from the Android runtime package feed' >&2
    exit 3
fi

safe_gopeed_destination() {
    destination=$1
    if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
        return 0
    fi
    if [ -f "$destination" ] && grep -F "$marker" "$destination" >/dev/null 2>&1; then
        return 0
    fi
    printf '%s exists and is not the Cat Food Gopeed client; leaving it alone\n' "$destination" >&2
    exit 4
}

safe_alias_destination() {
    destination=$1
    if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
        return 0
    fi
    if [ -L "$destination" ]; then
        existing=$(readlink "$destination" 2>/dev/null || printf '%s' '')
        case $existing in
            gopeed|"$bin/gopeed") return 0 ;;
        esac
    fi
    printf '%s exists and is not a Cat Food Gopeed alias; leaving it alone\n' "$destination" >&2
    exit 4
}

destination=$bin/gopeed
safe_gopeed_destination "$destination"
temporary=$destination.tmp.$$
rm -f "$temporary"
cp "$client" "$temporary"
chmod 0755 "$temporary"
mv "$temporary" "$destination"

for alias in gdl go_down_load; do
    link=$bin/$alias
    safe_alias_destination "$link"
    rm -f "$link"
    ln -s gopeed "$link"
done

printf 'Cat Food Android local Gopeed client installed under %s\n' "$bin"
printf '%s\n' 'Gopeed Android app/package and physical-device REST acceptance remain separate.'
