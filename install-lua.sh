#!/bin/sh
set -eu

workspace=${CATFOOD_ROOT:-${HOME:?}/opt}
target=${CATFOOD_TARGET:-auto}
bin=$workspace/bin
receipts=$workspace/receipts

mkdir -p "$bin" "$receipts"

resolve_command() {
    requested=$1
    shift
    if [ -n "$requested" ]; then
        command -v "$requested" 2>/dev/null || return 1
        return 0
    fi
    for candidate do
        if command -v "$candidate" >/dev/null 2>&1; then
            command -v "$candidate"
            return 0
        fi
    done
    return 1
}

termux_runtime=0
case $target in
    phone|tablet|termux) termux_runtime=1 ;;
    cloud|container|hetzner|auto) ;;
    *)
        printf 'Cat Food Lua installer does not know target: %s\n' "$target" >&2
        exit 2
        ;;
esac

if [ "$termux_runtime" -eq 1 ] &&
   [ -z "${CATFOOD_LUA_COMMAND:-}" ] &&
   [ -z "${CATFOOD_LUAC_COMMAND:-}" ]; then
    if ! command -v lua5.5 >/dev/null 2>&1 ||
       ! command -v luac5.5 >/dev/null 2>&1; then
        command -v pkg >/dev/null 2>&1 || {
            printf '%s\n' 'Cat Food Lua needs the Termux pkg command to install lua55' >&2
            exit 127
        }
        pkg install -y lua55
    fi
fi

if [ "$termux_runtime" -eq 1 ]; then
    lua_command=$(resolve_command "${CATFOOD_LUA_COMMAND:-}" lua5.5 lua) || {
        printf '%s\n' 'Cat Food Lua could not find the Termux Lua interpreter after installing lua55' >&2
        exit 127
    }
    luac_command=$(resolve_command "${CATFOOD_LUAC_COMMAND:-}" luac5.5 luac) || {
        printf '%s\n' 'Cat Food Lua could not find the Termux Lua compiler after installing lua55' >&2
        exit 127
    }
    acquisition=termux-lua55
else
    lua_command=$(resolve_command "${CATFOOD_LUA_COMMAND:-}" lua5.5 lua5.4 lua) || {
        printf '%s\n' 'Cat Food Lua needs a host Lua interpreter (provision installs lua5.4 on Debian/Ubuntu)' >&2
        exit 127
    }
    luac_command=$(resolve_command "${CATFOOD_LUAC_COMMAND:-}" luac5.5 luac5.4 luac) || {
        printf '%s\n' 'Cat Food Lua needs a host luac compiler (provision installs lua5.4 on Debian/Ubuntu)' >&2
        exit 127
    }
    acquisition=host-package
fi

probe=$("$lua_command" -e 'local t={6,7}; local f=function(x,y) return x*y end; io.write("catfood-lua=" .. f(t[1], t[2]))')
[ "$probe" = catfood-lua=42 ] || {
    printf 'Cat Food Lua semantic smoke returned: %s\n' "$probe" >&2
    exit 3
}

smoke=$workspace/.catfood-lua-smoke.$$.lua
trap 'rm -f "$smoke"' EXIT HUP INT TERM
printf '%s\n' 'local answer = 6 * 7; assert(answer == 42)' > "$smoke"
"$luac_command" -p "$smoke"
rm -f "$smoke"
trap - EXIT HUP INT TERM

check_link_destination() {
    destination=$1
    if [ -e "$destination" ] && [ ! -L "$destination" ]; then
        printf '%s exists and is not a Cat Food symlink; leaving it alone\n' "$destination" >&2
        exit 4
    fi
}

check_link_destination "$bin/lua"
check_link_destination "$bin/luac"
rm -f "$bin/lua" "$bin/luac"
ln -s "$lua_command" "$bin/lua"
ln -s "$luac_command" "$bin/luac"

version=$("$lua_command" -v 2>&1 | sed -n '1p')
receipt=$receipts/lua.tsv
{
    printf 'schema\tcatfood-lua-v1\n'
    printf 'target\t%s\n' "$target"
    printf 'acquisition\t%s\n' "$acquisition"
    printf 'interpreter\t%s\n' "$version"
    printf 'lua_path\t%s\n' "$lua_command"
    printf 'luac_path\t%s\n' "$luac_command"
    printf 'semantic_result\tPASS\n'
    printf 'compiler_parse_result\tPASS\n'
} > "$receipt.tmp.$$"
mv "$receipt.tmp.$$" "$receipt"

printf 'Cat Food Lua ready: %s\n' "$version"
printf 'commands: %s %s\n' "$bin/lua" "$bin/luac"
