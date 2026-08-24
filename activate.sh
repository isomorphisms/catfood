#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
workspace=${CATFOOD_ROOT:-/opt}
bindir=${CATFOOD_BIN:-$workspace/bin}

if [ -n "${CATFOOD_PREFIX:-}" ]; then
    prefix=$CATFOOD_PREFIX
elif [ "$(id -u)" -eq 0 ]; then
    prefix=/usr/local
else
    prefix=$HOME/.local
fi

mkdir -p "$bindir" "${XDG_CONFIG_HOME:-$HOME/.config}/az"

write_wrapper() {
    name=$1
    target=$2
    tmp=$bindir/.$name.tmp
    {
        printf '%s\n' '#!/bin/sh'
        printf 'exec "%s" "$@"\n' "$target"
    } > "$tmp"
    chmod 0755 "$tmp"
    mv "$tmp" "$bindir/$name"
}

# update-tools.ysh owns the stable project/tool aliases, including az and abe.
# Activation only adds Cat Food's own management commands and the PATH entry.
write_wrapper catfood-update "$root/bootstrap.sh"
write_wrapper catfood-doctor "$root/doctor.sh"

profile=${CATFOOD_PROFILE:-$HOME/.profile}
marker='# catfood workbench path'
if [ "${CATFOOD_NO_PROFILE:-0}" != 1 ]; then
    touch "$profile"
    if ! grep -F "$marker" "$profile" >/dev/null 2>&1; then
        {
            printf '\n%s\n' "$marker"
            printf 'PATH="%s/bin:%s/bin:$PATH"\n' "$prefix" "$workspace"
            printf 'export PATH\n'
        } >> "$profile"
    fi
fi

printf 'cat food commands are in %s\n' "$bindir"
printf '%s\n' 'management: catfood-update catfood-doctor'
