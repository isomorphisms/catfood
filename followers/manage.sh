#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
targets=$root/followers/targets.tsv
rules=$root/followers/impact-rules.tsv
host_cells=$root/followers/host-cells.tsv
jobs=$root/followers/jobs
receipts=$root/followers/receipts
host_receipts=$root/followers/host-receipts

fatal() { printf 'followers: %s\n' "$*" >&2; exit 1; }
tab=$(printf '\t')

record_value() {
    file=$1 key=$2
    awk -F '\t' -v key="$key" '$1 == key { if (seen++) exit 2; value=$2 } END { if (!seen) exit 1; print value }' "$file"
}

scope_matches() {
    expected=$1 observed=$2
    case $expected in
        observed-at-run)
            case $observed in ''|-|unknown|unknown-current) return 1 ;; esac
            ;;
        unknown-current)
            [ "$observed" = unknown-current ] || return 1
            ;;
        *)
            [ "$expected" = "$observed" ] || return 1
            ;;
    esac
}

target_field() {
    target=$1 field=$2
    target_line "$target" | awk -F '\t' -v field="$field" '{print $field}'
}

cell_line() {
    cell=$1
    awk -F '\t' -v cell="$cell" '
        $1 !~ /^#/ && $1 == cell { if (found++) exit 2; line=$0 }
        END { if (!found) exit 1; print line }
    ' "$host_cells"
}

host_cell_records_check() {
    [ -f "$host_cells" ] || fatal "missing host-cell records: $host_cells"
    awk -F '\t' '
        $1 ~ /^#/ { next }
        NF != 21 { print "host cell " $1 " has " NF " fields, expected 21" > "/dev/stderr"; exit 2 }
        seen[$1]++ { print "duplicate host cell " $1 > "/dev/stderr"; exit 2 }
    ' "$host_cells" || fatal 'invalid host-cell record shape'

    while IFS="$tab" read -r cell target required component implementation \
        host_os host_release architecture abi libc runtime cpu repository \
        source_revision artifact artifact_sha256 availability evidence_kind \
        eligibility disposition evidence_ref
    do
        case $cell in ''|'#'*) continue ;; esac
        line=$(target_line "$target") || fatal "host cell $cell names unknown target $target"
        concrete=$(printf '%s\n' "$line" | awk -F '\t' '{print $7}')
        maintenance=$(printf '%s\n' "$line" | awk -F '\t' '{print $14}')
        target_arch=$(printf '%s\n' "$line" | awk -F '\t' '{print $3}')
        target_os=$(printf '%s\n' "$line" | awk -F '\t' '{print $8}')
        target_release=$(printf '%s\n' "$line" | awk -F '\t' '{print $9}')
        target_abi=$(printf '%s\n' "$line" | awk -F '\t' '{print $10}')
        target_libc=$(printf '%s\n' "$line" | awk -F '\t' '{print $11}')
        target_runtime=$(printf '%s\n' "$line" | awk -F '\t' '{print $12}')
        target_cpu=$(printf '%s\n' "$line" | awk -F '\t' '{print $13}')

        scope_matches "$target_os" "$host_os" ||
            fatal "host cell $cell OS $host_os does not match $target"
        scope_matches "$target_release" "$host_release" ||
            fatal "host cell $cell release $host_release does not match $target"
        scope_matches "$target_arch" "$architecture" ||
            fatal "host cell $cell architecture $architecture does not match $target"
        scope_matches "$target_abi" "$abi" ||
            fatal "host cell $cell ABI $abi does not match $target"
        scope_matches "$target_libc" "$libc" ||
            fatal "host cell $cell libc $libc does not match $target"
        scope_matches "$target_runtime" "$runtime" ||
            fatal "host cell $cell runtime $runtime does not match $target"
        scope_matches "$target_cpu" "$cpu" ||
            fatal "host cell $cell CPU $cpu does not match $target"

        case $required in
            yes)
                [ "$concrete" = yes ] && [ "$maintenance" = yes ] ||
                    fatal "required host cell $cell is not backed by a maintained concrete target"
                ;;
            conditional)
                [ "$maintenance" = conditional ] ||
                    fatal "conditional host cell $cell lacks conditional target authority"
                ;;
            no) ;;
            *) fatal "host cell $cell has invalid required value $required" ;;
        esac
        case $source_revision in
            *[!0123456789abcdef]*|'') fatal "host cell $cell has invalid source revision" ;;
        esac
        [ "${#source_revision}" -eq 40 ] ||
            fatal "host cell $cell source revision is not a full commit"
        if [ "$artifact_sha256" != - ]; then
            case $artifact_sha256 in
                *[!0123456789abcdef]*|'') fatal "host cell $cell has invalid artifact SHA-256" ;;
            esac
            [ "${#artifact_sha256}" -eq 64 ] ||
                fatal "host cell $cell artifact SHA-256 has the wrong length"
            [ "$artifact" != - ] || fatal "host cell $cell hashes an unnamed artifact"
        fi
        case $implementation in
            *cpp*|*c++*|*cxx*)
                [ "$eligibility" = ineligible ] ||
                    fatal "C++ host cell $cell must remain ineligible"
                ;;
        esac
        if [ "$disposition" = accepted ]; then
            [ "$eligibility" = eligible ] ||
                fatal "host cell $cell accepted without eligible material"
            for material in "$host_os" "$host_release" "$architecture" "$abi" \
                "$libc" "$runtime" "$cpu"
            do
                case $material in
                    ''|-|unknown|unknown-current|observed-at-run)
                        fatal "host cell $cell accepted with unresolved scope $material"
                        ;;
                esac
            done
            case $evidence_kind in
                branch|ci-label|source-presence)
                    fatal "host cell $cell accepted from $evidence_kind"
                    ;;
            esac
            case $availability in
                permanent|current) ;;
                until:*)
                    expiry=${availability#until:}
                    case $expiry in
                        ????-??-??T??:??:??Z) ;;
                        *) fatal "host cell $cell has invalid availability timestamp $expiry" ;;
                    esac
                    now=${CATFOOD_HOST_CELL_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
                    [ "$expiry" \> "$now" ] ||
                        fatal "host cell $cell accepted an expired artifact"
                    ;;
                *) fatal "host cell $cell accepted without current acquisition material" ;;
            esac
        fi
        [ "$eligibility" != revoked ] || [ "$disposition" != accepted ] ||
            fatal "host cell $cell reused a revoked qualification"
        case $evidence_ref in
            http://*|https://*|followers/*) ;;
            *) fatal "host cell $cell has an uninspectable evidence reference" ;;
        esac
        : "$component" "$repository"
    done < "$host_cells"

    while IFS="$tab" read -r target platform architecture profile kind action \
        concrete host_os host_release host_abi host_libc host_runtime host_cpu \
        maintenance required_cells
    do
        case $target in ''|'#'*) continue ;; esac
        [ -n "$required_cells" ] || fatal "target $target lacks required_host_cells"
        [ "$required_cells" != - ] || continue
        oldifs=$IFS
        IFS=,
        for cell in $required_cells; do
            IFS=$oldifs
            record=$(cell_line "$cell") ||
                fatal "target $target requires missing host cell $cell"
            record_target=$(printf '%s\n' "$record" | awk -F '\t' '{print $2}')
            [ "$record_target" = "$target" ] ||
                fatal "required host cell $cell belongs to $record_target, not $target"
            record_required=$(printf '%s\n' "$record" | awk -F '\t' '{print $3}')
            case $maintenance in
                yes)
                    [ "$record_required" = yes ] ||
                        fatal "maintained target $target does not require host cell $cell"
                    ;;
                conditional)
                    [ "$record_required" = conditional ] ||
                        fatal "conditional target $target does not conditionally require host cell $cell"
                    ;;
            esac
            IFS=,
        done
        IFS=$oldifs
        : "$platform" "$architecture" "$profile" "$kind" "$action" "$concrete" \
            "$host_os" "$host_release" "$host_abi" "$host_libc" "$host_runtime" \
            "$host_cpu" "$maintenance"
    done < "$targets"
}

receipt_nonempty() {
    nonempty_file=$1 nonempty_key=$2
    nonempty_value=$(record_value "$nonempty_file" "$nonempty_key") ||
        fatal "$nonempty_file lacks host-cell field $nonempty_key"
    case $nonempty_value in ''|-|unknown|unknown-current)
        fatal "$nonempty_file has unresolved host-cell field $nonempty_key"
        ;;
    esac
    printf '%s\n' "$nonempty_value"
}

validate_host_receipt() {
    job=$1 receipt=$2 host_receipt=$3 target=$4
    [ -f "$receipt" ] || fatal "accepted host job lacks receipt: $receipt"
    [ -f "$host_receipt" ] || fatal "accepted host job lacks host receipt: $host_receipt"
    expected_target=$(record_value "$job" follower_platform)
    [ "$expected_target" = "$target" ] || fatal "$job target changed during host validation"
    [ "$(record_value "$host_receipt" schema)" = catfood-host-receipt-v1 ] ||
        fatal "$host_receipt has the wrong host receipt schema"
    [ "$(record_value "$host_receipt" job_id)" = "$(record_value "$job" job_id)" ] ||
        fatal "$host_receipt does not name $job"
    [ "$(record_value "$host_receipt" repository)" = "$(record_value "$job" repository)" ] ||
        fatal "$host_receipt repository does not match $job"
    [ "$(record_value "$host_receipt" host_target)" = "$target" ] ||
        fatal "$host_receipt cannot be reused for host target $target"

    observed_os=$(receipt_nonempty "$host_receipt" observed_os)
    observed_release=$(receipt_nonempty "$host_receipt" observed_release)
    observed_arch=$(receipt_nonempty "$host_receipt" observed_architecture)
    observed_abi=$(receipt_nonempty "$host_receipt" observed_abi)
    observed_libc=$(receipt_nonempty "$host_receipt" observed_libc)
    observed_runtime=$(receipt_nonempty "$host_receipt" runtime_identity)
    observed_cpu=$(receipt_nonempty "$host_receipt" cpu_identity)
    receipt_nonempty "$host_receipt" observed_account >/dev/null
    receipt_nonempty "$host_receipt" observed_hostname >/dev/null
    receipt_nonempty "$host_receipt" storage_identity >/dev/null

    scope_matches "$(target_field "$target" 8)" "$observed_os" ||
        fatal "$receipt OS cannot accept $target"
    scope_matches "$(target_field "$target" 9)" "$observed_release" ||
        fatal "$receipt release cannot accept $target"
    scope_matches "$(target_field "$target" 3)" "$observed_arch" ||
        fatal "$receipt architecture cannot accept $target"
    scope_matches "$(target_field "$target" 10)" "$observed_abi" ||
        fatal "$receipt ABI cannot accept $target"
    scope_matches "$(target_field "$target" 11)" "$observed_libc" ||
        fatal "$receipt libc cannot accept $target"
    scope_matches "$(target_field "$target" 12)" "$observed_runtime" ||
        fatal "$receipt runtime cannot accept $target"
    scope_matches "$(target_field "$target" 13)" "$observed_cpu" ||
        fatal "$receipt CPU cannot accept $target"

    trigger=$(record_value "$job" trigger_commit)
    [ "$(record_value "$host_receipt" source_revision)" = "$trigger" ] ||
        fatal "$host_receipt source revision does not match $job"
    [ "$(record_value "$host_receipt" evidence_kind)" = "$(record_value "$job" acceptance_kind)" ] ||
        fatal "$host_receipt evidence kind does not match $job"
    [ "$(record_value "$host_receipt" qualification_state)" = current ] ||
        fatal "$host_receipt qualification is not current"
    [ "$(record_value "$host_receipt" observation_kind)" = live ] ||
        fatal "$host_receipt is not a live host observation"
    [ "$(record_value "$receipt" artifact)" = "$(record_value "$job" artifact)" ] ||
        fatal "$receipt artifact does not match $job"
    [ "$(record_value "$receipt" artifact_sha256)" = "$(record_value "$job" artifact_sha256)" ] ||
        fatal "$receipt artifact digest does not match $job"

    availability=$(record_value "$host_receipt" artifact_available_until) ||
        fatal "$host_receipt lacks artifact availability"
    artifact=$(record_value "$job" artifact)
    if [ "$artifact" = - ]; then
        [ "$availability" = not-applicable ] ||
            fatal "$host_receipt invents availability for an artifact-free job"
    else
        case $availability in
            permanent) ;;
            *)
                case $availability in
                    ????-??-??T??:??:??Z) ;;
                    *) fatal "$host_receipt has invalid artifact availability $availability" ;;
                esac
                now=${CATFOOD_HOST_CELL_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
                [ "$availability" \> "$now" ] ||
                    fatal "$host_receipt artifact availability expired at $availability"
                ;;
        esac
    fi
}

host_target() {
    target=$1
    platform=$(target_field "$target" 2)
    [ "$platform" != android-termux ]
}

host_reconcile() {
    trigger=$1
    host_cell_records_check
    host_scratch=$(mktemp -d)
    trap 'rm -rf "$host_scratch"' EXIT HUP INT TERM
    affected "$trigger" > "$host_scratch/affected"
    trap 'rm -rf "$host_scratch"' EXIT HUP INT TERM
    while IFS="$tab" read -r target kind reason; do
        host_target "$target" || continue
        job_for "$trigger" "$target" >/dev/null ||
            fatal "host matrix is missing follower cell $trigger/$target ($reason)"
        : "$kind"
    done < "$host_scratch/affected"
    for file in "$jobs"/*.tsv; do
        [ -f "$file" ] || continue
        [ "$(record_value "$file" trigger_commit)" = "$trigger" ] || continue
        target=$(record_value "$file" follower_platform)
        host_target "$target" || continue
        state=$(record_value "$file" state)
        if [ "$state" = accepted ]; then
            evidence=$(record_value "$file" evidence)
            [ "$evidence" != - ] || fatal "$file claims accepted without evidence"
            validate_host_receipt "$file" "$receipts/$evidence" \
                "$host_receipts/$evidence" "$target"
        fi
    done
    rm -rf "$host_scratch"
    trap - EXIT HUP INT TERM
    printf 'host-cell reconciliation passes for %s\n' "$trigger"
}

host_matrix() {
    [ "$#" -le 1 ] || fatal 'host-matrix [TRIGGER]'
    host_cell_records_check
    trigger=${1:-}
    scratch=$(mktemp)
    trap 'rm -f "$scratch"' EXIT HUP INT TERM
    awk -F '\t' '$1 !~ /^#/ {print}' "$host_cells" > "$scratch"
    if [ -n "$trigger" ]; then
        trigger=$(resolve_trigger "$trigger")
        for file in "$jobs"/*.tsv; do
            [ -f "$file" ] || continue
            [ "$(record_value "$file" trigger_commit)" = "$trigger" ] || continue
            target=$(record_value "$file" follower_platform)
            host_target "$target" || continue
            state=$(record_value "$file" state)
            evidence=$(record_value "$file" evidence)
            availability=unknown
            evidence_ref=${file#"$root"/}
            if [ "$state" = accepted ]; then
                [ "$evidence" != - ] || fatal "$file claims accepted without evidence"
                receipt=$receipts/$evidence
                host_receipt=$host_receipts/$evidence
                validate_host_receipt "$file" "$receipt" "$host_receipt" "$target"
                availability=$(record_value "$host_receipt" artifact_available_until)
                evidence_ref=${host_receipt#"$root"/}
            fi
            line=$(target_line "$target")
            printf '%s\t%s\t%s\tfollower\tcatfood\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\teligible\t%s\t%s\n' \
                "$(record_value "$file" job_id)" "$target" "$(record_value "$file" required)" \
                "$(printf '%s\n' "$line" | awk -F '\t' '{print $8}')" \
                "$(printf '%s\n' "$line" | awk -F '\t' '{print $9}')" \
                "$(printf '%s\n' "$line" | awk -F '\t' '{print $3}')" \
                "$(printf '%s\n' "$line" | awk -F '\t' '{print $10}')" \
                "$(printf '%s\n' "$line" | awk -F '\t' '{print $11}')" \
                "$(printf '%s\n' "$line" | awk -F '\t' '{print $12}')" \
                "$(printf '%s\n' "$line" | awk -F '\t' '{print $13}')" \
                "$(record_value "$file" repository)" "$trigger" \
                "$(record_value "$file" artifact)" "$(record_value "$file" artifact_sha256)" \
                "$availability" "$(record_value "$file" acceptance_kind)" "$state" "$evidence_ref" \
                >> "$scratch"
        done
    fi
    printf '%s\n' '# cell_id	target	required	component	implementation	host_os	host_release	architecture	abi	libc	runtime	cpu	source_repository	source_revision	artifact	artifact_sha256	availability	evidence_kind	eligibility	disposition	evidence_ref'
    sort "$scratch"
    rm -f "$scratch"
    trap - EXIT HUP INT TERM
}

target_line() {
    target=$1
    awk -F '\t' -v target="$target" '$1 !~ /^#/ && $1 == target { print; found=1 } END { if (!found) exit 1 }' "$targets"
}

rule_for_path() {
    changed=$1
    while IFS="$tab" read -r match pattern followers reason; do
        case $match in ''|'#'*) continue ;; esac
        applies=no
        case $match in
            exact) [ "$changed" = "$pattern" ] && applies=yes ;;
            prefix) case $changed in "$pattern"*) applies=yes ;; esac ;;
            default) applies=yes ;;
            *) fatal "unknown impact rule $match" ;;
        esac
        if [ "$applies" = yes ]; then
            printf '%s\t%s\n' "$followers" "$reason"
            return 0
        fi
    done < "$rules"
    fatal "no impact rule for $changed"
}

changed_for_commit() {
    trigger=$1
    parents=$(git -C "$root" rev-list --parents -n 1 "$trigger") || fatal "unknown trigger $trigger"
    set -- $parents
    commit=$1
    shift
    if [ "$#" -eq 0 ]; then
        git -C "$root" diff-tree --root --no-commit-id --name-only -r "$commit"
    else
        first_parent=$1
        git -C "$root" diff --name-only "$first_parent" "$commit"
    fi
}

affected() {
    trigger=$1
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT HUP INT TERM
    changed_for_commit "$trigger" > "$tmp/paths" || fatal "cannot inspect trigger $trigger"
    affected_paths "$tmp/paths" "$tmp"
    rm -rf "$tmp"
    trap - EXIT HUP INT TERM
}

affected_paths() {
    paths=$1 scratch=$2
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        control_path "$path" && continue
        rule_for_path "$path"
    done < "$paths" > "$scratch/rules"
    while IFS="$tab" read -r follower reason; do
        [ "$follower" != - ] || continue
        oldifs=$IFS
        IFS=,
        for target in $follower; do
            IFS=$oldifs
            line=$(target_line "$target") || fatal "impact rule names unknown target $target"
            kind=$(printf '%s\n' "$line" | awk -F '\t' '{print $5}')
            printf '%s\t%s\t%s\n' "$target" "$kind" "$reason"
            IFS=,
        done
        IFS=$oldifs
    done < "$scratch/rules" > "$scratch/targets"
    sort -u "$scratch/targets"
}

# This retains the old exact obligation, never acceptance of a newer revision.
stale_target() {
    [ "$#" -eq 3 ] || fatal 'stale-target OLD CURRENT TARGET'
    old_trigger=$1 current_trigger=$2 follow_target=$3
    target_line "$follow_target" >/dev/null || fatal "unknown target $follow_target"
    [ "$(git -C "$root" rev-parse --is-shallow-repository)" = false ] || fatal 'full history is required to classify follower impact'
    git -C "$root" cat-file -e "${old_trigger}^{commit}" || fatal "unknown trigger $old_trigger"
    git -C "$root" cat-file -e "${current_trigger}^{commit}" || fatal "unknown trigger $current_trigger"
    if [ "$old_trigger" = "$current_trigger" ]; then printf 'no\n'; return; fi
    if git -C "$root" merge-base --is-ancestor "$old_trigger" "$current_trigger"; then
        :
    else
        ancestry_status=$?
        [ "$ancestry_status" -eq 1 ] || fatal 'cannot establish follower ancestry'
        printf 'no\n'
        return
    fi
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT HUP INT TERM
    # A changed policy cannot retroactively prove that an old target was unaffected.
    for policy in followers/impact-rules.tsv followers/targets.tsv; do
        if ! git -C "$root" show "$old_trigger:$policy" > "$tmp/old-policy" ||
            ! git -C "$root" show "$current_trigger:$policy" > "$tmp/current-policy" ||
            ! cmp -s "$tmp/old-policy" "$tmp/current-policy" ||
            ! cmp -s "$tmp/current-policy" "$root/$policy"; then
            printf 'yes\n'
            rm -rf "$tmp"
            trap - EXIT HUP INT TERM
            return
        fi
    done
    git -C "$root" diff --name-only "$old_trigger" "$current_trigger" > "$tmp/paths" || fatal 'cannot inspect follower source difference'
    affected_paths "$tmp/paths" "$tmp" > "$tmp/affected"
    awk -F '\t' -v target="$follow_target" '$1==target {found=1} END {print found ? "yes" : "no"}' "$tmp/affected"
    rm -rf "$tmp"
    trap - EXIT HUP INT TERM
}

control_path() {
    case $1 in
        followers/*|AGENTS.md|docs/followers.md|tests/followers.sh|.github/workflows/followers.yml|android/README.md|android/devices/*|docs/observations/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

latest_source_from() {
    start=$1
    tmp=$(mktemp)
    for candidate in $(git -C "$root" rev-list --first-parent "$start"); do
        changed_for_commit "$candidate" > "$tmp"
        while IFS= read -r path; do
            [ -n "$path" ] || continue
            if ! control_path "$path"; then
                rm -f "$tmp"
                printf '%s\n' "$candidate"
                return 0
            fi
        done < "$tmp"
    done
    rm -f "$tmp"
    fatal "no source-changing commit found on first-parent history from $start"
}

latest_source() {
    latest_source_from HEAD
}

job_for() {
    trigger=$1 target=$2
    for file in "$jobs"/*.tsv; do
        [ -f "$file" ] || continue
        [ "$(record_value "$file" trigger_commit)" = "$trigger" ] || continue
        [ "$(record_value "$file" follower_platform)" = "$target" ] || continue
        printf '%s\n' "$file"
        return 0
    done
    return 1
}

trigger_has_jobs() {
    trigger=$1
    for file in "$jobs"/*.tsv; do
        [ -f "$file" ] || continue
        [ "$(record_value "$file" trigger_commit)" = "$trigger" ] || continue
        return 0
    done
    return 1
}

job_triggers() {
    for file in "$jobs"/*.tsv; do
        [ -f "$file" ] || continue
        record_value "$file" trigger_commit
    done | sort -u
}

same_source_state() {
    left=$1 right=$2
    git -C "$root" cat-file -e "${left}^{commit}" 2>/dev/null || return 1
    git -C "$root" cat-file -e "${right}^{commit}" 2>/dev/null || return 1
    git -C "$root" diff --quiet "$left" "$right" -- . \
        ':(exclude)followers/**' \
        ':(exclude)AGENTS.md' \
        ':(exclude)docs/followers.md' \
        ':(exclude)tests/followers.sh' \
        ':(exclude).github/workflows/followers.yml' \
        ':(exclude)android/README.md' \
        ':(exclude)android/devices/**' \
        ':(exclude)docs/observations/**'
}

resolve_trigger() {
    [ "$#" -eq 1 ] || fatal 'resolve TRIGGER'
    requested=$1
    git -C "$root" cat-file -e "${requested}^{commit}" 2>/dev/null || fatal "unknown trigger $requested"

    if trigger_has_jobs "$requested"; then
        printf '%s\n' "$requested"
        return 0
    fi

    matches=$(mktemp)
    for candidate in $(job_triggers); do
        [ "$candidate" != "$requested" ] || continue
        if same_source_state "$candidate" "$requested"; then
            printf '%s\n' "$candidate" >> "$matches"
        fi
    done

    count=$(wc -l < "$matches" | tr -d ' ')
    case $count in
        1)
            cat "$matches"
            rm -f "$matches"
            ;;
        0)
            rm -f "$matches"
            fatal "no follower records establish the leader for $requested, and no exact follower trigger has identical non-control source state"
            ;;
        *)
            candidates=$(tr '\n' ' ' < "$matches")
            rm -f "$matches"
            fatal "multiple follower triggers have the same non-control source state as $requested: $candidates"
            ;;
    esac
}

prepare() {
    [ "$#" -ge 4 ] || fatal 'prepare TRIGGER LEADER_TARGET LEADER_ARCH LEADER_EVIDENCE [BRANCH] [PR]'
    trigger=$1 leader=$2 leader_arch=$3 leader_evidence=$4
    branch=${5:-$(git -C "$root" branch --show-current)}
    pr=${6:--}
    [ -n "$branch" ] || branch=-
    target_line "$leader" >/dev/null || fatal "unknown leader target $leader"
    mkdir -p "$jobs" "$receipts"
    short=$(printf '%s' "$trigger" | cut -c1-12)
    affected "$trigger" | while IFS="$tab" read -r target kind reason; do
        if job_for "$trigger" "$target" >/dev/null 2>&1; then
            continue
        fi
        line=$(target_line "$target") || fatal "unknown target $target"
        arch=$(printf '%s\n' "$line" | awk -F '\t' '{print $3}')
        action=$(printf '%s\n' "$line" | awk -F '\t' '{print $6}')
        id=catfood-$short-$target
        state=pending
        evidence=-
        role=follower
        if [ "$target" = "$leader" ]; then
            role=leader
            if [ "$leader_evidence" != - ] && [ -f "$receipts/$leader_evidence" ]; then
                state=accepted
                evidence=$leader_evidence
            fi
        fi
        cat > "$jobs/$id.tsv" <<EOF_JOB
schema	aici-follower-job-v1
job_id	$id
repository	isomorphisms/catfood
branch	$branch
pr	$pr
trigger_commit	$trigger
leader_platform	$leader
leader_arch	$leader_arch
leader_evidence	$leader_evidence
artifact	${CATFOOD_FOLLOWER_ARTIFACT:--}
artifact_sha256	${CATFOOD_FOLLOWER_ARTIFACT_SHA256:--}
follower_platform	$target
follower_arch	$arch
required	yes
action	$role target for Cat Food commit $trigger on $target; fetch that exact commit, run the named acceptance action, and record a receipt.
acceptance_kind	$kind
acceptance_action	$action
state	$state
last_attempt_commit	-
blocker	-
evidence	$evidence
depends_on	-
reason	$reason
superseded_by	-
follow_policy	exact
EOF_JOB
        printf '%s\n' "$jobs/$id.tsv"
    done
}

verifier() {
    if [ -n "${AICI_FOLLOWERS:-}" ]; then
        printf '%s\n' "$AICI_FOLLOWERS"
    elif command -v aici-followers >/dev/null 2>&1; then
        command -v aici-followers
    else
        fatal 'set AICI_FOLLOWERS to the compiled AICI follower verifier'
    fi
}

infer_leader() {
    trigger=$1
    leader=
    for file in "$jobs"/*.tsv; do
        [ -f "$file" ] || continue
        [ "$(record_value "$file" trigger_commit)" = "$trigger" ] || continue
        candidate=$(record_value "$file" leader_platform)
        if [ -n "$leader" ] && [ "$candidate" != "$leader" ]; then
            fatal "trigger $trigger has conflicting leaders $leader and $candidate"
        fi
        leader=$candidate
    done
    [ -n "$leader" ] || fatal "no follower records establish the leader for $trigger"
    printf '%s\n' "$leader"
}

reconcile() {
    requested=${1:-$(latest_source)}
    trigger=$(resolve_trigger "$requested")
    tool=$(verifier)
    "$tool" verify "$jobs" "$receipts"
    leader=$(infer_leader "$trigger")
    target_line "$leader" >/dev/null || fatal "leader $leader is no longer in targets.tsv"
    missing=0
    affected "$trigger" | while IFS="$tab" read -r target kind reason; do
        if ! job_for "$trigger" "$target" >/dev/null 2>&1; then
            printf 'missing follower job\t%s\t%s\t%s\n' "$trigger" "$target" "$reason" >&2
            exit 44
        fi
    done || missing=$?
    [ "$missing" -eq 0 ] || fatal "trigger $trigger is missing inferred follower work"
    for file in "$jobs"/*.tsv; do
        [ -f "$file" ] || continue
        target=$(record_value "$file" follower_platform)
        target_line "$target" >/dev/null || fatal "$file references vanished target $target"
    done
    if [ "$requested" != "$trigger" ]; then
        printf 'integrated source commit %s resolves to exact follower trigger %s\n' "$requested" "$trigger"
    fi
    host_reconcile "$trigger"
    printf 'follower reconciliation passes for %s\n' "$trigger"
}

job_by_id() {
    id=$1
    file=$jobs/$id.tsv
    [ -f "$file" ] || fatal "unknown follower job $id"
    printf '%s\n' "$file"
}

rewrite_field() {
    file=$1 key=$2 value=$3 output=$4
    awk -F '\t' -v OFS='\t' -v key="$key" -v value="$value" \
        '$1 == key { $2=value; seen=1 } { print } END { if (!seen) exit 2 }' \
        "$file" > "$output"
}

record_receipt() {
    [ "$#" -ge 2 ] && [ "$#" -le 3 ] ||
        fatal 'record JOB_ID RECEIPT_FILE [HOST_RECEIPT_FILE]'
    id=$1 source=$2 host_source=${3:-}
    [ -f "$source" ] || fatal "receipt not found: $source"
    file=$(job_by_id "$id")
    target=$(record_value "$file" follower_platform)
    if host_target "$target"; then
        [ -n "$host_source" ] || fatal "host receipt required for $id"
        validate_host_receipt "$file" "$source" "$host_source" "$target"
    elif [ -n "$host_source" ]; then
        fatal "$id is not a host follower and cannot accept a host receipt"
    fi
    mkdir -p "$receipts" "$host_receipts"
    destination=$receipts/$id.tsv
    host_destination=$host_receipts/$id.tsv
    backup=$file.backup.$$
    cp "$file" "$backup"
    cp "$source" "$destination"
    if [ -n "$host_source" ]; then cp "$host_source" "$host_destination"; fi
    attempt=$(awk -F '\t' '$1 == "attempt_commit" { print $2; found=1 } END { if (!found) exit 1 }' "$destination") || {
        rm -f "$destination" "$host_destination" "$backup"
        fatal 'receipt lacks attempt_commit'
    }
    tmp=$file.new.$$
    rewrite_field "$file" state accepted "$tmp" && mv "$tmp" "$file"
    rewrite_field "$file" last_attempt_commit "$attempt" "$tmp" && mv "$tmp" "$file"
    rewrite_field "$file" blocker - "$tmp" && mv "$tmp" "$file"
    rewrite_field "$file" evidence "$id.tsv" "$tmp" && mv "$tmp" "$file"
    tool=$(verifier)
    if ! "$tool" verify "$jobs" "$receipts" >/dev/null; then
        mv "$backup" "$file"
        rm -f "$destination" "$host_destination" "$tmp"
        fatal "receipt does not satisfy $id"
    fi
    rm -f "$backup" "$tmp"
    printf '%s\n' "$destination"
}

mark_blocked() {
    [ "$#" -ge 2 ] && [ "$#" -le 3 ] || fatal 'block JOB_ID REASON [LAST_ATTEMPT_COMMIT]'
    id=$1 reason=$2 attempt=${3:--}
    file=$(job_by_id "$id")
    tmp=$file.new.$$
    rewrite_field "$file" state blocked "$tmp" && mv "$tmp" "$file"
    rewrite_field "$file" blocker "$reason" "$tmp" && mv "$tmp" "$file"
    rewrite_field "$file" last_attempt_commit "$attempt" "$tmp" && mv "$tmp" "$file"
    printf '%s\n' "$file"
}

supersede_ancestors() {
    [ "$#" -eq 1 ] || fatal 'supersede-ancestors CURRENT_TRIGGER'
    current=$(resolve_trigger "$1")
    plan=$(mktemp)
    for file in "$jobs"/*.tsv; do
        [ -f "$file" ] || continue
        state=$(record_value "$file" state)
        case $state in pending|blocked|unsupported) ;; *) continue ;; esac
        old=$(record_value "$file" trigger_commit)
        [ "$old" != "$current" ] || continue
        target=$(record_value "$file" follower_platform)
        stale=$(sh "$root/followers/manage.sh" stale-target "$old" "$current" "$target")
        [ "$stale" = yes ] || continue
        successor_file=$(job_for "$current" "$target") || {
            rm -f "$plan"
            fatal "stale job $(record_value "$file" job_id) has no same-target successor at $current"
        }
        old_kind=$(record_value "$file" acceptance_kind)
        new_kind=$(record_value "$successor_file" acceptance_kind)
        [ "$old_kind" = "$new_kind" ] || {
            rm -f "$plan"
            fatal "stale job $(record_value "$file" job_id) changes acceptance kind from $old_kind to $new_kind"
        }
        printf '%s\t%s\n' "$file" "$(record_value "$successor_file" job_id)" >> "$plan"
    done

    if [ ! -s "$plan" ]; then
        rm -f "$plan"
        printf 'no supersedable ancestor followers before %s\n' "$current"
        return 0
    fi

    while IFS="$tab" read -r file successor; do
        tmp=$file.new.$$
        rewrite_field "$file" state superseded "$tmp" && mv "$tmp" "$file"
        rewrite_field "$file" superseded_by "$successor" "$tmp" && mv "$tmp" "$file"
        printf 'superseded\t%s\t%s\n' "$(record_value "$file" job_id)" "$successor"
    done < "$plan"
    rm -f "$plan"
}

merge_blockers() {
    requested=${1:-$(latest_source)}
    current=$(resolve_trigger "$requested")
    printf 'follower\tblocking\ttrigger\tcurrent_trigger\tacceptance_kind\tstate\tsuccessor\tobject_ref\taction\n'
    for file in "$jobs"/*.tsv; do
        [ -f "$file" ] || continue
        state=$(record_value "$file" state)
        trigger=$(record_value "$file" trigger_commit)
        obligation=$current
        action=run-follower
        if [ "$trigger" = "$current" ]; then
            :
        else
            case $state in pending|blocked|unsupported) ;; *) continue ;; esac
            target=$(record_value "$file" follower_platform)
            stale=$(sh "$root/followers/manage.sh" stale-target "$trigger" "$current" "$target")
            git -C "$root" merge-base --is-ancestor "$trigger" "$current" || continue
            if [ "$stale" = yes ]; then action=supersede-ancestors
            else obligation=$trigger
            fi
        fi
        printf '%s\tno\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$(record_value "$file" job_id)" "$trigger" "$obligation" \
            "$(record_value "$file" acceptance_kind)" "$state" \
            "$(record_value "$file" superseded_by)" "$file" \
            "$action"
    done
}

fallback_pending() {
    trigger=${1:-}
    printf 'job_id\trepository\ttrigger_commit\tfollower_platform\tfollower_arch\tacceptance_kind\tstate\taction\tblocker\n'
    for file in "$jobs"/*.tsv; do
        [ -f "$file" ] || continue
        state=$(record_value "$file" state)
        case $state in pending|blocked|unsupported) ;; *) continue ;; esac
        commit=$(record_value "$file" trigger_commit)
        [ -z "$trigger" ] || [ "$commit" = "$trigger" ] || continue
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$(record_value "$file" job_id)" "$(record_value "$file" repository)" "$commit" \
            "$(record_value "$file" follower_platform)" \
            "$(record_value "$file" follower_arch)" \
            "$(record_value "$file" acceptance_kind)" "$state" \
            "$(record_value "$file" action)" "$(record_value "$file" blocker)"
    done
}

pending() {
    trigger=${1:-}
    if [ -n "${AICI_FOLLOWERS:-}" ] || command -v aici-followers >/dev/null 2>&1; then
        tool=$(verifier)
        if [ -n "$trigger" ]; then "$tool" pending "$jobs" "$receipts" "$trigger"
        else "$tool" pending "$jobs" "$receipts"
        fi
    else
        fallback_pending "$trigger"
    fi
}

matrix() {
    trigger=${1:-}
    tool=$(verifier)
    if [ -n "$trigger" ]; then "$tool" matrix "$jobs" "$receipts" "$trigger"
    else "$tool" matrix "$jobs" "$receipts"
    fi
}

case ${1:-} in
    affected) [ "$#" -eq 2 ] || fatal 'affected TRIGGER'; affected "$2" ;;
    stale-target) shift; stale_target "$@" ;;
    latest) [ "$#" -eq 1 ] || fatal 'latest takes no arguments'; latest_source ;;
    resolve) [ "$#" -eq 2 ] || fatal 'resolve TRIGGER'; resolve_trigger "$2" ;;
    prepare) shift; prepare "$@" ;;
    reconcile) shift; reconcile "$@" ;;
    pending) shift; pending "$@" ;;
    matrix) shift; matrix "$@" ;;
    host-matrix) shift; host_matrix "$@" ;;
    host-reconcile) shift; [ "$#" -eq 1 ] || fatal 'host-reconcile TRIGGER'; host_reconcile "$1" ;;
    record) shift; record_receipt "$@" ;;
    block) shift; mark_blocked "$@" ;;
    supersede-ancestors) shift; supersede_ancestors "$@" ;;
    blockers) shift; merge_blockers "$@" ;;
    *) fatal 'usage: manage.sh affected|latest|resolve|prepare|reconcile|pending|matrix|host-matrix|host-reconcile|record|block|supersede-ancestors|blockers ...' ;;
esac
