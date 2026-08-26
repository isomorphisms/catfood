#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
checker=$root/check-releases.sh
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

remote=$temporary/one.git
source_checkout=$temporary/source
workspace=$temporary/workspace
fake_bin=$temporary/bin
manifest=$temporary/tools.tsv
projects=$temporary/release-projects.txt

git init -q --bare "$remote"
git init -q -b main "$source_checkout"
git -C "$source_checkout" config user.name 'Cat Food test'
git -C "$source_checkout" config user.email catfood@example.invalid
printf '%s\n' one > "$source_checkout/value"
git -C "$source_checkout" add value
git -C "$source_checkout" commit -qm one
git -C "$source_checkout" tag v1
git -C "$source_checkout" remote add origin "$remote"
git -C "$source_checkout" push -q origin main --tags

mkdir -p "$workspace" "$fake_bin"
git clone -q --branch main "$remote" "$workspace/one"
printf 'one %s main none\n' "$remote" > "$manifest"
printf '%s\n' one > "$projects"

cat > "$fake_bin/curl" <<'EOF'
#!/bin/sh
output=
while [ "$#" -gt 0 ]; do
    case $1 in
        -o)
            output=$2
            shift 2
            ;;
        -w)
            shift 2
            ;;
        -H)
            shift 2
            ;;
        -*) shift ;;
        *) shift ;;
    esac
done
case ${FAKE_HTTP_STATUS:-200} in
    200) printf '{"tag_name":"%s"}\n' "${FAKE_RELEASE_TAG:-v1}" > "$output" ;;
    *) printf '%s\n' '{"message":"fixture"}' > "$output" ;;
esac
printf '%s' "${FAKE_HTTP_STATUS:-200}"
EOF
chmod +x "$fake_bin/curl"

run_check() {
    PATH="$fake_bin:$PATH" \
    CATFOOD_ROOT="$workspace" \
    CATFOOD_MANIFEST="$manifest" \
    CATFOOD_RELEASE_PROJECTS="$projects" \
    CATFOOD_BUILD_ROOT="$temporary/build" \
        sh "$checker"
}

run_check >/dev/null
grep -F 'one'"$(printf '\t')" "${temporary}/build/receipts/release-status.tsv" |
    grep -F "$(printf '\t')released-current" >/dev/null

printf '%s\n' two > "$source_checkout/value"
git -C "$source_checkout" commit -qam two
git -C "$source_checkout" push -q origin main
if run_check >/dev/null 2>&1; then
    printf '%s\n' 'stale checkout unexpectedly passed' >&2
    exit 1
fi

git -C "$workspace/one" pull -q --ff-only
if run_check >/dev/null 2>&1; then
    printf '%s\n' 'release behind branch head unexpectedly passed' >&2
    exit 1
fi

FAKE_HTTP_STATUS=404 run_check >/dev/null
grep -F "$(printf '\t')unreleased" "${temporary}/build/receipts/release-status.tsv" >/dev/null

if FAKE_HTTP_STATUS=500 run_check >/dev/null 2>&1; then
    printf '%s\n' 'failed release query unexpectedly passed' >&2
    exit 1
fi

printf '%s\n' 'release freshness fixtures passed'
