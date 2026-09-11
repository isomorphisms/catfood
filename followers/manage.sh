#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
targets=$root/followers/targets.tsv
rules=$root/followers/impact-rules.tsv
jobs=$root/followers/jobs
receipts=$root/followers/receipts

fatal() { printf 'followers: %s\n' "$*" >&2; exit 1; }
tab=$(printf '\t')

record_value() {
    file=$1 key=$2
    awk -F '\t' -v key="$key" '$1 == key { if (seen++) exit 2; value=$2 } END { if (!seen) exit 1; print value }' "$file"
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
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT HUP INT TERM
    changed_for_commit "$trigger" | while IFS= read -r path; do
        [ -n "$path" ] || continue
        rule_for_path "$path"
    done | while IFS="$tab" read -r follower reason; do
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
    done | sort -u > "$tmp"
    cat "$tmp"
    rm -f "$tmp"
    trap - EXIT HUP INT TERM
}

control_path() {
    case $1 in
        followers/*|AGENTS.md|docs/followers.md|tests/followers.sh|.github/workflows/followers.yml)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

latest_source() {
    tmp=$(mktemp)
    for candidate in $(git -C "$root" rev-list --first-parent HEAD); do
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
    fatal 'no source-changing commit found on first-parent history'
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
    trigger=${1:-$(latest_source)}
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
    [ "$#" -eq 2 ] || fatal 'record JOB_ID RECEIPT_FILE'
    id=$1 source=$2
    [ -f "$source" ] || fatal "receipt not found: $source"
    file=$(job_by_id "$id")
    mkdir -p "$receipts"
    destination=$receipts/$id.tsv
    backup=$file.backup.$$
    cp "$file" "$backup"
    cp "$source" "$destination"
    attempt=$(awk -F '\t' '$1 == "attempt_commit" { print $2; found=1 } END { if (!found) exit 1 }' "$destination") || {
        rm -f "$destination" "$backup"
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
        rm -f "$destination" "$tmp"
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

fallback_pending() {
    trigger=${1:-}
    printf 'job_id\ttrigger_commit\tfollower_platform\tfollower_arch\tacceptance_kind\tstate\taction\tblocker\n'
    for file in "$jobs"/*.tsv; do
        [ -f "$file" ] || continue
        state=$(record_value "$file" state)
        case $state in pending|blocked|unsupported) ;; *) continue ;; esac
        commit=$(record_value "$file" trigger_commit)
        [ -z "$trigger" ] || [ "$commit" = "$trigger" ] || continue
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$(record_value "$file" job_id)" "$commit" \
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
    latest) [ "$#" -eq 1 ] || fatal 'latest takes no arguments'; latest_source ;;
    prepare) shift; prepare "$@" ;;
    reconcile) shift; reconcile "$@" ;;
    pending) shift; pending "$@" ;;
    matrix) shift; matrix "$@" ;;
    record) shift; record_receipt "$@" ;;
    block) shift; mark_blocked "$@" ;;
    *) fatal 'usage: manage.sh affected|latest|prepare|reconcile|pending|matrix|record|block ...' ;;
esac
