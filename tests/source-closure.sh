#!/bin/sh
# Stage-zero Git acquisition fixtures; no compiler or Grease runtime is used.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/bin" "$work/unrelated" "$work/state"
real_git=$(command -v git)
printf '%s\n' "$real_git" > "$work/bin/real-git"

seed() {
    git init -q -b main "$1"
    git -C "$1" config user.name Fixture
    git -C "$1" config user.email fixture@example.invalid
    printf 'fixture\n' > "$1/source"
    git -C "$1" add source
    git -C "$1" commit -qm initial
}
seed "$work/leaf"
: > "$work/leaf/.gitmodules"
git -C "$work/leaf" add .gitmodules
git -C "$work/leaf" commit -qm empty-leaf-declarations
seed "$work/gcc"
git -C "$work/gcc" -c protocol.file.allow=always submodule add -q "$work/leaf" nested
git -C "$work/gcc" config -f .gitmodules submodule.nested.url https://github.com/example/leaf.git
git -C "$work/gcc" add .gitmodules nested
git -C "$work/gcc" commit -qm nested
gcc_commit=$(git -C "$work/gcc" rev-parse HEAD)
seed "$work/ick"
git -C "$work/ick" -c protocol.file.allow=always submodule add -q "$work/gcc" gcc
git -C "$work/ick" config -f .gitmodules submodule.gcc.url https://github.com/example/gcc.git
mkdir -p "$work/ick/ick"
printf 'gcc_repository=https://github.com/example/gcc.git\ngcc_commit=%s\n' "$gcc_commit" > "$work/ick/ick/SOURCE.lock"
printf 'fixture\n' > "$work/ick/ick/OVERLAY.sha256"
printf 'fixture\n' > "$work/ick/ick/PRUNE"
printf '# fixture materializer; never executed\n' > "$work/ick/ick/materialize.sh"
git -C "$work/ick" add .
git -C "$work/ick" commit -qm locked
commit=$(git -C "$work/ick" rev-parse HEAD)

# Only the transport is substituted. The fixture uses real commits, origins,
# gitlinks, checkouts and recursive Git operations. This is not live GitHub evidence.
printf '%s\n' "$work" > "$work/bin/work"
cat > "$work/bin/git" <<'EOF'
#!/bin/sh
fixture_git=$(cat "${0%/*}/real-git")
fixture_root=$(cat "${0%/*}/work")
printf '%s\n' "$@" >> "$fixture_root/git-arguments"
exec "$fixture_git" -c protocol.file.allow=always \
    -c "url.file://$fixture_root/ick.insteadOf=https://github.com/example/ick.git" \
    -c "url.file://$fixture_root/gcc.insteadOf=https://github.com/example/gcc.git" \
    -c "url.file://$fixture_root/leaf.insteadOf=https://github.com/example/leaf.git" "$@"
EOF
chmod +x "$work/bin/git"
PATH=$work/bin:$PATH
export PATH
CATFOOD_TARGET=container
export CATFOOD_TARGET
CATFOOD_MANIFEST=$work/tools.tsv
CATFOOD_CHECKOUTS=$work/state/checkouts.tsv
export CATFOOD_MANIFEST CATFOOD_CHECKOUTS
printf 'ick\thttps://github.com/example/ick.git\tmain\tskip\n' > "$CATFOOD_MANIFEST"
cd "$work/unrelated"

acquire() {
    sh "$root/catfood" acquire ick "$commit" "$1" "${2:-workbench}"
}
reject() {
    diagnostic=$1
    shift
    if "$@" > "$work/reject.out" 2> "$work/reject.err"; then
        printf 'FAIL: accepted %s\n' "$diagnostic" >&2
        exit 1
    fi
    grep -F "$diagnostic" "$work/reject.err" >/dev/null || { cat "$work/reject.err" >&2; exit 1; }
}

acquire "$work/skipped source" > "$work/skip.tsv"
test ! -e "$work/skipped source/gcc/.git"
test ! -d "$work/skipped source/.git/modules"
grep 'submodules[[:space:]]skip' "$work/skip.tsv" >/dev/null
acquire "$work/skipped source" > "$work/repeat.tsv"
cmp "$work/skip.tsv" "$work/repeat.tsv"
mv "$work/skipped source" "$work/relocated source"
acquire "$work/relocated source" > "$work/relocated.tsv"
cmp "$work/skip.tsv" "$work/relocated.tsv"
printf 'PASS: skip avoids GCC; repeat and relocation preserve material bytes\n'

acquire "$work/producer source" producer > "$work/producer.tsv"
test "$(git -C "$work/producer source/gcc" rev-parse HEAD)" = "$gcc_commit"
test -e "$work/producer source/gcc/nested/.git"
grep 'gitlink[[:space:]]gcc/nested' "$work/producer.tsv" >/dev/null
acquire "$work/producer source" producer > "$work/producer-repeat.tsv"
cmp "$work/producer.tsv" "$work/producer-repeat.tsv"
printf 'PASS: producer obtains exact GCC and nested reference\n'

acquire "$work/custom update" > "$work/custom-skip.tsv"
git -C "$work/custom update" config submodule.gcc.update "!touch '$work/unwanted-effect'"
acquire "$work/custom update" producer > "$work/custom-producer.tsv"
test ! -e "$work/unwanted-effect"
cmp "$work/producer.tsv" "$work/custom-producer.tsv"
printf 'PASS: configured custom update command cannot execute\n'

git -C "$work/relocated source" remote set-url origin https://github.com/unrelated/ick.git
reject 'wrong repository origin' acquire "$work/relocated source"
git -C "$work/relocated source" remote set-url origin https://github.com/example/ick.git
printf 'changed\n' > "$work/relocated source/source"
reject 'partial or changed checkout' acquire "$work/relocated source"
git -C "$work/relocated source" checkout -- source
rm "$work/relocated source/source"
reject 'partial or changed checkout' acquire "$work/relocated source"
git -C "$work/relocated source" checkout -- source
git -C "$work/relocated source" config core.sparseCheckout true
reject 'sparse checkout is incomplete' acquire "$work/relocated source"
git -C "$work/relocated source" config core.sparseCheckout false
git -C "$work/relocated source" update-index --assume-unchanged source
printf 'hidden change\n' > "$work/relocated source/source"
reject 'index hides tracked content' acquire "$work/relocated source"
git -C "$work/relocated source" update-index --no-assume-unchanged source
git -C "$work/relocated source" checkout -- source
git -C "$work/relocated source" update-index --skip-worktree source
reject 'index hides tracked content' acquire "$work/relocated source"
git -C "$work/relocated source" update-index --no-skip-worktree source
git -C "$work/relocated source" config core.autocrlf true
printf 'fixture\r\n' > "$work/relocated source/source"
git -C "$work/relocated source" add source
reject 'raw source bytes differ from commit' acquire "$work/relocated source"
git -C "$work/relocated source" config core.autocrlf false
printf 'fixture\n' > "$work/relocated source/source"
git -C "$work/producer source/gcc" remote set-url origin https://github.com/unrelated/gcc.git
reject 'wrong repository origin' acquire "$work/producer source" producer
git -C "$work/producer source/gcc" remote set-url origin https://github.com/example/gcc.git
reject 'source acquisition requires an explicit host workbench target' env CATFOOD_TARGET=phone sh "$root/catfood" acquire ick "$commit" "$work/device-must-not-exist" workbench
test ! -e "$work/device-must-not-exist"
reject 'commit must be full lowercase SHA-1' sh "$root/catfood" acquire ick main "$work/not-created" workbench
test ! -e "$work/not-created"
reject 'destination must be absolute' sh "$root/catfood" acquire ick "$commit" relative workbench
ln -s "$work/relocated source" "$work/link"
reject 'symlink destination' acquire "$work/link"
old_commit=$(git -C "$work/ick" rev-parse HEAD~1)
reject 'wrong locked commit' sh "$root/catfood" acquire ick "$old_commit" "$work/relocated source" workbench
if sh "$root/catfood" acquire ick 1111111111111111111111111111111111111111 "$work/unavailable" workbench > "$work/unavailable.tsv" 2> "$work/unavailable.err"; then
    printf 'FAIL: unavailable object accepted\n' >&2; exit 1
fi
test ! -s "$work/unavailable.tsv"
printf 'PASS: wrong origins, changed/partial/sparse checkout, mutable ref, relative/symlink path and missing objects reject\n'

# Change the committed source lock independently of the gitlink.
printf 'gcc_repository=https://github.com/example/gcc.git\ngcc_commit=1111111111111111111111111111111111111111\n' > "$work/ick/ick/SOURCE.lock"
git -C "$work/ick" add ick/SOURCE.lock
git -C "$work/ick" commit -qm wrong-lock
commit=$(git -C "$work/ick" rev-parse HEAD)
reject 'GCC source lock differs from gitlink' acquire "$work/wrong lock"
test ! -e "$work/wrong lock/gcc/.git"
printf 'PASS: committed lock/gitlink disagreement rejects\n'

# Multiple allowed-looking URL values cannot inject extra canonical TSV rows.
printf 'gcc_repository=https://github.com/example/gcc.git\ngcc_commit=%s\n' "$gcc_commit" > "$work/ick/ick/SOURCE.lock"
git -C "$work/ick" config -f .gitmodules --add submodule.gcc.url https://github.com/example/leaf.git
git -C "$work/ick" add .gitmodules ick/SOURCE.lock
git -C "$work/ick" commit -qm duplicate-url
commit=$(git -C "$work/ick" rev-parse HEAD)
reject 'multiple submodule repository URLs' acquire "$work/multiple urls" producer
test ! -e "$work/multiple urls/gcc/.git"
git -C "$work/ick" config -f .gitmodules --replace-all submodule.gcc.url https://github.com/example/gcc.git
git -C "$work/ick" add .gitmodules
git -C "$work/ick" commit -qm restore-url

# A newly fetched child's declaration must be judged before its transport runs.
git -C "$work/gcc" config -f .gitmodules submodule.nested.url https://unapproved.invalid/leaf.git
git -C "$work/gcc" add .gitmodules
git -C "$work/gcc" commit -qm unsupported-child
gcc_commit=$(git -C "$work/gcc" rev-parse HEAD)
git -C "$work/ick/gcc" fetch -q origin "$gcc_commit"
git -C "$work/ick/gcc" checkout -q --detach "$gcc_commit"
printf 'gcc_repository=https://github.com/example/gcc.git\ngcc_commit=%s\n' "$gcc_commit" > "$work/ick/ick/SOURCE.lock"
git -C "$work/ick" add gcc ick/SOURCE.lock
git -C "$work/ick" commit -qm nested-pin
commit=$(git -C "$work/ick" rev-parse HEAD)
: > "$work/git-arguments"
reject 'unsupported submodule repository URL' acquire "$work/bad nested" producer
if grep -F 'https://unapproved.invalid/leaf.git' "$work/git-arguments" >/dev/null; then
    printf 'FAIL: attempted unapproved nested transport\n' >&2; exit 1
fi
test ! -e "$work/bad nested/gcc/nested/.git"
printf 'PASS: multivalued URL and unapproved nested transport reject before child acquisition\n'

# Advance the real leaf and both committed parent gitlinks together. The leaf's
# declaration content changes; its parent URL and immutable linkage remain valid.
advance_leaf() {
    leaf_commit=$(git -C "$work/leaf" rev-parse HEAD)
    git -C "$work/gcc" config -f .gitmodules submodule.nested.url https://github.com/example/leaf.git
    git -C "$work/gcc" add .gitmodules
    # Commit the actual leaf identity without asking fixture setup to interpret
    # the intentionally malformed child declarations before acquisition does.
    git -C "$work/gcc" update-index --cacheinfo "160000,$leaf_commit,nested"
    git -C "$work/gcc" commit -qm advance-leaf
    gcc_commit=$(git -C "$work/gcc" rev-parse HEAD)
    git -C "$work/ick/gcc" fetch -q origin "$gcc_commit"
    git -C "$work/ick/gcc" checkout -q --detach "$gcc_commit"
    printf 'gcc_repository=https://github.com/example/gcc.git\ngcc_commit=%s\n' "$gcc_commit" > "$work/ick/ick/SOURCE.lock"
    git -C "$work/ick" add gcc ick/SOURCE.lock
    git -C "$work/ick" commit -qm advance-leaf-pin
    commit=$(git -C "$work/ick" rev-parse HEAD)
}

printf '# No nested references.\n' > "$work/leaf/.gitmodules"
git -C "$work/leaf" add .gitmodules
git -C "$work/leaf" commit -qm comment-only-leaf-declarations
advance_leaf
acquire "$work/comment-only leaf" producer > "$work/comment-only.tsv"
test "$(git -C "$work/comment-only leaf/gcc/nested" rev-parse HEAD)" = "$leaf_commit"
acquire "$work/comment-only leaf" producer > "$work/comment-only-repeat.tsv"
cmp "$work/comment-only.tsv" "$work/comment-only-repeat.tsv"
printf 'PASS: empty and comment-only leaf declarations retain exact recursive acquisition\n'

printf '[submodule\n' > "$work/leaf/.gitmodules"
git -C "$work/leaf" add .gitmodules
git -C "$work/leaf" commit -qm malformed-leaf-declarations
advance_leaf
reject 'malformed submodule declarations' acquire "$work/malformed leaf" producer
test ! -s "$work/reject.out"

printf '[submodule "missing-path"]\n\turl = https://github.com/example/leaf.git\n' > "$work/leaf/.gitmodules"
git -C "$work/leaf" add .gitmodules
git -C "$work/leaf" commit -qm incomplete-leaf-declarations
advance_leaf
reject 'submodule policy requires declarations' acquire "$work/incomplete leaf" producer
test ! -s "$work/reject.out"
printf 'PASS: malformed and incomplete nonempty leaf declarations still reject\n'
