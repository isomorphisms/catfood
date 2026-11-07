#!/bin/sh
# Verify selected native Grease and receipt without altering the SDF account.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$root/android/target.sh"
catfood_verify_sdf_target
fail() { printf 'SDF Grease check: %s\n' "$*" >&2; exit 1; }
case $(uname -r) in 9.3|9.3.*) ;; *) fail 'requires pinned NetBSD 9.3 ABI' ;; esac

release=$(awk '$1 !~ /^#/ && NF == 7 { n++; print } END { if (n != 1) exit 1 }' \
    "$root/sdf/grease-release.tsv") || fail 'invalid Grease release matrix'
set -- $release
[ "$1" = greasecpp ] && [ "$2" = netbsd-9.3-amd64 ] || fail 'wrong implementation'
revision=$3
oils_revision=$4
archive_digest=$6
runtime=$HOME/opt
if [ -n "${CATFOOD_SDF_RUNTIME_ROOT:-}" ]; then runtime=$CATFOOD_SDF_RUNTIME_ROOT; fi
package=$runtime/packages/grease/$revision
bin=$runtime/bin
receipt=$runtime/receipts/grease-netbsd-9.3-amd64.tsv
[ -f "$receipt" ] || fail 'installation receipt missing'
for name in grease greasecpp oils-for-unix; do
    [ -L "$bin/$name" ] && [ "$(readlink "$bin/$name")" = "$package/$name" ] ||
        fail "$name does not select the current Cat Food package"
done
[ -x "$package/oils-for-unix" ] && [ -x "$package/greasecpp" ] &&
    [ "$(readlink "$package/grease")" = greasecpp ] ||
    fail 'native package incomplete or implementation wrong'
has_row() {
    grep -Fqx "$(printf '%s\t%s' "$1" "$2")" "$receipt" ||
        fail "receipt mismatch: $1"
}
has_row target NetBSD-9.3-amd64
has_row implementation greasecpp
has_row default greasecpp
has_row grease_revision "$revision"
has_row oils_revision "$oils_revision"
has_row archive_sha256 "$archive_digest"
has_row native_package_smoke PASS
has_row native_alias_and_unalias PASS
has_row selected_command_smoke PASS
sha_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v sha256 >/dev/null 2>&1; then
        sha256 -q "$1"
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        fail 'SHA-256 verifier absent'
    fi
}
has_row oils_binary_sha256 "$(sha_file "$package/oils-for-unix")"
has_row greasecpp_sha256 "$(sha_file "$package/greasecpp")"
script=$(cat <<'GREASE_PROBE'
shopt -s ysh:all
var answer = 6 * 7
write -- "grease=$answer"
alias ll='echo alias-ok'
ll
unalias ll
if alias ll >/dev/null 2>&1 {
  echo status=0
} else {
  echo status=$?
}
GREASE_PROBE
)
expected=$(printf 'grease=42\nalias-ok\nstatus=1')
for name in grease greasecpp; do
    actual=$("$bin/$name" -c "$script") || fail "selected $name failed"
    [ "$actual" = "$expected" ] || fail "$name lacks current alias semantics"
done
if [ -x "$HOME/bin/grease" ]; then
    actual=$("$HOME/bin/grease" -c "$script") ||
        fail 'old PATH launcher does not run current Grease'
    [ "$actual" = "$expected" ] || fail 'old PATH launcher selects an obsolete binary'
fi
printf 'grease\tPASS\t%s\t%s\n' "$revision" "$(sha_file "$package/oils-for-unix")"
