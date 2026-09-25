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

binary_assets=$temporary/runtime-binary-assets
mkdir -p "$binary_assets/miller-9.8.7-linux-amd64"
cat > "$binary_assets/jq" <<'EOF_JQ'
#!/bin/sh
[ "${1:-}" = --version ] && { printf '%s\n' 'jq-9.8.7'; exit 0; }
exit 2
EOF_JQ
cat > "$binary_assets/miller-9.8.7-linux-amd64/mlr" <<'EOF_MLR'
#!/bin/sh
[ "${1:-}" = --version ] && { printf '%s\n' 'mlr 9.8.7'; exit 0; }
exit 2
EOF_MLR
chmod 0755 "$binary_assets/jq" "$binary_assets/miller-9.8.7-linux-amd64/mlr"
tar -czf "$binary_assets/miller.tar.gz" -C "$binary_assets" miller-9.8.7-linux-amd64
jq_sha=$(sha256sum "$binary_assets/jq" | awk '{print $1}')
mlr_sha=$(sha256sum "$binary_assets/miller.tar.gz" | awk '{print $1}')
binary_manifest=$temporary/runtime-binaries.tsv
{
    printf '# command\tsource\tversion\tplatform\tmode\turl\tsha256\tentrypoint\tprobe_arg\tprobe_contains\n'
    printf 'jq\tfixture/jq\t9.8.7\tlinux-x86_64\tfile\tfile://%s\t%s\t-\t--version\t9.8.7\n' "$binary_assets/jq" "$jq_sha"
    printf 'mlr\tfixture/miller\t9.8.7\tlinux-x86_64\ttar.gz\tfile://%s\t%s\tmiller-9.8.7-linux-amd64/mlr\t--version\t9.8.7\n' "$binary_assets/miller.tar.gz" "$mlr_sha"
} > "$binary_manifest"
export CATFOOD_BINARY_MANIFEST=$binary_manifest
export CATFOOD_BINARY_PLATFORM=linux-x86_64

termux_home=$temporary/termux-home
mkdir -p "$termux_home"
HOME=$termux_home \
PREFIX=/data/data/com.termux/files/usr \
TERMUX_VERSION=0.118.3 \
PATH=$fake_bin:$PATH \
CATFOOD_TEST_LOG=$log \
CATFOOD_TARGET=termux \
CATFOOD_MANIFEST=$manifest \
CATFOOD_DEPTH=1 \
CATFOOD_NO_PROFILE=1 \
    sh "$root/catfood" >/dev/null

test -d "$termux_home/opt/grease/.git"
test -d "$termux_home/opt/catfood-fixture/.git"
tab=$(printf '\t')
grep -F "pkg${tab}install -y bash ca-certificates coreutils curl gawk git grep libiconv sed tar" "$log" >/dev/null
test "$("$termux_home/opt/bin/jq" --version)" = "jq-9.8.7"
test "$("$termux_home/opt/bin/mlr" --version)" = "mlr 9.8.7"
if grep -F 'forbidden' "$log" >/dev/null; then
    printf '%s\n' 'Termux entrypoint attempted a root/cloud package command' >&2
    exit 1
fi

git -C "$termux_home/opt/grease" remote set-url origin https://github.com/isomorphisms/grease
git -C "$termux_home/opt/catfood-fixture" remote set-url origin https://github.com/isomorphisms/catfood
HOME=$termux_home \
PREFIX=/data/data/com.termux/files/usr \
TERMUX_VERSION=0.118.3 \
PATH=$fake_bin:$PATH \
CATFOOD_TEST_LOG=$log \
CATFOOD_TARGET=termux \
CATFOOD_MANIFEST=$manifest \
CATFOOD_DEPTH=1 \
CATFOOD_NO_PACKAGES=1 \
CATFOOD_NO_PROFILE=1 \
    sh "$root/catfood" >/dev/null

cloud_root=$termux_home/opt
mkdir -p "$cloud_root/bin"
cat > "$cloud_root/bin/ysh" <<'EOF'
#!/bin/sh
exec sh "$@"
EOF
chmod 0755 "$cloud_root/bin/ysh"

HOME=$termux_home \
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

help_index=$temporary/help-index
sh "$root/catfood" help > "$help_index"
grep -Fx '  grease' "$help_index" >/dev/null
awk '$1 !~ /^#/ && NF >= 4 { print $1 }' "$root/tools.tsv" | while IFS= read -r tool; do
    grep -Fx "  $tool" "$help_index" >/dev/null || {
        printf 'missing Cat Food help topic for %s\n' "$tool" >&2
        exit 1
    }
done
sh "$root/catfood" help gopeed | grep -F '# Gopeed REST API' >/dev/null
sh "$root/catfood" help ib | grep -F 'Repository: https://github.com/isomorphisms/ib.git' >/dev/null
sh "$root/catfood" help grease | grep -F 'stage-one shell bootstrap' >/dev/null

checkouts=$temporary/checkouts.tsv
canonical=$termux_home/opt/catfood-fixture

located=$(
    HOME=$termux_home \
    CATFOOD_ROOT=$termux_home/opt \
    CATFOOD_MANIFEST=$manifest \
    CATFOOD_CHECKOUTS=$checkouts \
        sh "$root/catfood" where catfood-fixture
)
test "$located" = "catfood-fixture${tab}workbench${tab}$canonical"

make_checkout() {
    checkout_path=$1
    checkout_origin=$2
    mkdir -p "$checkout_path"
    git -C "$checkout_path" init -q
    git -C "$checkout_path" remote add origin "$checkout_origin"
}

acceptance=$temporary/ib-phone-smoke
cache_checkout=$temporary/cache/catfood-fixture
stale=$temporary/stale/catfood-fixture
mismatched=$temporary/mismatched/catfood-fixture
rejected=$temporary/rejected/catfood-fixture

make_checkout "$acceptance" https://github.com/isomorphisms/catfood
make_checkout "$cache_checkout" https://github.com/isomorphisms/catfood.git
make_checkout "$stale" https://github.com/isomorphisms/catfood.git
make_checkout "$mismatched" https://github.com/isomorphisms/catfood.git
make_checkout "$rejected" https://github.com/isomorphisms/not-catfood.git

register_checkout() {
    role=$1
    checkout_path=$2
    HOME=$termux_home \
    CATFOOD_ROOT=$termux_home/opt \
    CATFOOD_MANIFEST=$manifest \
    CATFOOD_CHECKOUTS=$checkouts \
        sh "$root/catfood" register catfood-fixture "$role" "$checkout_path" >/dev/null
}

register_checkout acceptance "$acceptance"
register_checkout cache "$cache_checkout"
register_checkout test "$stale"
register_checkout other "$mismatched"

rm -rf "$stale"
git -C "$mismatched" remote set-url origin https://github.com/isomorphisms/not-catfood.git

if HOME=$termux_home \
    CATFOOD_ROOT=$termux_home/opt \
    CATFOOD_MANIFEST=$manifest \
    CATFOOD_CHECKOUTS=$checkouts \
    sh "$root/catfood" register catfood-fixture other "$rejected" >/dev/null 2>&1; then
    printf '%s\n' 'checkout registration accepted a mismatched Git origin' >&2
    exit 1
fi

locations=$temporary/locations.tsv
HOME=$termux_home \
CATFOOD_ROOT=$termux_home/opt \
CATFOOD_MANIFEST=$manifest \
CATFOOD_CHECKOUTS=$checkouts \
    sh "$root/catfood" where catfood-fixture > "$locations"

grep -Fx "catfood-fixture${tab}acceptance${tab}$acceptance" "$locations" >/dev/null
grep -Fx "catfood-fixture${tab}cache${tab}$cache_checkout" "$locations" >/dev/null
grep -Fx "catfood-fixture${tab}workbench${tab}$canonical" "$locations" >/dev/null
test "$(wc -l < "$locations" | tr -d ' ')" -eq 3
if grep -F "$stale" "$locations" >/dev/null || grep -F "$mismatched" "$locations" >/dev/null; then
    printf '%s\n' 'checkout lookup reported stale or mismatched registered state' >&2
    exit 1
fi

HOME=$termux_home \
CATFOOD_ROOT=$termux_home/opt \
CATFOOD_MANIFEST=$manifest \
CATFOOD_CHECKOUTS=$checkouts \
    sh "$root/catfood" where > "$locations"
grep -Fx "catfood-fixture${tab}acceptance${tab}$acceptance" "$locations" >/dev/null
grep -Fx "catfood-fixture${tab}cache${tab}$cache_checkout" "$locations" >/dev/null
grep -Fx "catfood-fixture${tab}workbench${tab}$canonical" "$locations" >/dev/null

if HOME=$termux_home \
    CATFOOD_ROOT=$termux_home/opt \
    CATFOOD_MANIFEST=$manifest \
    CATFOOD_CHECKOUTS=$checkouts \
    sh "$root/catfood" where missing-tool >/dev/null 2>&1; then
    printf '%s\n' 'checkout lookup accepted an unknown tool' >&2
    exit 1
fi

rm -rf "$canonical" "$acceptance" "$cache_checkout"
if HOME=$termux_home \
    CATFOOD_ROOT=$termux_home/opt \
    CATFOOD_MANIFEST=$manifest \
    CATFOOD_CHECKOUTS=$checkouts \
    sh "$root/catfood" where catfood-fixture >/dev/null 2>&1; then
    printf '%s\n' 'checkout lookup reported only stale or mismatched locations as current' >&2
    exit 1
fi

apk_phone=$temporary/apks-phone
apk_tablet=$temporary/apks-tablet
sh "$root/catfood" apks phone "$apk_phone" >/dev/null
sh "$root/catfood" apks tablet "$apk_tablet" >/dev/null

general_count=$(awk 'NR > 1 { n++ } END { print n + 0 }' "$root/android/apks/general-dex/manifest.tsv")
miro_count=$(awk 'NR > 1 { n++ } END { print n + 0 }' "$root/android/apks/miro-a1/manifest.tsv")
tablet_count=$(awk 'NR > 1 { n++ } END { print n + 0 }' "$root/android/apks/tab-p10-row/manifest.tsv")

set -- "$apk_phone"/*.apk
test -e "$1"
test "$#" -eq "$((general_count + miro_count))"

set -- "$apk_tablet"/*.apk
test -e "$1"
test "$#" -eq "$((general_count + tablet_count))"

awk -F '\t' 'NR > 1 && $8 != "-" { exit 1 }' "$root/android/apks/general-dex/manifest.tsv"
awk -F '\t' 'NR > 1 && $8 == "-" { exit 1 }' "$root/android/apks/miro-a1/manifest.tsv"
awk -F '\t' 'NR > 1 && $8 == "-" { exit 1 }' "$root/android/apks/tab-p10-row/manifest.tsv"
grep -F '7b9657ea55dfbff437c30ca92c31b06d6aeb6d04cafbd185b6e74cb3957f5f19' "$root/android/apks/general-dex/manifest.tsv" >/dev/null

printf '%s\n' 'cat food cloud, generic Termux, APK staging, inventory help, and verified checkout location entrypoints pass'
