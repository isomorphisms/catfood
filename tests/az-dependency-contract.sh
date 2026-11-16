#!/bin/sh
# Contract fixture, not proof of a current Amazon product or a Grease build.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
lane=${1:-}
checkout=${2:-}
case "$lane" in production|candidate) ;; *) echo "usage: $0 production|candidate AZ_CHECKOUT" >&2; exit 2 ;; esac
[ -d "$checkout/.git" ] || { echo "AZ search contract drift: missing source checkout" >&2; exit 2; }
record=$(awk -F '\t' '$1 == "az" { print; exit }' "$root/ci/az-consumers.tsv")
[ -n "$record" ] || { echo "AZ search contract drift: missing consumer contract row" >&2; exit 2; }
oldIFS=$IFS
IFS=$(printf '\t')
set -- $record
IFS=$oldIFS
[ "$#" -eq 7 ] || { echo "AZ search contract drift: malformed manifest" >&2; exit 2; }
[ "$2" = Ashtray-Archer/az ] && [ "$3" = main ] &&
[ "$7" = tests/az-dependency-contract.sh ] ||
    { echo "AZ search contract drift: wrong repository or consumer" >&2; exit 2; }
case "$lane" in
    production) expected=$4 ;;
    candidate) expected=$6 ;;
esac
actual=$(git -C "$checkout" rev-parse HEAD)
origin=$(git -C "$checkout" remote get-url origin)
case "$origin" in
    https://github.com/Ashtray-Archer/az|https://github.com/Ashtray-Archer/az.git|git@github.com:Ashtray-Archer/az.git) ;;
    *) echo "AZ search contract drift: wrong source origin $origin" >&2; exit 2 ;;
esac
if [ "$actual" != "$expected" ]; then
    printf 'AZ search contract drift: %s HEAD %s, recorded %s\n' "$lane" "$actual" "$expected" >&2
    echo "Update obligation: ci/az-consumers.tsv, tests/az-dependency-contract.sh, ci/fixtures/amazon-search, and Kitchen/Flexible Pipes source pins" >&2
    exit 1
fi
# Production is a pinned, known-bad baseline: its source predates the status
# contract. Verify its identity, but never call it an accepted consumer result.
# The candidate lane below is the only one required to satisfy the new contract.
if [ "$lane" = production ]; then
    printf 'Cat Food AZ production baseline PINNED_KNOWN_BAD (not accepted): source=%s\n' "$actual"
    exit 0
fi

# A checked-out candidate with a changed source and an old fixture is not
# admitted simply because the commit was recorded in the manifest.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin"
cat > "$tmp/bin/curl" <<'EOF'
#!/bin/sh
for arg in "$@"; do
    case "$arg" in
        'https://www.amazon.com/s?k=catfood%20contract')
            cat "$CATFOOD_AZ_PAGE"
            exit 0 ;;
    esac
done
echo "unexpected fake curl request" >&2
exit 22
EOF
chmod +x "$tmp/bin/curl"
export PATH="$tmp/bin:$PATH"
export AZ_SEARCH_STATUS_FILE="$tmp/status.tsv"
export CATFOOD_AZ_PAGE="$tmp/page.html"
export HOME="$tmp/home"
mkdir -p "$HOME"
cat > "$CATFOOD_AZ_PAGE" <<'HTML'
<html><body><div id="search">
<div data-component-type="s-search-result" data-asin="B000CCFXYY"></div>
<div data-component-type="s-search-result" data-asin="B000PEZ1L4"></div>
</div></body></html>
HTML
result=$(bash "$checkout/bin/az" search 'catfood contract')
expected_header=$(printf 'asin\tamount\tcurrency\tbuy_url\ttitle')
[ "$(printf '%s\n' "$result" | sed -n 1p)" = "$expected_header" ] || {
    echo "AZ search contract drift: consumer TSV columns changed" >&2; exit 1;
}
printf '%s\n' "$result" | grep -Fq 'B000CCFXYY' ||
    { echo "AZ search contract drift: missing candidate" >&2; exit 1; }
grep -Fx "$(printf 'status\tEXTRACTED_UNVERIFIED')" "$AZ_SEARCH_STATUS_FILE" >/dev/null ||
    { echo "AZ search contract drift: candidates incorrectly promoted" >&2; exit 1; }
cat > "$CATFOOD_AZ_PAGE" <<'HTML'
<html><title>Robot Check</title><body>Enter the characters you see below</body></html>
HTML
if bash "$checkout/bin/az" search 'catfood contract' >"$tmp/out" 2>"$tmp/err"; then
    echo "AZ search contract drift: challenge was successful" >&2; exit 1
else
    code=$?
    [ "$code" -eq 5 ] ||
        { echo "AZ search contract drift: changed challenge exit code $code" >&2; exit 1; }
fi
grep -Fx "$(printf 'status\tCHALLENGE')" "$AZ_SEARCH_STATUS_FILE" >/dev/null ||
    { echo "AZ search contract drift: missing challenge receipt" >&2; exit 1; }
link=$(bash "$checkout/bin/az" link B000CCFXYY)
[ "$link" = 'https://www.amazon.com/dp/B000CCFXYY?tag=macguyver03-20' ] ||
    { echo "AZ search contract drift: affiliate-link contract changed" >&2; exit 1; }
# A candidate that passes the host fixture still needs the exact Android
# runtime package bytes for both ABI lanes. C67 consumes the arm64-v8a lane,
# but has independent device acceptance.
actual_digest=$(sha256sum "$checkout/bin/az" | awk '{print $1}')
verify_android_pins() {
    awk -F '\t' -v rev="$expected" -v digest="$actual_digest" '
    $1 == "az-phone" || $1 == "az-tablet" {
        target=$1
        abi=(target == "az-phone" ? "armeabi-v7a" : "arm64-v8a")
        dep=(target == "az-phone" ? "grease-phone" : "grease-tablet")
        url="https://raw.githubusercontent.com/Ashtray-Archer/az/" rev "/bin/az"
        if (++seen[target] != 1 || NF != 18 ||
            $2 != abi || $3 != abi || $4 != "file" ||
            $5 != "Ashtray-Archer/az" ||
            $6 != rev || $7 != rev || $8 != url ||
            $9 != digest || $10 != "az" || $11 != "bin/az" ||
            $18 != dep) {
            print "AZ Android package drift: " target " is not bound to the accepted source bytes" > "/dev/stderr"
            invalid=1
        }
        found++
    }
    END {
        if (found != 2 || seen["az-phone"] != 1 || seen["az-tablet"] != 1) {
            print "AZ Android package drift: exactly one package per ABI lane required" > "/dev/stderr"
            invalid=1
        }
        if (invalid) exit 1
    }' "$1"
}
verify_android_pins "$root/android/packages.tsv" || exit 1
sh "$root/android/check.sh" check >/dev/null

# Reject a plausible-looking package that retains a valid 64-hex digest
# but no longer matches the actual approved AZ source bytes.
awk -F '\t' 'BEGIN {OFS="\t"} $1 == "az-phone" {$9="0000000000000000000000000000000000000000000000000000000000000000"} {print}' \
    "$root/android/packages.tsv" > "$tmp/digest-mutant.tsv"
if verify_android_pins "$tmp/digest-mutant.tsv" >/dev/null 2>&1; then
    echo "AZ Android package drift: altered SHA-256 was admitted" >&2
    exit 1
fi
# A transferred or unrelated source URL is not equivalent to canonical,
# revision-pinned publication provenance.
awk -F '\t' 'BEGIN {OFS="\t"} $1 == "az-tablet" {$8="https://raw.githubusercontent.com/isomorphisms/az/" $6 "/bin/az"} {print}' \
    "$root/android/packages.tsv" > "$tmp/origin-mutant.tsv"
if verify_android_pins "$tmp/origin-mutant.tsv" >/dev/null 2>&1; then
    echo "AZ Android package drift: noncanonical package URL was admitted" >&2
    exit 1
fi

printf 'Cat Food AZ %s contract fixture PASS: source=%s sha256=%s (Bash simulation, not physical Android)\n' "$lane" "$actual" "$actual_digest"
