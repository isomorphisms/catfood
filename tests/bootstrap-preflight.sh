#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/catfood-bootstrap-preflight.$$
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/home"

real_awk=$(command -v awk)
cat > "$tmp/bin/awk" <<EOF
#!/bin/sh
exec "$real_awk" "\$@"
EOF
chmod +x "$tmp/bin/awk"

trace=$tmp/git.trace
cat > "$tmp/bin/git" <<'EOF'
#!/bin/sh
[ "${GIT_TERMINAL_PROMPT:-}" = 0 ] || {
    printf '%s\n' 'remote preflight did not disable Git terminal prompting' >&2
    exit 96
}
printf '%s\n' "$*" >> "$CATFOOD_TEST_GIT_TRACE"
case ${1:-} in
    ls-remote)
        case "$*" in
            *refs/heads/good) exit 0 ;;
            *refs/heads/main)
                case "$*" in
                    *isomorphisms/grease.git*) [ "${CATFOOD_TEST_GREASE_REMOTE:-good}" = good ] && exit 0 || exit 2 ;;
                esac
                ;;
        esac
        exit 2
        ;;
    clone|fetch|checkout|merge|submodule)
        : > "$CATFOOD_TEST_MUTATION_MARKER"
        exit 97
        ;;
    *)
        exit 97
        ;;
esac
EOF
chmod +x "$tmp/bin/git"

bad_manifest=$tmp/bad.tsv
printf '%s\n' 'broken https://github.com/example/broken.git missing none' > "$bad_manifest"
workspace=$tmp/workspace
marker=$tmp/mutated
if HOME=$tmp/home PATH=$tmp/bin:$PATH CATFOOD_ROOT=$workspace CATFOOD_MANIFEST=$bad_manifest \
   CATFOOD_TEST_GIT_TRACE=$trace CATFOOD_TEST_MUTATION_MARKER=$marker \
   sh "$root/bootstrap.sh" >"$tmp/bad.out" 2>"$tmp/bad.err"; then
    printf '%s\n' 'bootstrap accepted a missing manifest remote branch' >&2
    exit 1
fi
test ! -e "$workspace"
test ! -e "$marker"
grep -F 'missing remote branch missing' "$tmp/bad.err" >/dev/null

good_manifest=$tmp/good.tsv
printf '%s\n' 'good https://github.com/example/good.git good none' > "$good_manifest"
rm -f "$trace" "$marker"
if HOME=$tmp/home PATH=$tmp/bin:$PATH CATFOOD_ROOT=$workspace CATFOOD_MANIFEST=$good_manifest \
   CATFOOD_TEST_GREASE_REMOTE=missing CATFOOD_TEST_GIT_TRACE=$trace CATFOOD_TEST_MUTATION_MARKER=$marker \
   sh "$root/bootstrap.sh" >"$tmp/grease.out" 2>"$tmp/grease.err"; then
    printf '%s\n' 'bootstrap accepted a missing Grease remote branch' >&2
    exit 1
fi
test ! -e "$workspace"
test ! -e "$marker"
grep -F 'grease remote branch does not exist' "$tmp/grease.err" >/dev/null

printf '%s\n' 'PASS bootstrap remote refs fail before workspace mutation'
