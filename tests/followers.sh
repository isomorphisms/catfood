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
    "$root/followers/host-cells.tsv" \
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
for name in entrypoint targets android-delivery ib-handoff; do
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
    printf '%s %s\n' "$grease_head" "$source_pin" > "$workbench/.build/stamps/grease"
    printf '%s\n' '#!/bin/sh' 'echo canonical-grease' > "$workbench/bin/grease"
    case $hostile in
        missing-stamp) rm "$workbench/.build/stamps/grease" ;;
        wrong-source) printf '%s %s\n' "$grease_head" "$grease_head" > "$workbench/.build/stamps/grease" ;;
        wrong-runtime)
            printf '%s\n' '#!/bin/sh' 'exec bash "$@"' > "$workbench/bin/grease"
            ;;
        missing-source)
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
    for target in phone c67 tablet github-x86_64 container-x86_64 hetzner-x86_64; do
        printf '%s\n' "$affected" | grep "^$target[[:space:]]" >/dev/null
    done

    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        prepare "$trigger" phone armv7 - phone/example 1 >/dev/null
    count=$(find followers/jobs -name '*.tsv' -type f | wc -l | tr -d ' ')
    [ "$count" -eq 6 ]
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh reconcile "$trigger" >/dev/null
    sh followers/manage.sh host-matrix "$trigger" > "$tmp/host-matrix-a.tsv"
    sh followers/manage.sh host-matrix "$trigger" > "$tmp/host-matrix-b.tsv"
    cmp "$tmp/host-matrix-a.tsv" "$tmp/host-matrix-b.tsv"
    awk -F '\t' 'NF != 21 {exit 1}' "$tmp/host-matrix-a.tsv"
    grep '^sdf-icky-dmd[[:space:]]' "$tmp/host-matrix-a.tsv" >/dev/null
    grep '^sdf-greased[[:space:]]' "$tmp/host-matrix-a.tsv" >/dev/null
    grep '^void-current[[:space:]].*unknown.*unresolved' "$tmp/host-matrix-a.tsv" >/dev/null
    grep "^catfood-$(printf '%s' "$trigger" | cut -c1-12)-github-x86_64[[:space:]]" \
        "$tmp/host-matrix-a.tsv" >/dev/null
    awk -F '\t' '$4=="follower" {
        if ($19!="unknown" || $20!="pending") exit 1
        count++
    } END {if (count!=3) exit 1}' "$tmp/host-matrix-a.tsv"

    cp followers/host-cells.tsv "$tmp/host-cells-good.tsv"
    # Preserve the original bad source/archive witness independently of its
    # mutable display name. These pins are regression evidence, not a denylist.
    awk -F '\t' '$1=="sdf-greasecpp" {
        if ($13!="dilapidated-shed/grease" ||
            $14!="60641ddd99844655c0788f790cd3a8a14c7166fd" ||
            $16!="a7f5e35feebd1a222e2ae724bbbf4a2c1fe28c5683ac3aa6561ed770a9bb3136" ||
            $19!="ineligible" || $20!="historical") exit 1
        found=1
    } END {if (!found) exit 1}' "$tmp/host-cells-good.tsv"
    awk '/^#/ {header[++headers]=$0; next} {row[++rows]=$0}
        END {for(i=1;i<=headers;i++) print header[i]; for(i=rows;i>=1;i--) print row[i]}' \
        "$tmp/host-cells-good.tsv" > followers/host-cells.tsv
    sh followers/manage.sh host-matrix "$trigger" > "$tmp/host-matrix-reordered.tsv"
    cmp "$tmp/host-matrix-a.tsv" "$tmp/host-matrix-reordered.tsv"
    cp "$tmp/host-cells-good.tsv" followers/host-cells.tsv
    awk -F '\t' -v OFS='\t' '$1=="sdf-greased" {$7="11"} {print}' \
        "$tmp/host-cells-good.tsv" > followers/host-cells.tsv
    if sh followers/manage.sh host-matrix >/dev/null 2>&1; then
        echo 'NetBSD 11 evidence was reused for the SDF NetBSD 9.3 cell' >&2
        exit 1
    fi
    awk -F '\t' -v OFS='\t' '$1=="sdf-greased" {$17="current"; $18="branch"; $19="eligible"; $20="accepted"} {print}' \
        "$tmp/host-cells-good.tsv" > followers/host-cells.tsv
    if sh followers/manage.sh host-matrix >/dev/null 2>&1; then
        echo 'branch presence was accepted as host evidence' >&2
        exit 1
    fi
    awk -F '\t' -v OFS='\t' '$1=="sdf-greased" {$12="different-cpu"} {print}' \
        "$tmp/host-cells-good.tsv" > followers/host-cells.tsv
    if sh followers/manage.sh host-matrix >/dev/null 2>&1; then
        echo 'wrong CPU identity was reused for the SDF cell' >&2
        exit 1
    fi
    awk -F '\t' -v OFS='\t' '$1=="sdf-greased" {$15="greased.tar"; $16="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; $17="until:2020-01-01T00:00:00Z"; $19="eligible"; $20="accepted"} {print}' \
        "$tmp/host-cells-good.tsv" > followers/host-cells.tsv
    if CATFOOD_HOST_CELL_NOW=1900-01-01T00:00:00Z \
        sh followers/manage.sh host-matrix > "$tmp/expired-static-artifact.log" 2>&1; then
        echo 'expired artifact availability was accepted' >&2
        exit 1
    fi
    grep -F 'accepted an expired artifact' "$tmp/expired-static-artifact.log" >/dev/null
    # These are synthetic metadata-reader controls, never live host evidence.
    for bad_availability in \
        until:2028-13-01T00:00:00Z until:2028-02-30T00:00:00Z \
        until:2027-02-29T00:00:00Z until:2100-02-29T00:00:00Z \
        until:2028-01-01T24:00:00Z \
        until:2028-01-01T00:60:00Z until:2028-01-01T00:00:60Z \
        until:zzzz-zz-zzTzz:zz:zzZ
    do
        awk -F '\t' -v OFS='\t' -v availability="$bad_availability" \
            '$1=="sdf-greased" {$15="greased.tar"; $16="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; $17=availability; $19="eligible"; $20="accepted"} {print}' \
            "$tmp/host-cells-good.tsv" > followers/host-cells.tsv
        if sh followers/manage.sh host-matrix > "$tmp/invalid-availability.log" 2>&1; then
            printf 'invalid normalized host artifact availability was accepted: %s\n' "$bad_availability" >&2
            exit 1
        fi
        grep -F 'invalid availability timestamp' "$tmp/invalid-availability.log" >/dev/null
    done
    awk -F '\t' -v OFS='\t' \
        '$1=="sdf-greased" {$15="greased.tar"; $16="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; $17="until:9996-02-29T00:00:00Z"; $19="eligible"; $20="accepted"} {print}' \
        "$tmp/host-cells-good.tsv" > followers/host-cells.tsv
    # A valid calendar reaches the unavailable authority boundary; synthetic
    # metadata can no longer create a passing accepted Grease runtime fixture.
    if CATFOOD_HOST_CELL_NOW=9999-01-01T00:00:00Z \
        sh followers/manage.sh host-matrix > "$tmp/valid-calendar.log" 2>&1; then
        echo 'valid availability metadata manufactured runtime eligibility' >&2
        exit 1
    fi
    grep -F 'independently qualified host runtime object is unavailable' "$tmp/valid-calendar.log" >/dev/null
    if CATFOOD_HOST_CELL_NOW=invalid-clock \
        sh followers/manage.sh host-matrix > "$tmp/ignored-clock.log" 2>&1; then
        echo 'caller clock metadata manufactured runtime eligibility' >&2
        exit 1
    fi
    grep -F 'independently qualified host runtime object is unavailable' "$tmp/ignored-clock.log" >/dev/null
    awk -F '\t' -v OFS='\t' '$1=="sdf-greased" {$17="current"; $19="revoked"; $20="accepted"} {print}' \
        "$tmp/host-cells-good.tsv" > followers/host-cells.tsv
    if sh followers/manage.sh host-matrix >/dev/null 2>&1; then
        echo 'revoked qualification was reused as acceptance' >&2
        exit 1
    fi
    awk -F '\t' -v OFS='\t' '$1=="sdf-greased" {$1="android-glibc"; $2="phone"; $3="no"; $4="runtime"; $5="fixture"; $6="Android"; $7="14"; $8="armv7"; $9="armeabi-v7a"; $10="glibc"; $11="termux-runtime"; $12="SC9863A"} {print}' \
        "$tmp/host-cells-good.tsv" > followers/host-cells.tsv
    if sh followers/manage.sh host-matrix >/dev/null 2>&1; then
        echo 'Android target accepted a glibc host cell' >&2
        exit 1
    fi
    awk -F '\t' '$1!="sdf-greased" {print}' \
        "$tmp/host-cells-good.tsv" > followers/host-cells.tsv
    if sh followers/manage.sh host-matrix >/dev/null 2>&1; then
        echo 'removing a required SDF cell preserved a green denominator' >&2
        exit 1
    fi
    awk -F '\t' -v OFS='\t' '$1=="sdf-greasecpp" {$19="eligible"} {print}' \
        "$tmp/host-cells-good.tsv" > followers/host-cells.tsv
    if sh followers/manage.sh host-matrix >/dev/null 2>&1; then
        echo 'historical C++ Grease evidence became eligible' >&2
        exit 1
    fi
    for promotion in permanent-only accepted-only; do
        awk -F '\t' -v OFS='\t' -v promotion="$promotion" '
            $1=="sdf-greasecpp" {
                if (promotion=="permanent-only") $17="permanent"
                if (promotion=="accepted-only") {$17="current"; $20="accepted"}
            }
            {print}
        ' "$tmp/host-cells-good.tsv" > followers/host-cells.tsv
        if sh followers/manage.sh host-matrix > "$tmp/runtime-promotion-$promotion.log" 2>&1; then
            printf 'standalone host runtime claim bypassed missing authority: %s\n' "$promotion" >&2
            exit 1
        fi
        grep -F 'independently qualified host runtime object is unavailable' \
            "$tmp/runtime-promotion-$promotion.log" >/dev/null
    done
    for bypass in renamed-implementation changed-source changed-artifact; do
        awk -F '\t' -v OFS='\t' -v bypass="$bypass" '
            $1=="sdf-greasecpp" {
                $5="native-engine"; $17="permanent"; $19="eligible"; $20="accepted"
                if (bypass=="changed-source") $14="1111111111111111111111111111111111111111"
                if (bypass=="changed-artifact") {
                    $15="native-engine.tar.gz"
                    $16="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
                }
            }
            {print}
        ' "$tmp/host-cells-good.tsv" > followers/host-cells.tsv
        if sh followers/manage.sh host-matrix > "$tmp/runtime-promotion-$bypass.log" 2>&1; then
            printf 'host runtime promotion bypassed missing authority: %s\n' "$bypass" >&2
            exit 1
        fi
        grep -F 'independently qualified host runtime object is unavailable' \
            "$tmp/runtime-promotion-$bypass.log" >/dev/null
    done
    awk -F '\t' -v OFS='\t' '$1=="void-current" {$17="current"; $19="eligible"; $20="accepted"} {print}' \
        "$tmp/host-cells-good.tsv" > followers/host-cells.tsv
    if sh followers/manage.sh host-matrix >/dev/null 2>&1; then
        echo 'unknown Void scope became an accepted requirement' >&2
        exit 1
    fi
    cp "$tmp/host-cells-good.tsv" followers/host-cells.tsv
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
    cat > "$tmp/github-host-receipt.tsv" <<EOF_HOST_RECEIPT
schema	catfood-host-receipt-v1
job_id	$id
repository	isomorphisms/catfood
host_target	github-x86_64
observed_os	Linux
observed_release	Ubuntu-24.04
observed_architecture	x86_64
observed_abi	x86_64-linux-gnu
observed_libc	glibc
runtime_identity	github-hosted-runtime
cpu_identity	fixture-x86-64-cpu
observed_account	fixture-user
observed_hostname	fixture-host
storage_identity	fixture-device:/fixture
source_revision	$trigger
evidence_kind	runtime
qualification_state	current
observation_kind	live
artifact_available_until	not-applicable
EOF_HOST_RECEIPT
    sed 's/^host_target\tgithub-x86_64$/host_target\thetzner-x86_64/' \
        "$tmp/github-host-receipt.tsv" > "$tmp/wrong-target-host-receipt.tsv"
    if AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        record "$id" "$tmp/github-receipt.tsv" \
        "$tmp/wrong-target-host-receipt.tsv" >/dev/null 2>&1; then
        echo 'GitHub evidence was reused for the Hetzner target' >&2
        exit 1
    fi
    sed 's/^runtime_identity\tgithub-hosted-runtime$/runtime_identity\tpersistent-host-runtime/' \
        "$tmp/github-host-receipt.tsv" > "$tmp/wrong-runtime-host-receipt.tsv"
    if AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        record "$id" "$tmp/github-receipt.tsv" \
        "$tmp/wrong-runtime-host-receipt.tsv" >/dev/null 2>&1; then
        echo 'wrong host runtime identity was accepted' >&2
        exit 1
    fi
    cp -R followers/jobs "$tmp/jobs-before-host-record-refusal"
    cp -R followers/receipts "$tmp/receipts-before-host-record-refusal"
    for duplicate_key in source_revision observation_kind schema job_id \
        repository host_target evidence_kind qualification_state identical-source malformed-source
    do
        cp "$tmp/github-host-receipt.tsv" "$tmp/duplicate-host-receipt.tsv"
        case $duplicate_key in
            identical-source)
                printf 'source_revision\t%s\n' "$trigger" >> "$tmp/duplicate-host-receipt.tsv" ;;
            malformed-source)
                awk -F '\t' -v OFS='\t' '$1=="source_revision" {$3="extra-value"} {print}' \
                    "$tmp/github-host-receipt.tsv" > "$tmp/duplicate-host-receipt.tsv" ;;
            *) printf '%s\tconflicting-value\n' "$duplicate_key" >> "$tmp/duplicate-host-receipt.tsv" ;;
        esac
        if AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
            record "$id" "$tmp/github-receipt.tsv" \
            "$tmp/duplicate-host-receipt.tsv" > "$tmp/duplicate-host-record.log" 2>&1; then
            if AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
                host-reconcile "$trigger" > "$tmp/duplicate-host-reconcile.log" 2>&1; then
                printf 'duplicate host field was admitted and accepted by reconciliation: %s\n' "$duplicate_key" >&2
            fi
            printf 'duplicate host field was admitted: %s\n' "$duplicate_key" >&2
            exit 1
        fi
        diff -r "$tmp/jobs-before-host-record-refusal" followers/jobs >/dev/null
        diff -r "$tmp/receipts-before-host-record-refusal" followers/receipts >/dev/null
        [ ! -e followers/host-receipts ] || {
            echo 'rejected host receipt created canonical host material' >&2
            exit 1
        }
    done
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        record "$id" "$tmp/github-receipt.tsv" \
        "$tmp/github-host-receipt.tsv" >/dev/null
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh host-reconcile "$trigger" >/dev/null
    cp -R followers/jobs "$tmp/jobs-before-host-reconcile-refusal"
    cp -R followers/receipts "$tmp/receipts-before-host-reconcile-refusal"
    for duplicate_key in source_revision observation_kind schema job_id \
        repository host_target evidence_kind qualification_state identical-source malformed-source
    do
        cp "$tmp/github-host-receipt.tsv" "followers/host-receipts/$id.tsv"
        case $duplicate_key in
            identical-source)
                printf 'source_revision\t%s\n' "$trigger" >> "followers/host-receipts/$id.tsv" ;;
            malformed-source)
                awk -F '\t' -v OFS='\t' '$1=="source_revision" {$3="extra-value"} {print}' \
                    "$tmp/github-host-receipt.tsv" > "followers/host-receipts/$id.tsv" ;;
            *) printf '%s\tconflicting-value\n' "$duplicate_key" >> "followers/host-receipts/$id.tsv" ;;
        esac
        cp "followers/host-receipts/$id.tsv" "$tmp/host-receipt-before-reconcile.tsv"
        if AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
            host-reconcile "$trigger" > "$tmp/duplicate-host-reconcile.log" 2>&1; then
            printf 'host reconciliation accepted a duplicate field: %s\n' "$duplicate_key" >&2
            exit 1
        fi
        diff -r "$tmp/jobs-before-host-reconcile-refusal" followers/jobs >/dev/null
        diff -r "$tmp/receipts-before-host-reconcile-refusal" followers/receipts >/dev/null
        cmp "$tmp/host-receipt-before-reconcile.tsv" "followers/host-receipts/$id.tsv"
    done
    cp "$tmp/github-host-receipt.tsv" "followers/host-receipts/$id.tsv"
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh host-reconcile "$trigger" >/dev/null
    # A named artifact has a real acquisition deadline. A caller-supplied past
    # clock must not revive it during admission or accepted-state reconciliation.
    cp "followers/jobs/$id.tsv" "$tmp/original-host-job.tsv"
    cp "followers/receipts/$id.tsv" "$tmp/original-host-receipt.tsv"
    cp "followers/host-receipts/$id.tsv" "$tmp/original-host-sidecar.tsv"
    awk -F '\t' -v OFS='\t' '
        $1=="artifact" {$2="fixture-host-runtime.tar.gz"}
        $1=="artifact_sha256" {$2="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
        {print}
    ' "$tmp/original-host-job.tsv" > "followers/jobs/$id.tsv"
    awk -F '\t' -v OFS='\t' '
        $1=="artifact" {$2="fixture-host-runtime.tar.gz"}
        $1=="artifact_sha256" {$2="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
        {print}
    ' "$tmp/github-receipt.tsv" > "$tmp/artifact-receipt.tsv"
    sed 's/^artifact_available_until.*/artifact_available_until\t2000-01-01T00:00:00Z/' \
        "$tmp/github-host-receipt.tsv" > "$tmp/expired-host-artifact.tsv"
    cp -R followers/jobs "$tmp/jobs-before-expired-host-record"
    cp -R followers/receipts "$tmp/receipts-before-expired-host-record"
    cp -R followers/host-receipts "$tmp/host-receipts-before-expired-host-record"
    if CATFOOD_HOST_CELL_NOW=1900-01-01T00:00:00Z AICI_FOLLOWERS="$verifier" \
        sh followers/manage.sh record "$id" "$tmp/artifact-receipt.tsv" \
        "$tmp/expired-host-artifact.tsv" > "$tmp/expired-host-record.log" 2>&1; then
        if CATFOOD_HOST_CELL_NOW=1900-01-01T00:00:00Z AICI_FOLLOWERS="$verifier" \
            sh followers/manage.sh host-reconcile "$trigger" > "$tmp/expired-host-reconcile.log" 2>&1; then
            echo 'caller clock admitted an expired artifact and accepted host reconciliation' >&2
        fi
        echo 'caller clock admitted an expired host artifact receipt' >&2
        exit 1
    fi
    grep -F 'artifact availability expired' "$tmp/expired-host-record.log" >/dev/null
    diff -r "$tmp/jobs-before-expired-host-record" followers/jobs >/dev/null
    diff -r "$tmp/receipts-before-expired-host-record" followers/receipts >/dev/null
    diff -r "$tmp/host-receipts-before-expired-host-record" followers/host-receipts >/dev/null
    sed 's/^artifact_available_until.*/artifact_available_until\t9996-02-29T00:00:00Z/' \
        "$tmp/github-host-receipt.tsv" > "$tmp/future-host-artifact.tsv"
    CATFOOD_HOST_CELL_NOW=9999-01-01T00:00:00Z AICI_FOLLOWERS="$verifier" \
        sh followers/manage.sh record "$id" "$tmp/artifact-receipt.tsv" \
        "$tmp/future-host-artifact.tsv" >/dev/null
    CATFOOD_HOST_CELL_NOW=9999-01-01T00:00:00Z AICI_FOLLOWERS="$verifier" \
        sh followers/manage.sh host-reconcile "$trigger" >/dev/null
    cp -R followers/jobs "$tmp/jobs-before-expired-host-reconcile"
    cp -R followers/receipts "$tmp/receipts-before-expired-host-reconcile"
    cp "$tmp/expired-host-artifact.tsv" "followers/host-receipts/$id.tsv"
    if CATFOOD_HOST_CELL_NOW=1900-01-01T00:00:00Z AICI_FOLLOWERS="$verifier" \
        sh followers/manage.sh host-reconcile "$trigger" > "$tmp/expired-host-reconcile.log" 2>&1; then
        echo 'caller clock revived an expired accepted host artifact' >&2
        exit 1
    fi
    grep -F 'artifact availability expired' "$tmp/expired-host-reconcile.log" >/dev/null
    diff -r "$tmp/jobs-before-expired-host-reconcile" followers/jobs >/dev/null
    diff -r "$tmp/receipts-before-expired-host-reconcile" followers/receipts >/dev/null
    cmp "$tmp/expired-host-artifact.tsv" "followers/host-receipts/$id.tsv"
    cp "$tmp/original-host-job.tsv" "followers/jobs/$id.tsv"
    cp "$tmp/original-host-receipt.tsv" "followers/receipts/$id.tsv"
    cp "$tmp/original-host-sidecar.tsv" "followers/host-receipts/$id.tsv"
    sh followers/manage.sh host-matrix "$trigger" > "$tmp/host-matrix-recorded.tsv"
    awk -F '\t' -v id="$id" '$1==id {
        if ($4!="follower" || $19!="unknown" || $20!="accepted") exit 1
        found=1
    } END {if (!found) exit 1}' "$tmp/host-matrix-recorded.tsv"
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
    [ "$(find followers/jobs -name '*.tsv' -type f | wc -l | tr -d ' ')" -eq 7 ]
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
    [ "$(printf '%s\n' "$android_affected" | wc -l | tr -d ' ')" -eq 4 ]
    printf '%s\n' "$android_affected" | grep '^phone[[:space:]].*physical-device' >/dev/null
    printf '%s\n' "$android_affected" | grep '^c67[[:space:]].*physical-device' >/dev/null
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
        "$root/followers/host-cells.tsv" \
        "$destination/followers/"
    cat > "$destination/catfood" <<'EOF_CATFOOD'
#!/bin/sh
if [ "${1:-}" = --target ]; then
    printf '%s\n' "${CATFOOD_TARGET:-cloud}"
fi
EOF_CATFOOD
    chmod +x "$destination/catfood"
    for name in entrypoint targets android-delivery ib-handoff; do
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


# A commit that only records documentation/device observations is not a new
# runtime or physical-acceptance source trigger.
noimpact_fixture=$tmp/noimpact-repo
make_integration_fixture "$noimpact_fixture"
(
    cd "$noimpact_fixture"
    git init -q
    git config user.email follower-test@example.invalid
    git config user.name follower-test
    git add .
    git commit -qm base

    printf '%s\n' '# source change' >> provision.sh
    printf '%s\n' '# original artifact change' >> android/install-example.sh
    git add provision.sh android/install-example.sh
    git commit -qm source
    source_trigger=$(git rev-parse HEAD)
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        prepare "$source_trigger" phone armv7 - noimpact 1 >/dev/null
    git add followers
    git commit -qm follower-ledger

    mkdir -p android/devices docs/observations
    printf '%s\n' '# Android notes only' > android/README.md
    printf '%s\n' '# device profile only' > android/devices/fixture.md
    printf '%s\n' '# observed handset and downloaded-file location only' > android/device-instance-and-artifact-location.md
    printf '%s\n' 'kind\tvalue' 'observation\tfixture' > docs/observations/fixture.tsv
    git add android/README.md android/devices/fixture.md android/device-instance-and-artifact-location.md docs/observations/fixture.tsv
    git commit -qm observation-evidence
    evidence_commit=$(git rev-parse HEAD)

    affected=$(sh followers/manage.sh affected "$evidence_commit")
    [ -z "$affected" ] || {
        echo 'no-impact evidence commit must not become a follower trigger' >&2
        exit 1
    }
    [ "$(sh followers/manage.sh latest)" = "$source_trigger" ] || {
        echo 'no-impact evidence commit must not become a follower trigger' >&2
        exit 1
    }
    [ "$(sh followers/manage.sh resolve "$evidence_commit")" = "$source_trigger" ] || {
        echo 'no-impact evidence commit must preserve exact source-state resolution' >&2
        exit 1
    }
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh reconcile "$(sh followers/manage.sh latest)" >/dev/null

    # Later portable source has six successors, while the unchanged artifact
    # obligation remains pending at its own exact source. Observation prose
    # must not turn it into a missing seventh successor at the portable head.
    printf '%s\n' '# later portable source' >> provision.sh
    git add provision.sh
    git commit -qm portable-successor
    portable_trigger=$(git rev-parse HEAD)
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        prepare "$portable_trigger" phone armv7 - noimpact 2 >/dev/null
    [ "$(sh followers/manage.sh affected "$portable_trigger" | wc -l | tr -d ' ')" -eq 6 ]
    [ "$(sh followers/manage.sh stale-target "$source_trigger" "$portable_trigger" github-x86_64-artifact)" = no ]
    sh followers/manage.sh supersede-ancestors "$portable_trigger" >/dev/null
    sh followers/stale.sh >/dev/null
    old_artifact=followers/jobs/catfood-$(printf '%s' "$source_trigger" | cut -c1-12)-github-x86_64-artifact.tsv
    awk -F '\t' -v source="$source_trigger" \
        '$1=="state" {pending=$2=="pending"} $1=="trigger_commit" {exact=$2==source} END {exit !(pending && exact)}' "$old_artifact"

    # A real install payload change still renews artifact validation. Refuse a
    # missing same-target successor before changing any ancestor job, even if
    # other valid supersessions were already planned.
    printf '%s\n' '# genuine Android install payload change' >> android/install-example.sh
    git add android/install-example.sh
    git commit -qm artifact-successor
    artifact_trigger=$(git rev-parse HEAD)
    AICI_FOLLOWERS="$verifier" sh followers/manage.sh \
        prepare "$artifact_trigger" phone armv7 - noimpact 3 >/dev/null
    [ "$(sh followers/manage.sh stale-target "$source_trigger" "$artifact_trigger" github-x86_64-artifact)" = yes ]
    artifact_successor=followers/jobs/catfood-$(printf '%s' "$artifact_trigger" | cut -c1-12)-github-x86_64-artifact.tsv
    mv "$artifact_successor" "$tmp/artifact-successor.hold"
    cp -R followers/jobs "$tmp/jobs-before-refusal"
    if sh followers/manage.sh supersede-ancestors "$artifact_trigger" > "$tmp/missing-artifact.log" 2>&1; then
        echo 'missing artifact successor was accepted' >&2
        exit 1
    fi
    grep -F 'has no same-target successor' "$tmp/missing-artifact.log" >/dev/null
    diff -r "$tmp/jobs-before-refusal" followers/jobs >/dev/null
    mv "$tmp/artifact-successor.hold" "$artifact_successor"
    sh followers/manage.sh supersede-ancestors "$artifact_trigger" >/dev/null
    sh followers/stale.sh >/dev/null
    expected_successor=$(basename "$artifact_successor" .tsv)
    awk -F '\t' -v successor="$expected_successor" \
        '$1=="state" {retired=$2=="superseded"} $1=="superseded_by" {exact=$2==successor} END {exit !(retired && exact)}' "$old_artifact"
    awk -F '\t' '$1=="state" {exit $2!="pending"}' "$artifact_successor"
)

printf '%s\n' 'cat food follower inference self-test passes'
