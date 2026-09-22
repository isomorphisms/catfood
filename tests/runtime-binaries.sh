#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/catfood-runtime-binaries-test.$$
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/assets/miller-9.8.7-linux-amd64" "$tmp/work" "$tmp/cache"

cat > "$tmp/assets/jq" <<'EOF'
#!/bin/sh
case "${1:-}" in
    --version) printf '%s\n' 'jq-9.8.7' ;;
    *) printf '%s\n' '{"ok":true}' ;;
esac
EOF
chmod +x "$tmp/assets/jq"

cat > "$tmp/assets/miller-9.8.7-linux-amd64/mlr" <<'EOF'
#!/bin/sh
case "${1:-}" in
    --version) printf '%s\n' 'mlr 9.8.7' ;;
    *) printf '%s\n' 'a=1' ;;
esac
EOF
chmod +x "$tmp/assets/miller-9.8.7-linux-amd64/mlr"
printf '%s\n' test > "$tmp/assets/miller-9.8.7-linux-amd64/README.md"
tar -czf "$tmp/assets/miller.tar.gz" -C "$tmp/assets" miller-9.8.7-linux-amd64

jq_sha=$(sha256sum "$tmp/assets/jq" | awk '{print $1}')
mlr_sha=$(sha256sum "$tmp/assets/miller.tar.gz" | awk '{print $1}')
manifest="$tmp/runtime-binaries.tsv"
tab=$(printf '\t')
{
    printf '# command\tsource\tversion\tplatform\tmode\turl\tsha256\tentrypoint\tprobe_arg\tprobe_contains\n'
    printf 'jq\tfixture/jq\t9.8.7\tlinux-x86_64\tfile\tfile://%s\t%s\t-\t--version\t9.8.7\n'         "$tmp/assets/jq" "$jq_sha"
    printf 'mlr\tfixture/miller\t9.8.7\tlinux-x86_64\ttar.gz\tfile://%s\t%s\tmiller-9.8.7-linux-amd64/mlr\t--version\t9.8.7\n'         "$tmp/assets/miller.tar.gz" "$mlr_sha"
} > "$manifest"

CATFOOD_BINARY_PLATFORM=linux-x86_64 CATFOOD_BINARY_MANIFEST="$manifest" CATFOOD_ROOT="$tmp/work" CATFOOD_CACHE="$tmp/cache" sh "$root/install-binaries.sh" >/dev/null

[ "$("$tmp/work/bin/jq" --version)" = "jq-9.8.7" ]
[ "$("$tmp/work/bin/mlr" --version)" = "mlr 9.8.7" ]
grep -Fqx "installation_result${tab}PASS" "$tmp/work/receipts/runtime-binary-linux-x86_64-jq.tsv"
grep -Fqx "runtime_probe_result${tab}PASS" "$tmp/work/receipts/runtime-binary-linux-x86_64-mlr.tsv"

bad="$tmp/bad.tsv"
sed "s/${jq_sha}/0000000000000000000000000000000000000000000000000000000000000000/"     "$manifest" > "$bad"
rm -rf "$tmp/bad-work" "$tmp/bad-cache"
mkdir -p "$tmp/bad-work" "$tmp/bad-cache"
if CATFOOD_BINARY_PLATFORM=linux-x86_64    CATFOOD_BINARY_MANIFEST="$bad"    CATFOOD_ROOT="$tmp/bad-work"    CATFOOD_CACHE="$tmp/bad-cache"    sh "$root/install-binaries.sh" >/dev/null 2>&1; then
    printf '%s\n' 'runtime-binary installer accepted a bad SHA-256' >&2
    exit 1
fi

mkdir -p "$tmp/collision/bin"
printf '#!/bin/sh\nexit 0\n' > "$tmp/collision/bin/jq"
chmod +x "$tmp/collision/bin/jq"
if CATFOOD_BINARY_PLATFORM=linux-x86_64    CATFOOD_BINARY_MANIFEST="$manifest"    CATFOOD_ROOT="$tmp/collision"    CATFOOD_CACHE="$tmp/cache-collision"    sh "$root/install-binaries.sh" >/dev/null 2>&1; then
    printf '%s\n' 'runtime-binary installer overwrote an unowned command' >&2
    exit 1
fi

printf '%s\n' 'runtime-binary contracts PASS'
