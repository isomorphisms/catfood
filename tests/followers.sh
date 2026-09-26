#!/bin/sh
set -eu

[ "$#" -eq 1 ] || { echo 'usage: tests/followers.sh AICI_FOLLOWERS' >&2; exit 2; }
verifier=$1
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
if (
    unset CATFOOD_ROOT CATFOOD_PREFIX
    sh "$root/followers/accept-x86.sh" container
) > "$tmp/no-workbench.log" 2>&1; then
    echo 'unprovisioned host was accepted as runtime follower evidence' >&2
    exit 1
fi
grep -F 'requires CATFOOD_ROOT and CATFOOD_PREFIX' "$tmp/no-workbench.log" >/dev/null
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
elif [ "${1:-}" = where ]; then
    printf 'grease\tworkbench\t%s/grease\n' "$CATFOOD_ROOT"
fi
EOF_CATFOOD
chmod +x "$fixture/catfood"
for name in entrypoint targets android-delivery; do
    printf '%s\n' '#!/bin/sh' 'exit 0' > "$fixture/tests/$name.sh"
done
printf '%s\n' '# base provision' > "$fixture/provision.sh"
printf '%s\n' '# android base' > "$fixture/android/install-example.sh"

# Isolate the provenance verifier: these fake commands are fixtures, never
# runtime evidence. A good stamp must pass; missing/mismatched provenance must
# fail before the consumer's doctor could lend it false confidence.
workbench=$tmp/workbench
mkdir -p "$workbench/bin" "$workbench/.build/stamps" "$workbench/grease/source"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$workbench/bin/catfood-doctor"
chmod +x "$workbench/bin/catfood-doctor"
printf '%s\n' '#!/bin/sh' 'echo canonical-grease' > "$workbench/bin/grease"
chmod +x "$workbench/bin/grease"
git -C "$workbench/grease/source" init -q
git -C "$workbench/grease/source" -c user.name=test -c user.email=test@example.invalid commit --allow-empty -qm source
source_pin=$(git -C "$workbench/grease/source" rev-parse HEAD)
git -C "$workbench/grease" init -q
git -C "$workbench/grease" update-index --add --cacheinfo "160000,$source_pin,source"
git -C "$workbench/grease" -c user.name=test -c user.email=test@example.invalid commit -qm gitlink
grease_head=$(git -C "$workbench/grease" rev-parse HEAD)
printf '%s %s\n' "$grease_head" "$source_pin" > "$workbench/.build/stamps/grease"
CATFOOD_ROOT="$workbench" CATFOOD_PREFIX="$tmp/prefix" \
    sh "$root/followers/accept-x86.sh" github "$fixture" > "$tmp/provenance-good.log"
for hostile in missing-stamp wrong-source wrong-runtime missing-source; do
    case $hostile in
        missing-stamp) rm "$workbench/.build/stamps/grease" ;;
        wrong-source) printf '%s %s\n' "$grease_head" "$grease_head" > "$workbench/.build/stamps/grease" ;;
        wrong-runtime)
            printf '%s %s\n' "$grease_head" "$source_pin" > "$workbench/.build/stamps/grease"
            printf '%s\n' '#!/bin/sh' 'exec bash "$@"' > "$workbench/bin/grease"
            ;;
        missing-source)
            printf '%s %s\n' "$grease_head" "$source_pin" > "$workbench/.build/stamps/grease"
            rm -rf "$workbench/grease/source"
            ;;
    esac
    if CATFOOD_ROOT="$workbench" CATFOOD_PREFIX="$tmp/prefix" \
        sh "$root/followers/accept-x86.sh" github "$fixture" > "$tmp/provenance-$hostile.log" 2>&1; then
        printf 'runtime provenance accepted %s\n' "$hostile" >&2
        exit 1
    fi
done

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
    for target in phone tablet github-x86_64 container-x86_64 hetzner-x86_64; do
        printf '%s\n' "$affected" | grep "^$target[[:space:]]" >/dev/null
    done

    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        prepare "$trigger" phone armv7 - phone/example 1 >/dev/null
    count=$(find followers/jobs -name '*.tsv' -type f | wc -l | tr -d ' ')
    [ "$count" -eq 5 ]
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh reconcile "$trigger" >/dev/null
    # The read-only renderer must retain the canonical verifier's columns.
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh pending > "$tmp/verified-pending"
    AICI_FOLLOWERS= sh followers/manage.sh pending > "$tmp/read-only-pending"
    sort "$tmp/verified-pending" > "$tmp/verified-sorted"
    sort "$tmp/read-only-pending" > "$tmp/read-only-sorted"
    cmp "$tmp/verified-sorted" "$tmp/read-only-sorted"

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
    printf '%s\n' '# CI-only repair' > .github/workflows/check.yml
    git add .github/workflows/check.yml
    git commit -qm ci-only
    ci_trigger=$(git rev-parse HEAD)
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        prepare "$ci_trigger" phone armv7 - phone/example 2 >/dev/null
    [ "$(find followers/jobs -name '*.tsv' -type f | wc -l | tr -d ' ')" -eq 6 ]
    sh followers/manage.sh supersede-ancestors "$ci_trigger" >/dev/null
    sh followers/stale.sh >/dev/null
    [ "$(sh followers/manage.sh stale-target "$trigger" "$ci_trigger" phone)" = no ]
    awk -F '\t' '$1=="state" {exit $2!="pending"}' "$tablet"
    # Retained debt remains bound to its original exact source in the merge view.
    sh followers/manage.sh blockers "$ci_trigger" | awk -F '\t' \
        -v old="$trigger" 'NR>1 && $3==old && $4==old && $6=="pending" {found=1} END {exit !found}'
    if sh followers/manage.sh affected deadbeef >/dev/null 2>&1; then
        echo 'missing source history became empty successful inference' >&2
        exit 1
    fi
    if sh followers/manage.sh stale-target deadbeef "$ci_trigger" phone >/dev/null 2>&1; then
        echo 'missing ancestor history was treated as unaffected' >&2
        exit 1
    fi
    git clone -q --depth 1 "file://$fixture" "$tmp/shallow"
    if sh "$tmp/shallow/followers/manage.sh" stale-target "$trigger" "$ci_trigger" phone > "$tmp/shallow.log" 2>&1; then
        echo 'shallow history was treated as proof of unchanged target' >&2
        exit 1
    fi
    grep -F 'full history is required' "$tmp/shallow.log" >/dev/null
    cp followers/impact-rules.tsv "$tmp/policy"
    sed '/^default/d' "$tmp/policy" > followers/impact-rules.tsv
    if sh followers/manage.sh affected "$trigger" >/dev/null 2>&1; then
        echo 'unmatched source path became empty successful inference' >&2
        exit 1
    fi
    [ "$(sh followers/manage.sh stale-target "$trigger" "$ci_trigger" phone)" = yes ]
    git add followers/impact-rules.tsv
    git commit -qm changed-policy
    policy_trigger=$(git rev-parse HEAD)
    cp "$tmp/policy" followers/impact-rules.tsv
    # Reading old policy from the working tree must not hide CURRENT's policy change.
    [ "$(sh followers/manage.sh stale-target "$trigger" "$policy_trigger" phone)" = yes ]
    git add followers
    git commit -qm restore-policy-and-ci-ledger
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
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        prepare "$android_trigger" phone armv7 - phone/example 2 >/dev/null
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh reconcile "$android_trigger" >/dev/null

    if sh followers/stale.sh >/dev/null 2>&1; then
        echo 'unresolved follower work from an ancestor trigger was forgotten' >&2
        exit 1
    fi

    blockers=$(sh followers/manage.sh blockers "$android_trigger")
    printf '%s\n' "$blockers" | grep "${trigger}.*${android_trigger}" >/dev/null
    printf '%s\n' "$blockers" | awk -F '\t' -v current="$android_trigger" \
        'NR>1 && $4==current && $2=="no" {found=1} END {exit !found}'

    sh followers/manage.sh supersede-ancestors "$android_trigger" >/dev/null
    sh followers/stale.sh >/dev/null
    # Android delivery changes require device successors; unrelated host debt stays exact.
    [ "$(sh followers/manage.sh stale-target "$trigger" "$android_trigger" phone)" = yes ]
    [ "$(sh followers/manage.sh stale-target "$trigger" "$android_trigger" hetzner-x86_64)" = no ]
    old_host=followers/jobs/catfood-$(printf '%s' "$trigger" | cut -c1-12)-hetzner-x86_64.tsv
    awk -F '\t' '$1=="state" {exit $2!="pending"}' "$old_host"

    printf '%s\n' '# combined portable successor' >> provision.sh
    printf '%s\n' '# combined Android successor' >> android/install-example.sh
    git add provision.sh android/install-example.sh
    git commit -qm combined-successor
    current_trigger=$(git rev-parse HEAD)
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        prepare "$current_trigger" phone armv7 - phone/example 3 >/dev/null

    sh followers/manage.sh supersede-ancestors "$current_trigger" >/dev/null
    sh followers/stale.sh >/dev/null
    blockers=$(sh followers/manage.sh blockers "$current_trigger")
    if printf '%s\n' "$blockers" | grep "$trigger" >/dev/null; then
        echo 'superseded ancestor remained in merge blockers' >&2
        exit 1
    fi
    printf '%s\n' "$blockers" | awk -F '\t' -v current="$current_trigger" \
        'NR>1 && $3==current && $4==current && $2=="no" {found=1} END {exit !found}'
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
