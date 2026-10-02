#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
workspace=${CATFOOD_ROOT:-"$HOME/opt"}
target=${CATFOOD_TARGET:-}
source_script=$root/android/bootstrap-crawlspace.sh
destination=$workspace/bin/crawlspace-bootstrap
marker='# Cat Food Crawl Space phone bootstrap.'

case "$target" in
    tablet)
        printf '%s\n' 'Cat Food tablet: Crawl Space client installed; ADB bootstrap remains deferred.'
        exit 0
        ;;
    phone) ;;
    *)
        printf 'Crawl Space bootstrap installation requires CATFOOD_TARGET=phone or tablet; found %s\n' "${target:-unset}" >&2
        exit 2
        ;;
esac

[ -x "$workspace/bin/crawlspace" ] || {
    printf 'Cat Food phone is missing the delivered Crawl Space runtime: %s\n' "$workspace/bin/crawlspace" >&2
    exit 3
}
[ -f "$source_script" ] || {
    printf 'Cat Food Crawl Space bootstrap source is missing: %s\n' "$source_script" >&2
    exit 3
}

mkdir -p "$workspace/bin"
if [ -e "$destination" ] || [ -L "$destination" ]; then
    if [ ! -f "$destination" ] || ! grep -F "$marker" "$destination" >/dev/null 2>&1; then
        printf '%s exists and is not owned by Cat Food Crawl Space bootstrap; leaving it alone\n' "$destination" >&2
        exit 4
    fi
fi

temporary=$destination.tmp.$$
rm -f "$temporary"
cp "$source_script" "$temporary"
chmod 0755 "$temporary"
mv "$temporary" "$destination"
printf 'Crawl Space bootstrap installed at %s\n' "$destination"

if [ "${CATFOOD_CRAWLSPACE_BOOTSTRAP:-1}" != 0 ]; then
    CATFOOD_ROOT="$workspace" "$destination" --if-connected
fi
