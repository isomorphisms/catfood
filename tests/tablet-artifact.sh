#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

fake_bin=$temporary/bin
workspace=$temporary/workspace
cache=$temporary/cache
mkdir -p "$fake_bin" "$workspace" "$cache"

cat > "$fake_bin/getprop" <<'EOF'
#!/bin/sh
case ${1:-} in
    ro.product.cpu.abi) printf '%s\n' arm64-v8a ;;
    *) exit 0 ;;
esac
EOF
cat > "$fake_bin/uname" <<'EOF'
#!/bin/sh
case ${1:-} in
    -m) printf '%s\n' aarch64 ;;
    *) exec /usr/bin/uname "$@" ;;
esac
EOF
chmod +x "$fake_bin/getprop" "$fake_bin/uname"

PATH="$fake_bin:$PATH" \
CATFOOD_ROOT="$workspace" \
CATFOOD_CACHE="$cache" \
    sh "$root/tablet/install-grease.sh"

test -L "$workspace/bin/grease"
test -L "$workspace/bin/ysh"
test -x "$workspace/bin/grease"
test -x "$workspace/bin/ysh"
test -f "$workspace/.catfood/receipts/tablet-grease.tsv"
grep -Fqx 'abi	arm64-v8a' "$workspace/.catfood/receipts/tablet-grease.tsv"
grep -Fqx 'packaging_sha	9b3dc89048911bd0e23ee992fe00dcb3cd427f63' "$workspace/.catfood/receipts/tablet-grease.tsv"
grep -Fqx 'artifact_sha256	3ddb962ef313e528e525fa03518f494577e921c2201ecb49f7a11f2fbf4e82b2' "$workspace/.catfood/receipts/tablet-grease.tsv"

printf '%s\n' 'tablet pinned Grease artifact installs and verifies'
