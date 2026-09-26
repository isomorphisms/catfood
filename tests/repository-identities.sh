#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$root/ci/repositories.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

same_repository_url https://github.com/isomorphisms/ib.git https://github.com/dilapidated-shed/ib.git
same_repository_url git@github.com:isomorphisms/ib.git ssh://git@github.com/dilapidated-shed/ib.git
same_repository_url https://github.com/isomorphisms/analytic-continuation.git https://github.com/isomorphismes/holomorphic.git
if same_repository_url https://github.com/unrelated/ib.git https://github.com/dilapidated-shed/ib.git; then
    echo 'unrelated owner was accepted' >&2
    exit 1
fi

export CATFOOD_TEST_GIT CATFOOD_TEST_SEED
CATFOOD_TEST_GIT=$(command -v git)
CATFOOD_TEST_SEED=$work/seed
git init -q -b main "$CATFOOD_TEST_SEED"
git -C "$CATFOOD_TEST_SEED" -c user.name=Fixture -c user.email=fixture@example.invalid commit -q --allow-empty -m initial
workspace=$work/workspace
mkdir -p "$workspace" "$work/bin"
git clone -q "$CATFOOD_TEST_SEED" "$workspace/ib"
git clone -q "$CATFOOD_TEST_SEED" "$workspace/grease"
git -C "$workspace/ib" remote set-url origin https://github.com/isomorphisms/ib.git
git -C "$workspace/grease" remote set-url origin https://github.com/isomorphisms/grease.git

# Redirect fetch transport only. Identity checks still read the actual origins.
cat > "$work/bin/git" <<'EOF'
#!/bin/sh
if [ "${1:-}" = -C ] && [ "${3:-}" = fetch ]; then
    exec "$CATFOOD_TEST_GIT" \
        -c "url.file://$CATFOOD_TEST_SEED.insteadOf=https://github.com/isomorphisms/ib.git" \
        -c "url.file://$CATFOOD_TEST_SEED.insteadOf=https://github.com/dilapidated-shed/ib.git" \
        -c "url.file://$CATFOOD_TEST_SEED.insteadOf=https://github.com/isomorphisms/grease.git" \
        "$@"
fi
exec "$CATFOOD_TEST_GIT" "$@"
EOF
chmod +x "$work/bin/git"
PATH=$work/bin:$PATH
export PATH CATFOOD_ROOT CATFOOD_MANIFEST CATFOOD_CHECKOUTS
CATFOOD_ROOT=$workspace
CATFOOD_MANIFEST=$work/tools.tsv
CATFOOD_CHECKOUTS=$work/checkouts.tsv
printf 'ib\thttps://github.com/dilapidated-shed/ib.git\tmain\tnone\n' > "$CATFOOD_MANIFEST"

sh "$root/catfood" register ib workbench "$workspace/ib" >/dev/null
sh "$root/catfood" where ib | grep -F "$workspace/ib" >/dev/null
git -C "$CATFOOD_TEST_SEED" -c user.name=Fixture -c user.email=fixture@example.invalid commit -q --allow-empty -m update
expected=$(git -C "$CATFOOD_TEST_SEED" rev-parse HEAD)
sh "$root/update-tools.ysh" "$workspace" 1 "$CATFOOD_MANIFEST" 0 > "$work/feed.log" 2>&1
test "$(git -C "$workspace/ib" rev-parse HEAD)" = "$expected"
test "$(git -C "$workspace/ib" remote get-url origin)" = https://github.com/isomorphisms/ib.git

git -C "$workspace/ib" remote set-url origin https://github.com/dilapidated-shed/ib.git
sh "$root/catfood" where ib | grep -F "$workspace/ib" >/dev/null
CATFOOD_DEPTH=1 sh "$root/bootstrap.sh" > "$work/bootstrap.log" 2>&1
test "$(git -C "$workspace/grease" rev-parse HEAD)" = "$expected"
test "$(git -C "$workspace/grease" remote get-url origin)" = https://github.com/isomorphisms/grease.git

git -C "$workspace/ib" remote set-url origin https://github.com/unrelated/ib.git
if sh "$root/catfood" where ib > "$work/unrelated.out" 2>&1; then
    echo 'lookup accepted an unrelated origin' >&2
    exit 1
fi
if sh "$root/update-tools.ysh" "$workspace" 1 "$CATFOOD_MANIFEST" 0 > "$work/unrelated-feed.log" 2>&1; then
    echo 'feed accepted an unrelated origin' >&2
    exit 1
fi
grep -F 'leaving it alone' "$work/unrelated-feed.log" >/dev/null
test "$(git -C "$workspace/ib" rev-parse HEAD)" = "$expected"

cat "$catfood_repository_aliases" "$catfood_repository_aliases" > "$work/duplicates.tsv"
catfood_repository_aliases=$work/duplicates.tsv
if validate_repository_aliases > "$work/duplicates.log" 2>&1; then
    echo 'duplicate former repository was accepted' >&2
    exit 1
fi
grep -F 'duplicate former repository' "$work/duplicates.log" >/dev/null
printf '%s\n' 'PASS: transferred repositories resolve and update without accepting unrelated origins'
