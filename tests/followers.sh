#!/bin/sh
set -eu

[ "$#" -eq 1 ] || { echo 'usage: tests/followers.sh AICI_FOLLOWERS' >&2; exit 2; }
verifier=$1
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
fixture=$tmp/repo
mkdir -p "$fixture/followers/jobs" "$fixture/followers/receipts" \
    "$fixture/tests" "$fixture/android" "$fixture/.github/workflows"
cp "$root/followers/manage.sh" "$root/followers/stale.sh" \
    "$root/followers/targets.tsv" "$root/followers/impact-rules.tsv" \
    "$fixture/followers/"

cat > "$fixture/catfood" <<'EOF_CATFOOD'
#!/bin/sh
if [ "${1:-}" = --target ]; then
    printf '%s\n' "${CATFOOD_TARGET:-cloud}"
fi
EOF_CATFOOD
chmod +x "$fixture/catfood"
for name in entrypoint targets android-delivery; do
    printf '%s\n' '#!/bin/sh' 'exit 0' > "$fixture/tests/$name.sh"
done
printf '%s\n' '# base provision' > "$fixture/provision.sh"
printf '%s\n' '# android base' > "$fixture/android/install-example.sh"

(
    cd "$fixture"
    git init -q
    git config user.email follower-test@example.invalid
    git config user.name follower-test
    git add .
    git commit -qm base

    printf '%s\n' '# shared mobile-led change' >> provision.sh
    git add provision.sh
    git commit -qm shared-change
    trigger=$(git rev-parse HEAD)

    affected=$(sh followers/manage.sh affected "$trigger")
    for target in phone tablet github-x86_64 container-x86_64 hetzner-x86_64 void-x86_64; do
        printf '%s\n' "$affected" | grep "^$target[[:space:]]" >/dev/null
    done

    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        prepare "$trigger" phone armv7 - phone/example 1 >/dev/null
    count=$(find followers/jobs -name '*.tsv' -type f | wc -l | tr -d ' ')
    [ "$count" -eq 6 ]
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
    printf '%s\n' "$pending" | grep 'void-x86_64' >/dev/null

    tablet=followers/jobs/catfood-$(printf '%s' "$trigger" | cut -c1-12)-tablet.tsv
    mv "$tablet" "$tablet.hold"
    if AICI_FOLLOWERS="$verifier" sh followers/manage.sh reconcile "$trigger" >/dev/null 2>&1; then
        echo 'missing inferred tablet follower was accepted' >&2
        exit 1
    fi
    mv "$tablet.hold" "$tablet"

    git add followers
    git commit -qm follower-ledger
    printf '%s\n' '# Android artifact change' >> android/install-example.sh
    git add android/install-example.sh
    git commit -qm android-artifact
    android_trigger=$(git rev-parse HEAD)
    android_affected=$(sh followers/manage.sh affected "$android_trigger")
    [ "$(printf '%s\n' "$android_affected" | wc -l | tr -d ' ')" -eq 3 ]
    printf '%s\n' "$android_affected" | grep '^phone[[:space:]].*physical-device' >/dev/null
    printf '%s\n' "$android_affected" | grep '^tablet[[:space:]].*physical-device' >/dev/null
    printf '%s\n' "$android_affected" | grep '^github-x86_64-artifact[[:space:]].*artifact' >/dev/null
    if printf '%s\n' "$android_affected" | grep 'hetzner-x86_64' >/dev/null; then
        echo 'Android-only path incorrectly required Hetzner runtime' >&2
        exit 1
    fi
    if printf '%s\n' "$android_affected" | grep 'void-x86_64' >/dev/null; then
        echo 'Android-only path incorrectly required Void runtime' >&2
        exit 1
    fi
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        prepare "$android_trigger" phone armv7 - phone/example 2 >/dev/null
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh reconcile "$android_trigger" >/dev/null

    if sh followers/stale.sh >/dev/null 2>&1; then
        echo 'unresolved follower work from an ancestor trigger was forgotten' >&2
        exit 1
    fi
)

make_integration_fixture() {
    destination=$1
    mkdir -p "$destination/followers/jobs" "$destination/followers/receipts" \
        "$destination/tests" "$destination/android" "$destination/.github/workflows"
    cp "$root/followers/manage.sh" "$root/followers/stale.sh" \
        "$root/followers/targets.tsv" "$root/followers/impact-rules.tsv" \
        "$destination/followers/"
    cat > "$destination/catfood" <<'EOF_CATFOOD'
#!/bin/sh
if [ "${1:-}" = --target ]; then
    printf '%s\n' "${CATFOOD_TARGET:-cloud}"
fi
EOF_CATFOOD
    chmod +x "$destination/catfood"
    for name in entrypoint targets android-delivery; do
        printf '%s\n' '#!/bin/sh' 'exit 0' > "$destination/tests/$name.sh"
    done
    printf '%s\n' '# base provision' > "$destination/provision.sh"
    printf '%s\n' '# android base' > "$destination/android/install-example.sh"
}

# A normal merge creates a new commit identity even when its non-control source
# state is exactly the state for which the feature branch already recorded
# follower jobs. The merge must resolve back to that exact trigger rather than
# demanding jobs for a commit that did not exist before integration.
merge_fixture=$tmp/merge-repo
make_integration_fixture "$merge_fixture"
(
    cd "$merge_fixture"
    git init -q
    git config user.email follower-test@example.invalid
    git config user.name follower-test
    git add .
    git commit -qm base
    base_branch=$(git branch --show-current)

    git checkout -qb feature
    printf '%s\n' '# source change' >> provision.sh
    git add provision.sh
    git commit -qm source
    source_trigger=$(git rev-parse HEAD)
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        prepare "$source_trigger" phone armv7 - feature 1 >/dev/null
    git add followers
    git commit -qm follower-ledger

    git checkout -q "$base_branch"
    git merge --no-ff feature -m integration >/dev/null
    integration_trigger=$(git rev-parse HEAD)
    [ "$(sh followers/manage.sh latest)" = "$integration_trigger" ]
    [ "$(sh followers/manage.sh resolve "$integration_trigger")" = "$source_trigger" ]
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh reconcile "$integration_trigger" >/dev/null
    sh followers/stale.sh >/dev/null

    printf '%s\n' '# real post-integration source change' >> provision.sh
    git add provision.sh
    git commit -qm new-source
    if sh followers/manage.sh resolve "$(git rev-parse HEAD)" >/dev/null 2>&1; then
        echo 'different source state incorrectly reused an older follower trigger' >&2
        exit 1
    fi
)

# Squash integration has the same identity problem but no second parent. As
# long as the exact source commit named by the checked-in jobs is available,
# source-state equality is still sufficient to recover the canonical trigger.
squash_fixture=$tmp/squash-repo
make_integration_fixture "$squash_fixture"
(
    cd "$squash_fixture"
    git init -q
    git config user.email follower-test@example.invalid
    git config user.name follower-test
    git add .
    git commit -qm base
    base_branch=$(git branch --show-current)

    git checkout -qb feature
    printf '%s\n' '# source change' >> provision.sh
    git add provision.sh
    git commit -qm source
    source_trigger=$(git rev-parse HEAD)
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        prepare "$source_trigger" phone armv7 - feature 2 >/dev/null
    git add followers
    git commit -qm follower-ledger

    git checkout -q "$base_branch"
    git merge --squash feature >/dev/null
    git commit -qm squash-integration
    integration_trigger=$(git rev-parse HEAD)
    [ "$(sh followers/manage.sh latest)" = "$integration_trigger" ]
    [ "$(sh followers/manage.sh resolve "$integration_trigger")" = "$source_trigger" ]
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh reconcile "$integration_trigger" >/dev/null
    sh followers/stale.sh >/dev/null
)

printf '%s\n' 'cat food follower inference self-test passes'
