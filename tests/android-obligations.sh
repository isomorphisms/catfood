#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

approved=$tmp/approved.tsv
sh "$root/android/obligations.sh" build "$approved"
approved_sha=$(sha256sum "$approved" | awk '{print $1}')
sh "$root/android/obligations.sh" verify "$approved" "$approved_sha" >/dev/null

reject_obligations() {
    name=$1
    expected=$2
    packages_file=$3
    restrictions_file=$4
    if CATFOOD_ANDROID_PACKAGES="$packages_file" CATFOOD_ANDROID_RESTRICTIONS="$restrictions_file" \
        sh "$root/android/obligations.sh" verify "$approved" "$approved_sha" >"$tmp/$name.out" 2>&1; then
        printf 'obligation mutation survived: %s\n' "$name" >&2
        exit 1
    fi
    grep -F "$expected" "$tmp/$name.out" >/dev/null
}

# Harmless package-row ordering has no effect on canonical obligations.
awk '/^[[:space:]]*($|#)/ {header[++headers]=$0; next} {row[++rows]=$0} END {for(i=1;i<=headers;i++) print header[i]; for(i=rows;i>=1;i--) print row[i]}' \
    "$root/android/packages.tsv" > "$tmp/reordered.tsv"
CATFOOD_ANDROID_PACKAGES="$tmp/reordered.tsv" \
    sh "$root/android/obligations.sh" verify "$approved" "$approved_sha" >/dev/null

# Optional support remains a declared gap rather than a fabricated runtime
# requirement. The current approved projection is valid without a Gopeed
# package because its delivery row says it is not a bootstrap prerequisite.
awk -F '\t' '$1=="gopeed" && $2=="runtime" && $3=="gap:android-package-missing" && \
    $4=="gap:android-package-missing" && $5 ~ /^optional-/ {found=1} END {exit found ? 0 : 1}' \
    "$root/android/delivery.tsv"
if awk -F '\t' '$1 == "gopeed-phone" || $1 == "gopeed-tablet" {found=1} END {exit found ? 0 : 1}' \
    "$root/android/packages.tsv"; then
    printf '%s\n' 'optional Gopeed support unexpectedly became a required package' >&2
    exit 1
fi

# The historical concrete failures cannot manufacture currentness by deletion.
sed '/^powervr-runner-tablet\t/d' "$root/android/package-restrictions.tsv" > "$tmp/no-mali.tsv"
reject_obligations no-mali 'approved package restriction is missing or changed' \
    "$root/android/packages.tsv" "$tmp/no-mali.tsv"

awk -F '\t' -v OFS='\t' '$1=="az-phone" {$17="-"} {print}' \
    "$root/android/packages.tsv" > "$tmp/no-runtime.tsv"
reject_obligations no-runtime 'approved package/runtime obligation is missing or changed' \
    "$tmp/no-runtime.tsv" "$root/android/package-restrictions.tsv"

reject_graph() {
    name=$1
    expected=$2
    candidate=$3
    if CATFOOD_ANDROID_PACKAGES="$candidate" sh "$root/android/check.sh" check >"$tmp/$name.out" 2>&1; then
        printf 'invalid package graph survived: %s\n' "$name" >&2
        exit 1
    fi
    grep -F "$expected" "$tmp/$name.out" >/dev/null
}

awk -F '\t' -v OFS='\t' '$1=="az-phone" {$18="az-phone"} {print}' \
    "$root/android/packages.tsv" > "$tmp/self-cycle.tsv"
reject_graph self-cycle 'invalid package dependency for az-phone' "$tmp/self-cycle.tsv"

awk -F '\t' -v OFS='\t' '$1=="grease-phone" {$18="az-phone"} {print}' \
    "$root/android/packages.tsv" > "$tmp/two-cycle.tsv"
reject_graph two-cycle 'package dependency cycle reaches' "$tmp/two-cycle.tsv"

awk -F '\t' -v OFS='\t' '
    $1=="grease-phone" {$18="crawlspace-phone"}
    $1=="crawlspace-phone" {$18="az-phone"}
    {print}
' "$root/android/packages.tsv" > "$tmp/long-cycle.tsv"
reject_graph long-cycle 'package dependency cycle reaches' "$tmp/long-cycle.tsv"

awk -F '\t' -v OFS='\t' '$1=="az-phone" {$18="missing-phone"} {print}' \
    "$root/android/packages.tsv" > "$tmp/missing-node.tsv"
reject_graph missing-node 'depends on missing package missing-phone' "$tmp/missing-node.tsv"

awk -F '\t' -v OFS='\t' '$1=="az-phone" {$18="grease-tablet"} {print}' \
    "$root/android/packages.tsv" > "$tmp/cross-lane.tsv"
reject_graph cross-lane 'depends on package for a different target: grease-tablet' "$tmp/cross-lane.tsv"

cp "$root/android/packages.tsv" "$tmp/duplicate-package.tsv"
awk -F '\t' '$1=="az-phone" {print; exit}' "$root/android/packages.tsv" >> "$tmp/duplicate-package.tsv"
reject_graph duplicate-package 'duplicate package row' "$tmp/duplicate-package.tsv"

cp "$root/android/package-restrictions.tsv" "$tmp/duplicate-restriction.tsv"
awk -F '\t' '$1=="powervr-runner-tablet" {print; exit}' \
    "$root/android/package-restrictions.tsv" >> "$tmp/duplicate-restriction.tsv"
if CATFOOD_ANDROID_RESTRICTIONS="$tmp/duplicate-restriction.tsv" \
    sh "$root/android/check.sh" check >"$tmp/duplicate-restriction.out" 2>&1; then
    printf '%s\n' 'duplicate package restriction survived validation' >&2
    exit 1
fi
grep -F 'invalid Android package restrictions' "$tmp/duplicate-restriction.out" >/dev/null

# An approved unrelated package change leaves another package binding intact,
# while the changed package receives a new exact binding.
az_before=$(sh "$root/android/obligations.sh" package-sha "$approved" az-phone)
crawl_before=$(sh "$root/android/obligations.sh" package-sha "$approved" crawlspace-phone)
awk -F '\t' -v OFS='\t' '$1=="crawlspace-phone" {$17="command:sh"} {print}' \
    "$root/android/packages.tsv" > "$tmp/changed-unrelated.tsv"
CATFOOD_ANDROID_PACKAGES="$tmp/changed-unrelated.tsv" \
    sh "$root/android/obligations.sh" build "$tmp/changed-approved.tsv"
az_after=$(sh "$root/android/obligations.sh" package-sha "$tmp/changed-approved.tsv" az-phone)
crawl_after=$(sh "$root/android/obligations.sh" package-sha "$tmp/changed-approved.tsv" crawlspace-phone)
[ "$az_before" = "$az_after" ]
[ "$crawl_before" != "$crawl_after" ]

# The ARM64 lane can remain shared while physical-device restrictions stay
# distinct: the Mali-G57 runner is accepted for tablet and rejected for C67.
if sh "$root/android/check.sh" gaps c67 | grep -F 'powervr-runner-tablet' >/dev/null; then :; else
    printf '%s\n' 'C67 device restriction was lost' >&2; exit 1
fi
if sh "$root/android/check.sh" gaps tablet | grep -F 'powervr-runner-tablet' >/dev/null; then
    printf '%s\n' 'tablet package was rejected by its own Mali-G57 restriction' >&2; exit 1
fi

printf '%s\n' 'Cat Food approved obligation and package graph controls: PASS'
