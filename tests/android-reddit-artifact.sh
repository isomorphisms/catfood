#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

backend_sha=b7d50d50bc1b11f3c470051a39693cfe5996608c
fixture=$temporary/release
fake_bin=$temporary/bin
tab=$(printf '\t')
mkdir -p "$fixture/phone" "$fixture/tablet" "$fake_bin"

make_bundle() {
    target=$1
    abi=$2
    directory=$fixture/$target
    printf '%s\n' 'dex-fixture' > "$directory/classes.dex"
    printf '%s\n' "jni-fixture-$abi" > "$directory/libreddit_cli.so"
    {
        printf 'target=%s\n' "$target"
        printf 'abi=%s\n' "$abi"
        printf 'backend_sha=%s\n' "$backend_sha"
    } > "$directory/android-receipt.txt"
    tar -C "$directory" -czf "$fixture/reddit-$target.tar.gz" .
}

make_bundle phone armeabi-v7a
make_bundle tablet arm64-v8a
(
    cd "$fixture"
    sha256sum reddit-phone.tar.gz reddit-tablet.tar.gz > SHA256SUMS
)

cat > "$fake_bin/curl" <<'EOF'
#!/bin/sh
set -eu
output=
url=
while [ "$#" -gt 0 ]; do
    case $1 in
        -o)
            shift
            output=$1
            ;;
        http://*|https://*) url=$1 ;;
    esac
    shift
done
[ -n "$output" ] && [ -n "$url" ]
case $url in
    */SHA256SUMS) source=$CATFOOD_TEST_RELEASE/SHA256SUMS ;;
    */reddit-phone.tar.gz) source=$CATFOOD_TEST_RELEASE/reddit-phone.tar.gz ;;
    */reddit-tablet.tar.gz) source=$CATFOOD_TEST_RELEASE/reddit-tablet.tar.gz ;;
    *) exit 22 ;;
esac
cp "$source" "$output"
EOF

cat > "$fake_bin/getprop" <<'EOF'
#!/bin/sh
case ${1:-} in
    ro.product.cpu.abi) printf '%s\n' "$CATFOOD_TEST_ABI" ;;
    *) exit 0 ;;
esac
EOF

cat > "$fake_bin/uname" <<'EOF'
#!/bin/sh
case ${1:-} in
    -m) printf '%s\n' "$CATFOOD_TEST_MACHINE" ;;
    *) exec /usr/bin/uname "$@" ;;
esac
EOF
chmod +x "$fake_bin/curl" "$fake_bin/getprop" "$fake_bin/uname"

check_target() {
    target=$1
    abi=$2
    machine=$3
    workspace=$temporary/workspace-$target
    cache=$temporary/cache-$target
    mkdir -p "$workspace" "$cache"

    PATH="$fake_bin:$PATH" \
    CATFOOD_TEST_RELEASE="$fixture" \
    CATFOOD_TEST_ABI="$abi" \
    CATFOOD_TEST_MACHINE="$machine" \
    CATFOOD_ROOT="$workspace" \
    CATFOOD_CACHE="$cache" \
    CATFOOD_TARGET="$target" \
        sh "$root/android/install-reddit.sh"

    test -L "$workspace/bin/reddit"
    test -x "$workspace/bin/reddit"
    test -f "$workspace/.catfood/$target/reddit/$backend_sha/classes.dex"
    test -f "$workspace/.catfood/$target/reddit/$backend_sha/libreddit_cli.so"
    receipt="$workspace/.catfood/receipts/$target-reddit.tsv"
    test -f "$receipt"
    grep -Fqx "target${tab}$target" "$receipt"
    grep -Fqx "abi${tab}$abi" "$receipt"
    grep -Fqx "backend_sha${tab}$backend_sha" "$receipt"
    grep -Fqx "physical_device_execution${tab}PENDING" "$receipt"
    grep -Fq 'org.isomorphisms.reddit.RedditCli' "$workspace/bin/reddit"
}

check_target phone armeabi-v7a armv7l
check_target tablet arm64-v8a aarch64

printf '%s\n' 'phone and tablet Reddit DEX/JNI bundles install into separate Cat Food targets'
