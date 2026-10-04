#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
tab=$(printf '\t')

make_fake_runtime() {
    directory=$1
    version=$2
    suffix=$3
    mkdir -p "$directory"

    cat > "$directory/lua$suffix" <<'EOF'
#!/bin/sh
case ${1:-} in
    -v)
        printf '%s\n' 'Lua @VERSION@' >&2
        ;;
    -e)
        printf '%s' 'catfood-lua=42'
        ;;
    *)
        exit 0
        ;;
esac
EOF
    sed "s/@VERSION@/$version/" "$directory/lua$suffix" > "$directory/lua$suffix.tmp"
    mv "$directory/lua$suffix.tmp" "$directory/lua$suffix"
    cat > "$directory/luac$suffix" <<'EOF'
#!/bin/sh
[ "${1:-}" = -p ] || exit 2
[ -f "${2:-}" ] || exit 3
EOF
    chmod 0755 "$directory/lua$suffix" "$directory/luac$suffix"
}

termux_bin=$temporary/termux-bin
make_fake_runtime "$termux_bin" 5.5.1 5.5
termux_root=$temporary/termux-root
PATH="$termux_bin:/usr/bin:/bin" \
CATFOOD_ROOT=$termux_root \
CATFOOD_TARGET=phone \
CATFOOD_LUA_COMMAND=lua5.5 \
CATFOOD_LUAC_COMMAND=luac5.5 \
    sh "$root/install-lua.sh" >/dev/null

test -L "$termux_root/bin/lua"
test -L "$termux_root/bin/luac"
grep -Fx "acquisition${tab}termux-lua55" "$termux_root/receipts/lua.tsv" >/dev/null
grep -Fx "semantic_result${tab}PASS" "$termux_root/receipts/lua.tsv" >/dev/null
grep -Fx "compiler_parse_result${tab}PASS" "$termux_root/receipts/lua.tsv" >/dev/null

package_bin=$temporary/package-bin
package_log=$temporary/package.log
mkdir -p "$package_bin"
cat > "$package_bin/pkg" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$CATFOOD_PACKAGE_LOG"
directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cat > "$directory/lua5.5" <<'EOF_LUA'
#!/bin/sh
case ${1:-} in
    -v) printf '%s\n' 'Lua 5.5.1' >&2 ;;
    -e) printf '%s' 'catfood-lua=42' ;;
    *) exit 0 ;;
esac
EOF_LUA
cat > "$directory/luac5.5" <<'EOF_LUAC'
#!/bin/sh
[ "${1:-}" = -p ] || exit 2
[ -f "${2:-}" ] || exit 3
EOF_LUAC
chmod 0755 "$directory/lua5.5" "$directory/luac5.5"
EOF
chmod 0755 "$package_bin/pkg"

package_root=$temporary/package-root
PATH="$package_bin:/usr/bin:/bin" \
CATFOOD_PACKAGE_LOG=$package_log \
CATFOOD_ROOT=$package_root \
CATFOOD_TARGET=tablet \
    sh "$root/install-lua.sh" >/dev/null

grep -Fx 'install -y lua55' "$package_log" >/dev/null
grep -Fx "acquisition${tab}termux-lua55" "$package_root/receipts/lua.tsv" >/dev/null
test "$("$package_root/bin/lua" -e 'ignored')" = catfood-lua=42

host_bin=$temporary/host-bin
make_fake_runtime "$host_bin" 5.4.9 5.4
host_root=$temporary/host-root
PATH="$host_bin:/usr/bin:/bin" \
CATFOOD_ROOT=$host_root \
CATFOOD_TARGET=cloud \
CATFOOD_LUA_COMMAND=lua5.4 \
CATFOOD_LUAC_COMMAND=luac5.4 \
    sh "$root/install-lua.sh" >/dev/null

grep -Fx "acquisition${tab}host-package" "$host_root/receipts/lua.tsv" >/dev/null
test "$("$host_root/bin/lua" -e 'ignored')" = catfood-lua=42

hostile_root=$temporary/hostile-root
mkdir -p "$hostile_root/bin"
printf '%s\n' 'human file' > "$hostile_root/bin/lua"
if PATH="$host_bin:/usr/bin:/bin" \
    CATFOOD_ROOT=$hostile_root \
    CATFOOD_TARGET=cloud \
    CATFOOD_LUA_COMMAND=lua5.4 \
    CATFOOD_LUAC_COMMAND=luac5.4 \
        sh "$root/install-lua.sh" >/dev/null 2>&1; then
    printf '%s\n' 'Lua installer overwrote a non-Cat-Food destination' >&2
    exit 1
fi
grep -Fx 'human file' "$hostile_root/bin/lua" >/dev/null

printf '%s\n' 'cat food Lua interpreter contracts pass'
