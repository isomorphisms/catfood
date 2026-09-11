#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

fake_bin=$temporary/bin
home=$temporary/home
workspace=$temporary/workspace
manifest=$temporary/phone-tools.tsv
mkdir -p "$fake_bin" "$home" "$workspace"

cat > "$fake_bin/getprop" <<'EOF'
#!/bin/sh
case ${1:-} in
    ro.product.cpu.abi) printf '%s\n' armeabi-v7a ;;
    ro.build.fingerprint) printf '%s\n' catfood/test/device ;;
    ro.kernel.qemu|ro.boot.qemu) printf '%s\n' 0 ;;
    *) printf '\n' ;;
esac
EOF
chmod 0755 "$fake_bin/getprop"

cat > "$manifest" <<'EOF'
# name	mode	command	abi	source	ref	url	sha256	entrypoint
grep	system	grep	any	termux	system	-	-	-
grease	archive	grease	armeabi-v7a	isomorphisms/grease	test	PENDING	PENDING	bin/grease
EOF

# Deliberately request YSH installation and normal package handling. The phone
# target must still bypass both source/package paths and hand directly to the
# binary artifact profile.
output=$(
    HOME="$home" \
    PATH="$fake_bin:$PATH" \
    CATFOOD_TARGET=phone \
    CATFOOD_ROOT="$workspace" \
    CATFOOD_PHONE_MANIFEST="$manifest" \
    CATFOOD_INSTALL_YSH=1 \
        sh "$root/provision.sh"
)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -F 'grease     PENDING prebuilt artifact' >/dev/null
printf '%s\n' "$output" | grep -F 'abi         armeabi-v7a' >/dev/null
printf '%s\n' "$output" | grep -F 'cat food phone binaries are current' >/dev/null

if find "$workspace" -type d -name .git -print -quit | grep . >/dev/null; then
    printf '%s\n' 'phone profile created a source checkout' >&2
    exit 1
fi

if grep -En 'git (clone|fetch|checkout|pull)|(^|[[:space:]])(make|clang|cmake|javac|gradle)([[:space:]]|$)' \
    "$root/phone/build.sh" "$root/phone/doctor.sh" >/dev/null; then
    printf '%s\n' 'phone profile contains a source/build command' >&2
    exit 1
fi

if grep -En 'pkg[[:space:]]+install|apt-get[[:space:]]+install' \
    "$root/phone/build.sh" "$root/phone/doctor.sh" >/dev/null; then
    printf '%s\n' 'phone profile contains a package-install path' >&2
    exit 1
fi

grep -F '[ "$target" = phone ]' "$root/provision.sh" >/dev/null
grep -F 'sh "$root/phone/build.sh"' "$root/provision.sh" >/dev/null

echo 'phone profile is binary-only'
