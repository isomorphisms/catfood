#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$root/ci/repositories.sh"
stage_one=${CATFOOD_TEST_STAGE_ONE:-sh}
work=$(mktemp -d)
cleanup() {
    status=$?
    if [ "$status" -ne 0 ]; then
        for log in "$work"/*.log; do
            if [ -f "$log" ]; then
                printf '\n%s\n' "$log" >&2
                cat "$log" >&2
            fi
        done
    fi
    rm -rf "$work"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

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
printf '%s\n' "$CATFOOD_TEST_GIT" > "$work/bin/real-git-path"
printf '%s\n' "$CATFOOD_TEST_SEED" > "$work/bin/seed-path"
cat > "$work/bin/git" <<'EOF'
#!/bin/sh
CATFOOD_TEST_GIT=$(cat "${0%/*}/real-git-path")
CATFOOD_TEST_SEED=$(cat "${0%/*}/seed-path")
if [ "${1:-}" = -C ] && [ "${3:-}" = fetch ]; then
    exec "$CATFOOD_TEST_GIT" \
        -c "url.file://$CATFOOD_TEST_SEED.insteadOf=https://github.com/isomorphisms/ib.git" \
        -c "url.file://$CATFOOD_TEST_SEED.insteadOf=https://github.com/dilapidated-shed/ib.git" \
        -c "url.file://$CATFOOD_TEST_SEED.insteadOf=https://github.com/isomorphisms/grease.git" \
        "$@"
fi
if [ "${1:-}" = -C ] && [ "${3:-}" = submodule ]; then
    printf '%s\n' "${4:-}" >> "${0%/*}/submodule-calls"
    if [ "${4:-}" = status ] && [ -f "${0%/*}/fail-submodule-status" ]; then
        exit 9
    fi
    exec "$CATFOOD_TEST_GIT" -c protocol.file.allow=always "$@"
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
"$stage_one" "$root/update-tools.ysh" "$workspace" 1 "$CATFOOD_MANIFEST" 0 > "$work/feed.log" 2>&1
test "$(git -C "$workspace/ib" rev-parse HEAD)" = "$expected"
test "$(git -C "$workspace/ib" remote get-url origin)" = https://github.com/isomorphisms/ib.git

for undeclared_policy in skip recursive; do
    printf 'ib\thttps://github.com/dilapidated-shed/ib.git\tmain\t%s\n' "$undeclared_policy" > "$CATFOOD_MANIFEST"
    if "$stage_one" "$root/update-tools.ysh" "$workspace" 1 "$CATFOOD_MANIFEST" 0 > "$work/undeclared-$undeclared_policy-feed.log" 2>&1; then
        echo 'reference policy without declarations was accepted' >&2
        exit 1
    fi
    grep -F "marked $undeclared_policy without declared submodules" "$work/undeclared-$undeclared_policy-feed.log" >/dev/null
    if sh "$root/doctor.sh" > "$work/undeclared-$undeclared_policy-doctor.log" 2>&1; then :; fi
    grep -F "marked $undeclared_policy without declared submodules" "$work/undeclared-$undeclared_policy-doctor.log" >/dev/null
done
printf 'ib\thttps://github.com/dilapidated-shed/ib.git\tmain\tnone\n' > "$CATFOOD_MANIFEST"

git -C "$workspace/ib" remote set-url origin https://github.com/dilapidated-shed/ib.git
sh "$root/catfood" where ib | grep -F "$workspace/ib" >/dev/null
if [ "$stage_one" != sh ]; then
    export CATFOOD_YSH=$stage_one
fi
CATFOOD_DEPTH=1 sh "$root/bootstrap.sh" > "$work/bootstrap.log" 2>&1
test "$(git -C "$workspace/grease" rev-parse HEAD)" = "$expected"
test "$(git -C "$workspace/grease" remote get-url origin)" = https://github.com/isomorphisms/grease.git

git -C "$workspace/ib" remote set-url origin https://github.com/unrelated/ib.git
if sh "$root/catfood" where ib > "$work/unrelated.out" 2>&1; then
    echo 'lookup accepted an unrelated origin' >&2
    exit 1
fi
if "$stage_one" "$root/update-tools.ysh" "$workspace" 1 "$CATFOOD_MANIFEST" 0 > "$work/unrelated-feed.log" 2>&1; then
    echo 'feed accepted an unrelated origin' >&2
    exit 1
fi
grep -F 'leaving it alone' "$work/unrelated-feed.log" >/dev/null
test "$(git -C "$workspace/ib" rev-parse HEAD)" = "$expected"

# Existing source feeds and the doctor share the three-state inventory policy.
# Real gitlinks distinguish declared references from initialized checkouts.
git -C "$workspace/ib" remote set-url origin https://github.com/dilapidated-shed/ib.git
reference=$work/reference
git init -q -b main "$reference"
git -C "$reference" -c user.name=Fixture -c user.email=fixture@example.invalid commit -q --allow-empty -m reference
reference_commit=$(git -C "$reference" rev-parse HEAD)
git -C "$CATFOOD_TEST_SEED" config -f .gitmodules submodule.reference.path reference
git -C "$CATFOOD_TEST_SEED" config -f .gitmodules submodule.reference.url "file://$reference"
git -C "$CATFOOD_TEST_SEED" add .gitmodules
git -C "$CATFOOD_TEST_SEED" update-index --add --cacheinfo "160000,$reference_commit,reference"
git -C "$CATFOOD_TEST_SEED" -c user.name=Fixture -c user.email=fixture@example.invalid commit -q -m 'declare reference'

rm -f "$work/bin/submodule-calls"
printf 'ib\thttps://github.com/dilapidated-shed/ib.git\tmain\tskip\n' > "$CATFOOD_MANIFEST"
"$stage_one" "$root/update-tools.ysh" "$workspace" 1 "$CATFOOD_MANIFEST" 0 > "$work/skip-feed.log" 2>&1
grep -F 'reference submodules intentionally skipped' "$work/skip-feed.log" >/dev/null
test ! -e "$workspace/ib/reference/.git"
if [ -f "$work/bin/submodule-calls" ] && grep -E '^(sync|update)$' "$work/bin/submodule-calls" >/dev/null; then
    echo 'skip policy initialized a reference' >&2
    exit 1
fi
if sh "$root/doctor.sh" > "$work/skip-doctor.log" 2>&1; then :; fi
grep -F 'reference submodules intentionally skipped' "$work/skip-doctor.log" >/dev/null
if [ -f "$work/bin/submodule-calls" ] && grep -E '^(sync|update)$' "$work/bin/submodule-calls" >/dev/null; then
    echo 'skip policy doctor initialized a reference' >&2
    exit 1
fi

printf 'ib\thttps://github.com/dilapidated-shed/ib.git\tmain\tnone\n' > "$CATFOOD_MANIFEST"
if "$stage_one" "$root/update-tools.ysh" "$workspace" 1 "$CATFOOD_MANIFEST" 0 > "$work/none-feed.log" 2>&1; then
    echo 'none policy accepted declared references' >&2
    exit 1
fi
grep -F 'declared submodules require recursive or skip policy' "$work/none-feed.log" >/dev/null
if sh "$root/doctor.sh" > "$work/none-doctor.log" 2>&1; then :; fi
grep -F 'has untracked submodule policy' "$work/none-doctor.log" >/dev/null

printf 'ib\thttps://github.com/dilapidated-shed/ib.git\tmain\trecursive\n' > "$CATFOOD_MANIFEST"
if sh "$root/doctor.sh" > "$work/uninitialized-doctor.log" 2>&1; then :; fi
grep -F 'submodules are not at recorded commits' "$work/uninitialized-doctor.log" >/dev/null
"$stage_one" "$root/update-tools.ysh" "$workspace" 1 "$CATFOOD_MANIFEST" 0 > "$work/recursive-feed.log" 2>&1
test -f "$workspace/ib/reference/.git"
test "$(git -C "$workspace/ib/reference" rev-parse HEAD)" = "$reference_commit"
if sh "$root/doctor.sh" > "$work/recursive-doctor.log" 2>&1; then :; fi
if grep -E 'unable to verify submodule status|submodules are not at recorded commits' "$work/recursive-doctor.log" >/dev/null; then
    echo 'initialized exact reference was rejected' >&2
    exit 1
fi

touch "$work/bin/fail-submodule-status"
if sh "$root/doctor.sh" > "$work/status-failure-doctor.log" 2>&1; then :; fi
grep -F 'unable to verify submodule status' "$work/status-failure-doctor.log" >/dev/null
if "$stage_one" "$root/update-tools.ysh" "$workspace" 1 "$CATFOOD_MANIFEST" 0 > "$work/status-failure-feed.log" 2>&1; then
    echo 'failed submodule status was accepted' >&2
    exit 1
fi
grep -F 'unable to verify submodule status' "$work/status-failure-feed.log" >/dev/null
rm "$work/bin/fail-submodule-status"

git -C "$workspace/ib" remote set-url origin https://github.com/unrelated/ib.git
if sh "$root/doctor.sh" > "$work/origin-doctor.log" 2>&1; then :; fi
grep -F 'origin does not match inventory' "$work/origin-doctor.log" >/dev/null

printf 'ib\thttps://github.com/dilapidated-shed/ib.git\tmain\tinvalid\n' > "$CATFOOD_MANIFEST"
if "$stage_one" "$root/update-tools.ysh" "$work/must-not-exist" 1 "$CATFOOD_MANIFEST" 0 > "$work/invalid-feed.log" 2>&1; then
    echo 'invalid manifest policy was accepted' >&2
    exit 1
fi
grep -F 'submodules must be none, recursive, or skip' "$work/invalid-feed.log" >/dev/null
test ! -e "$work/must-not-exist"

cat "$catfood_repository_aliases" "$catfood_repository_aliases" > "$work/duplicates.tsv"
catfood_repository_aliases=$work/duplicates.tsv
if validate_repository_aliases > "$work/duplicates.log" 2>&1; then
    echo 'duplicate former repository was accepted' >&2
    exit 1
fi
grep -F 'duplicate former repository' "$work/duplicates.log" >/dev/null
printf '%s\n' 'PASS: repository identities and none/recursive/skip submodule policies'
