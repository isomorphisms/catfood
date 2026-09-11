#!/bin/sh
set -eu

[ "$#" -eq 1 ] || { echo 'usage: tests/followers.sh AICI_FOLLOWERS' >&2; exit 2; }
verifier=$1
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
fixture=$tmp/repo
mkdir -p "$fixture/followers/jobs" "$fixture/followers/receipts" \
    "$fixture/tests" "$fixture/phone" "$fixture/tablet" "$fixture/.github/workflows"
cp "$root/followers/manage.sh" "$root/followers/targets.tsv" \
    "$root/followers/impact-rules.tsv" "$fixture/followers/"

cat > "$fixture/catfood" <<'EOF_CATFOOD'
#!/bin/sh
if [ "${1:-}" = --target ]; then
    printf '%s\n' "${CATFOOD_TARGET:-cloud}"
fi
EOF_CATFOOD
chmod +x "$fixture/catfood"
for name in entrypoint targets phone-binaries; do
    printf '%s\n' '#!/bin/sh' 'exit 0' > "$fixture/tests/$name.sh"
done
printf '%s\n' '# base provision' > "$fixture/provision.sh"
printf '%s\n' '# phone base' > "$fixture/phone/README.md"

(
    cd "$fixture"
    git init -q
    git config user.email follower-test@example.invalid
    git config user.name follower-test
    git add .
    git commit -qm base

    printf '%s\n' '# shared phone-led change' >> provision.sh
    git add provision.sh
    git commit -qm shared-change
    trigger=$(git rev-parse HEAD)

    affected=$(sh followers/manage.sh affected "$trigger")
    for target in phone tablet github-x86_64 container-x86_64 hetzner-x86_64; do
        printf '%s\n' "$affected" | grep "^$target[[:space:]]" >/dev/null
    done

    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        prepare "$trigger" phone armv7 - phone/example 1 >/dev/null
    count=$(find followers/jobs -name '*.tsv' -type f | wc -l | tr -d ' ')
    [ "$count" -eq 5 ]
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh reconcile "$trigger" >/dev/null

    id=catfood-$(printf '%s' "$trigger" | cut -c1-12)-github-x86_64
    cat > "$tmp/github-receipt.tsv" <<EOF_RECEIPT
schema	aici-follower-receipt-v1
job_id	$id
repository	isomorphisms/catfood
trigger_commit	$trigger
follower_platform	github-x86_64
follower_arch	x86_64
acceptance_kind	runtime
result	pass
attempt_commit	$trigger
os_runtime	ubuntu fixture x86_64
build_command	-
test_command	sh followers/accept-x86.sh github
artifact	-
artifact_sha256	-
evidence_url	https://example.invalid/actions/1
recorded_at	2026-09-11T12:30:00-04:00
note	fixture proving exact follower completion
EOF_RECEIPT
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        record "$id" "$tmp/github-receipt.tsv" >/dev/null
    pending=$(AICI_FOLLOWERS="$verifier" sh followers/manage.sh pending "$trigger")
    if printf '%s\n' "$pending" | grep 'github-x86_64' >/dev/null; then
        echo 'completed GitHub follower remained pending' >&2
        exit 1
    fi
    printf '%s\n' "$pending" | grep 'hetzner-x86_64' >/dev/null

    tablet=followers/jobs/catfood-$(printf '%s' "$trigger" | cut -c1-12)-tablet.tsv
    mv "$tablet" "$tablet.hold"
    if AICI_FOLLOWERS="$verifier" sh followers/manage.sh reconcile "$trigger" >/dev/null 2>&1; then
        echo 'missing inferred tablet follower was accepted' >&2
        exit 1
    fi
    mv "$tablet.hold" "$tablet"

    git add followers
    git commit -qm follower-ledger
    printf '%s\n' '# phone-only change' >> phone/README.md
    git add phone/README.md
    git commit -qm phone-only
    phone_trigger=$(git rev-parse HEAD)
    phone_affected=$(sh followers/manage.sh affected "$phone_trigger")
    [ "$(printf '%s\n' "$phone_affected" | wc -l | tr -d ' ')" -eq 1 ]
    printf '%s\n' "$phone_affected" | grep '^phone[[:space:]]' >/dev/null
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        prepare "$phone_trigger" phone armv7 - phone/example 2 >/dev/null
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh reconcile "$phone_trigger" >/dev/null
)

printf '%s\n' 'cat food follower inference self-test passes'
