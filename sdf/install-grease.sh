#!/bin/sh
# Native NetBSD Grease distribution, not a source/Python bootstrap.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$root/android/target.sh"
catfood_verify_sdf_target || exit $?
fail() { printf 'SDF Grease: %s\n' "$*" >&2; exit 1; }

manifest=$root/sdf/grease-release.tsv
row=$(awk '$1 !~ /^#/ && NF == 7 { count++; print } END { if (count != 1) exit 1 }' "$manifest") ||
    fail 'the Grease release manifest must contain exactly one complete row'
set -- $row
[ "$#" -eq 7 ] && [ "$1" = greasecpp ] && [ "$2" = netbsd-9.3-amd64 ] ||
    fail 'Grease release manifest target/implementation mismatch'
revision=$3
oils_revision=$4
archive_name=$5
expected_sha=$6
url=$7
case $expected_sha in *[!0123456789abcdef]*|'') fail 'invalid SHA-256 pin' ;; esac
[ "$(printf '%s' "$expected_sha" | wc -c | tr -d ' ')" = 64 ] || fail 'invalid SHA-256 pin length'
case $(uname -r) in 9.3|9.3.*) ;; *) fail "NetBSD $(uname -r) is not the pinned NetBSD 9.3 ABI" ;; esac
case $url in https://github.com/dilapidated-shed/grease/releases/download/*) ;; *)
    fail 'unexpected release origin' ;; esac

runtime=$CATFOOD_SDF_RUNTIME_ROOT
if [ -z "$runtime" ]; then runtime=$HOME/opt; fi
case $runtime in /*) ;; *) fail 'runtime root must be absolute' ;; esac
bin=$runtime/bin
pkgroot=$runtime/packages/grease
package=$pkgroot/$revision
downloads=$runtime/downloads/grease
archive=$downloads/$revision-$archive_name
receipt=$runtime/receipts/grease-netbsd-9.3-amd64.tsv
for cmd in tar mktemp awk grep cmp readlink mv; do
    command -v "$cmd" >/dev/null 2>&1 || fail "missing command $cmd"
done
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    fail 'curl or wget required; no gh, root, or package manager assumed'
fi
if ! command -v sha256sum >/dev/null 2>&1 &&
   ! command -v sha256 >/dev/null 2>&1 &&
   ! command -v shasum >/dev/null 2>&1; then
    fail 'no SHA-256 verifier available'
fi
sha_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v sha256 >/dev/null 2>&1; then
        sha256 -q "$1"
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}
check_archive() {
    actual=$(sha_file "$1") || fail 'unable to hash release'
    [ "$actual" = "$expected_sha" ] ||
        fail "archive digest mismatch: expected $expected_sha, found $actual"
}

umask 077
mkdir -p "$bin" "$pkgroot" "$downloads" "$runtime/receipts"
partial=$archive.part.$$
stage=''
cleanup() {
    [ ! -f "$partial" ] || rm -f "$partial"
    if [ -n "$stage" ] && [ -d "$stage" ]; then rm -rf "$stage"; fi
}
trap cleanup EXIT HUP INT TERM
if [ -f "$archive" ]; then
    check_archive "$archive"
else
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 2 "$url" -o "$partial" || fail 'release download failed'
    else
        wget -O "$partial" "$url" || fail 'release download failed'
    fi
    check_archive "$partial"
    mv "$partial" "$archive"
fi

stage=$(mktemp -d "$pkgroot/.incoming.XXXXXXXX") ||
    fail 'cannot create private package staging directory'
tar -tzf "$archive" > "$stage/.contents" || fail 'archive list failed'
while IFS= read -r entry || [ -n "$entry" ]; do
    case $entry in
        .|./|./grease|./greasecpp|./oils-for-unix|./receipt.txt) ;;
        *) fail "unexpected release member: $entry" ;;
    esac
done < "$stage/.contents"
tar -xzf "$archive" -C "$stage" || fail 'release extraction failed'
[ -x "$stage/oils-for-unix" ] && [ -x "$stage/greasecpp" ] &&
    [ -L "$stage/grease" ] || fail 'native executable/wrapper missing'
[ "$(readlink "$stage/grease")" = greasecpp ] ||
    fail 'unqualified default Grease implementation'
grep -Fqx "grease_repository_revision=$revision" "$stage/receipt.txt" ||
    fail 'release Grease revision mismatch'
grep -Fqx "grease_source_revision=$oils_revision" "$stage/receipt.txt" ||
    fail 'release source revision mismatch'
grep -Fqx 'alias_ysh_all=PASS' "$stage/receipt.txt" ||
    fail 'release alias acceptance not recorded'

smoke=$stage/.alias-smoke.ysh
cat > "$smoke" <<'YSH'
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
YSH
expected=$(printf 'grease=42\nalias-ok\nstatus=1')
for candidate in "$stage/grease" "$stage/greasecpp"; do
    actual=$("$candidate" "$smoke") || fail "smoke failed: $candidate"
    [ "$actual" = "$expected" ] || fail "bad alias/arithmetic output: $candidate"
done
actual=$("$stage/oils-for-unix" ysh "$smoke") ||
    fail 'native Oils entrypoint failed'
[ "$actual" = "$expected" ] || fail 'native Oils output mismatch'
rm -f "$smoke" "$stage/.contents"

if [ -e "$package" ] || [ -L "$package" ]; then
    [ -d "$package" ] && [ ! -L "$package" ] ||
        fail 'versioned package path is not a directory'
    for name in oils-for-unix greasecpp receipt.txt; do
        cmp "$package/$name" "$stage/$name" >/dev/null ||
            fail "existing immutable package differs: $name"
    done
    [ "$(readlink "$package/grease")" = greasecpp ] ||
        fail 'existing package selects a different implementation'
else
    mv "$stage" "$package"
    stage=''
fi

# Preserve old stable entries in the SAME directory, retaining relative links.
backups=$runtime/receipts/.grease-backups.$$
: > "$backups"
install_link() {
    name=$1
    destination=$bin/$name
    source=$package/$name
    if [ -L "$destination" ] && [ "$(readlink "$destination")" = "$source" ]; then
        return 0
    fi
    temporary=$bin/.grease-new-$name-$$
    [ ! -e "$temporary" ] && [ ! -L "$temporary" ] ||
        fail "staging path occupied: $temporary"
    ln -s "$source" "$temporary" || fail "cannot stage $name link"
    if [ -e "$destination" ] || [ -L "$destination" ]; then
        backup=$bin/$name.before-grease-$revision-$$
        [ ! -e "$backup" ] && [ ! -L "$backup" ] || fail "backup already exists: $backup"
        mv "$destination" "$backup" || fail "cannot preserve old $name"
        if ! mv "$temporary" "$destination"; then
            mv "$backup" "$destination" || :
            fail "cannot activate $name"
        fi
        printf 'backup:%s\t%s\n' "$name" "$backup" >> "$backups"
    else
        mv "$temporary" "$destination" || fail "cannot activate $name"
    fi
}
install_link oils-for-unix
install_link greasecpp
install_link grease

# The previously installed ~/bin/grease has historically shadowed ~/opt/bin.
if [ -d "$HOME/bin" ] && [ -w "$HOME/bin" ]; then
    launcher=$HOME/bin/grease
    temporary=$HOME/bin/.grease-new-$$
    [ ! -e "$temporary" ] && [ ! -L "$temporary" ] ||
        fail 'temporary home launcher already exists'
    {
        printf '%s\n' '#!/bin/sh' '# Cat Food SDF Grease launcher'
        printf 'exec "%s" "$@"\n' "$bin/grease"
    } > "$temporary"
    chmod 0700 "$temporary"
    if [ -e "$launcher" ] || [ -L "$launcher" ]; then
        if cmp "$launcher" "$temporary" >/dev/null 2>&1; then
            rm -f "$temporary"
        else
            backup=$HOME/bin/grease.before-$revision-$$
            [ ! -e "$backup" ] && [ ! -L "$backup" ] || fail 'launcher backup occupied'
            mv "$launcher" "$backup" || fail 'cannot preserve old ~/bin/grease'
            if ! mv "$temporary" "$launcher"; then
                mv "$backup" "$launcher" || :
                fail 'cannot activate ~/bin/grease'
            fi
            printf 'backup:home-bin-grease\t%s\n' "$backup" >> "$backups"
        fi
    else
        mv "$temporary" "$launcher" || fail 'cannot activate ~/bin/grease'
    fi
fi
for name in grease greasecpp; do
    actual=$("$bin/$name" -c 'var answer = 6 * 7; write -- "grease=$answer"') ||
        fail "stable $name not runnable"
    [ "$actual" = grease=42 ] || fail "stable $name produced wrong result"
done

receipt_temp=$receipt.$$
{
    printf 'schema\tcatfood-sdf-grease-v1\n'
    printf 'target\tNetBSD-9.3-amd64\n'
    printf 'implementation\tgreasecpp\n'
    printf 'default\tgreasecpp\n'
    printf 'grease_revision\t%s\n' "$revision"
    printf 'oils_revision\t%s\n' "$oils_revision"
    printf 'archive_sha256\t%s\n' "$expected_sha"
    printf 'oils_binary_sha256\t%s\n' "$(sha_file "$package/oils-for-unix")"
    printf 'greasecpp_sha256\t%s\n' "$(sha_file "$package/greasecpp")"
    printf 'native_package_smoke\tPASS\n'
    printf 'native_alias_and_unalias\tPASS\n'
    printf 'selected_command_smoke\tPASS\n'
    cat "$backups"
} > "$receipt_temp"
mv "$receipt_temp" "$receipt"
rm -f "$backups"
printf 'SDF Grease: installed %s using greasecpp\n' "$revision"
printf 'Stable command: %s/grease\n' "$bin"
printf 'Receipt: %s\n' "$receipt"
printf '%s\n' 'Existing launchers were backed up; login shell/rc files remain unchanged.'
