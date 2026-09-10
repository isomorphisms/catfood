#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

fake_bin=$temporary/bin
log=$temporary/commands.tsv
mkdir -p "$fake_bin"

cat > "$fake_bin/pkg" <<'EOF'
#!/bin/sh
printf 'pkg\t%s\n' "$*" >> "$CATFOOD_TEST_LOG"
EOF

for forbidden in apt-get sudo; do
    cat > "$fake_bin/$forbidden" <<'EOF'
#!/bin/sh
printf 'forbidden\t%s\n' "$0 $*" >> "$CATFOOD_TEST_LOG"
exit 99
EOF
done
chmod 0755 "$fake_bin/pkg" "$fake_bin/apt-get" "$fake_bin/sudo"

manifest=$temporary/tools.tsv
printf '%s\n' \
    'catfood-fixture https://github.com/isomorphisms/catfood.git main none' \
    > "$manifest"

phone_home=$temporary/phone-home
mkdir -p "$phone_home"
HOME=$phone_home \
PREFIX=/data/data/com.termux/files/usr \
TERMUX_VERSION=0.118.3 \
PATH=$fake_bin:$PATH \
CATFOOD_TEST_LOG=$log \
CATFOOD_MANIFEST=$manifest \
CATFOOD_DEPTH=1 \
CATFOOD_NO_PROFILE=1 \
    sh "$root/catfood" >/dev/null

test -d "$phone_home/opt/grease/.git"
test -d "$phone_home/opt/catfood-fixture/.git"
tab=$(printf '\t')
grep -F "pkg${tab}install -y bash ca-certificates coreutils curl gawk git jq" "$log" >/dev/null
if grep -F 'forbidden' "$log" >/dev/null; then
    printf '%s\n' 'Termux entrypoint attempted a root/cloud package command' >&2
    exit 1
fi

cloud_root=$phone_home/opt
mkdir -p "$cloud_root/bin"
cat > "$cloud_root/bin/ysh" <<'EOF'
#!/bin/sh
exec sh "$@"
EOF
chmod 0755 "$cloud_root/bin/ysh"

HOME=$phone_home \
PATH=$fake_bin:$PATH \
CATFOOD_TEST_LOG=$log \
CATFOOD_TARGET=cloud \
CATFOOD_ROOT=$cloud_root \
CATFOOD_MANIFEST=$manifest \
CATFOOD_DEPTH=1 \
CATFOOD_NO_PACKAGES=1 \
CATFOOD_INSTALL_YSH=0 \
CATFOOD_BUILD_TOOLS=0 \
CATFOOD_NO_PROFILE=1 \
    sh "$root/catfood" >/dev/null

test -d "$cloud_root/grease/.git"
test -d "$cloud_root/catfood-fixture/.git"
grep -F 'exec "$bin_dir/ysh"' "$cloud_root/bin/fdroid-deploy" >/dev/null
grep -F 'exec "$bin_dir/ysh"' "$cloud_root/bin/fdroid-check-deployed" >/dev/null
sh "$root/catfood" --help | grep -F 'CATFOOD_TARGET=cloud|termux' >/dev/null

printf '%s\n' 'cat food cloud and Termux entrypoints pass'
