#!/bin/sh
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
observation=$root/docs/observations/miro-c67-grease-github-transfer-2026-10-09.tsv
[ -f "$observation" ] || { echo 'missing C67 Grease live-transfer observation' >&2; exit 1; }
tab=$(printf '\t')

for required in \
    "package${tab}id${tab}grease-tablet${tab}device-install-log${tab}C67 consumes the arm64-v8a package lane" \
    "package${tab}archive_sha256${tab}3ddb962ef313e528e525fa03518f494577e921c2201ecb49f7a11f2fbf4e82b2${tab}device-install-log${tab}download verified before install" \
    "installation${tab}result${tab}PASS${tab}device-install-log${tab}installed through android/install.sh" \
    "provisioning${tab}full_catfood_result${tab}BLOCKED${tab}device-install-log${tab}pinned linux-aarch64 jq runtime probe failed before Android package delivery" \
    "runtime${tab}physical_execution${tab}PASS${tab}user-confirmed${tab}physical MIRO C67 Termux" \
    "runtime${tab}exact_final_stdout${tab}NOT_RETAINED${tab}evidence-limit${tab}do not reconstruct final terminal bytes" \
    "postcondition${tab}result${tab}PASS${tab}independent-GitHub-read${tab}all ten destinations canonical under isomorphismes" \
    "postcondition${tab}repository_count${tab}10${tab}independent-GitHub-read${tab}all numeric IDs preserved" \
    "boundary${tab}generic_trusted_chat_adapter${tab}NOT_DEPLOYED${tab}evidence-limit${tab}this conversation is positive operational evidence, not general attestation"
do
    grep -Fqx "$required" "$observation" || {
        printf 'missing required C67 observation row: %s\n' "$required" >&2
        exit 1
    }
done

actual=$(mktemp)
expected=$(mktemp)
trap 'rm -f "$actual" "$expected"' EXIT HUP INT TERM
awk -F '\t' '$1 == "postcondition" && $2 != "result" && $2 != "repository_count" { print $2 "\t" $3 }' "$observation" > "$actual"
cat > "$expected" <<'EOF'
mapping-class	1412391052
montesinos	1412394512
Bulatov-Goodman-Strauss	1412402847
regina	1412463768
VanKoughnett	1412475989
zakharevich	1412476795
snaith	1412477737
kirby-calculus	1412481397
morava	1412482666
goodwillie	1412483445
EOF
cmp "$expected" "$actual" || {
    echo 'C67 live-transfer repository identity observation changed' >&2
    exit 1
}

echo 'PASS retained C67 Grease live-transfer observation and evidence limits'
