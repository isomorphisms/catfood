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

install_native_shell_link() {
    name=$1
    target=$prefix/bin/$name
    link=$bindir/$name

    [ -x "$target" ] || return 0
    "$target" -c ':' >/dev/null 2>&1 || {
        printf '%s exists but is not runnable\n' "$target" >&2
        return 1
    }

    if [ -e "$link" ] || [ -L "$link" ]; then
        if [ -L "$link" ]; then
            rm -f "$link"
        else
            printf '%s exists and is not a symlink; leaving it alone\n' "$link" >&2
            return 1
        fi
    fi

    ln -s "$target" "$link"
}

write_wrapper() {
    name=$1
    target=$2
    wrapper=$bindir/$name
    tmp=$bindir/.$name.tmp

    if [ -e "$wrapper" ] || [ -L "$wrapper" ]; then
        if [ -f "$wrapper" ] && grep -F '# catfood management wrapper' "$wrapper" >/dev/null 2>&1; then
            :
        else
            printf '%s exists and is not a Cat Food management wrapper; leaving it alone\n' "$wrapper" >&2
            return 1
        fi
    fi

    {
        printf '%s\n' '#!/bin/sh'
        printf '%s\n' '# catfood management wrapper'
        printf 'exec "%s" "$@"\n' "$target"
    } > "$tmp"
    chmod 0755 "$tmp"
    mv "$tmp" "$wrapper"
}

# update-tools.ysh owns project/tool aliases. Provisioning deliberately replaces
# only its osh/ysh symlinks with the verified native Oils installation.
install_native_shell_link osh
install_native_shell_link ysh
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
