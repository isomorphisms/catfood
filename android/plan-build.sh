#!/bin/sh
# Read-only immutable target obligations; no builder, publisher or device claim.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
fail() { printf 'catfood Android plan: %s\n' "$*" >&2; exit 2; }
[ "$#" -eq 3 ] || fail 'usage: plan-build.sh APPLICATION_CONTRACT phone|c67 SOURCE_SHA'
contract=$1
requested=$2
source_sha=$3
[ -f "$contract" ] || fail "missing application contract: $contract"
case "$requested" in phone|c67) ;; *) fail "unknown requested target: $requested" ;; esac
printf '%s\n' "$source_sha" | grep -Eq '^[0123456789abcdef]{40}$' ||
    fail 'source SHA must be an exact lowercase 40-character commit'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is required'
command -v git >/dev/null 2>&1 || fail 'git is required'
catfood_commit=$(git -C "$root" rev-parse HEAD 2>/dev/null) ||
    fail 'Cat Food must be an exact Git checkout'
printf '%s\n' "$catfood_commit" | grep -Eq '^[0123456789abcdef]{40}$' ||
    fail 'invalid Cat Food revision'
matrix="$root/android/application-targets.tsv"
[ -f "$matrix" ] || fail 'missing authoritative application target matrix'
awk -F '\t' '
    BEGIN { ok=1 }
    /^[[:space:]]*#/ {next}
    NF != 2 {print "invalid application contract field width" > "/dev/stderr"; ok=0; next}
    !($1=="schema" || $1=="repository" || $1=="package_id" ||
      $1=="launcher_label" || $1=="min_sdk" || $1=="packaging" ||
      $1=="armeabi-v7a" || $1=="arm64-v8a") {
        print "unknown application contract field: " $1 > "/dev/stderr"; ok=0
    }
    seen[$1]++ {print "duplicate application contract field: " $1 > "/dev/stderr"; ok=0}
    END {
        split("schema repository package_id launcher_label min_sdk packaging armeabi-v7a arm64-v8a", required, " ")
        for (i=1;i<=8;i++) if (seen[required[i]]!=1) {
            print "missing application contract field: " required[i] > "/dev/stderr"; ok=0
        }
        exit !ok
    }
' "$contract" || fail 'invalid application contract'
field() { awk -F '\t' -v key="$1" '$1==key {print $2}' "$contract"; }
[ "$(field schema)" = catfood-android-application-v1 ] || fail 'unsupported contract schema'
repository=$(field repository)
package=$(field package_id)
launcher_label=$(field launcher_label)
min_sdk=$(field min_sdk)
packaging=$(field packaging)
printf '%s\n' "$repository" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' ||
    fail 'repository must be owner/name'
printf '%s\n' "$package" | grep -Eq '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$' ||
    fail 'invalid Android package name'
[ -n "$launcher_label" ] || fail 'launcher label is missing'
# The leaf build cannot authorize its own rebranding: Cat Food maintains the
# approved application name independently of the source contract.
labels="$root/android/application-labels.tsv"
[ -f "$labels" ] || fail 'missing approved launcher-identity registry'
approved_label=$(awk -F '\t' -v repository="$repository" -v package="$package" '
    /^[[:space:]]*#/ {next}
    $1==repository && $2==package {n++; value=$3; if(NF!=3) exit 2}
    END {if(n!=1) exit 2; print value}
' "$labels") || fail 'missing or duplicate approved launcher identity'
[ "$launcher_label" = "$approved_label" ] ||
    fail "launcher identity changed against Cat Food policy: $launcher_label"
printf '%s\n' "$min_sdk" | grep -Eq '^[0-9]+$' || fail 'invalid minimum SDK'
case "$packaging" in shared|split) ;; *) fail 'packaging must be shared or split' ;; esac
for abi in armeabi-v7a arm64-v8a; do
    value=$(field "$abi")
    case "$value" in supported|incompatible|unknown) ;; *)
        fail "invalid $abi support decision: $value" ;; esac
done
awk -F '\t' '
    NR==1 {if ($0!="target\tdevice\tabi\tpriority") exit 2; next}
    /^[[:space:]]*#/ {next}
    NF!=4 {exit 2}
    seen[$1]++ {exit 2}
    $1=="phone" && !($2=="MIRO_A1" && $3=="armeabi-v7a" && $4=="primary") {exit 2}
    $1=="c67" && !($2=="MIRO_C67" && $3=="arm64-v8a" && $4=="paired") {exit 2}
    END {if (seen["phone"]!=1 || seen["c67"]!=1) exit 2}
' "$matrix" || fail 'invalid Cat Food Android target matrix'
contract_sha=$(sha256sum "$contract" | awk '{print $1}')
matrix_sha=$(sha256sum "$matrix" | awk '{print $1}')
labels_sha=$(sha256sum "$labels" | awk '{print $1}')
printf 'schema\tcatfood-android-build-plan-v1\n'
printf 'catfood_commit\t%s\n' "$catfood_commit"
printf 'matrix_sha256\t%s\n' "$matrix_sha"
printf 'labels_sha256\t%s\n' "$labels_sha"
printf 'contract_sha256\t%s\n' "$contract_sha"
printf 'repository\t%s\n' "$repository"
printf 'source_sha\t%s\n' "$source_sha"
printf 'package_id\t%s\n' "$package"
printf 'launcher_label\t%s\n' "$launcher_label"
printf 'min_sdk\t%s\n' "$min_sdk"
printf 'packaging\t%s\n' "$packaging"
printf 'requested_target\t%s\n' "$requested"
printf 'target\tdevice\tabi\tobligation\tacceptance\n'
for target in phone c67; do
    if [ "$requested" = c67 ] && [ "$target" = phone ]; then continue; fi
    row=$(awk -F '\t' -v t="$target" '$1==t {print $2 "\t" $3}' "$matrix")
    abi=$(printf '%s\n' "$row" | cut -f2)
    status=$(field "$abi")
    if [ "$target" = "$requested" ]; then
        case "$status" in supported) obligation=required ;; *) obligation=blocked ;; esac
    else
        case "$status" in
            supported) obligation=required ;;
            incompatible) obligation=incompatible ;;
            unknown) obligation=blocked ;;
        esac
    fi
    printf '%s\t%s\t%s\tnot_run\n' "$target" "$row" "$obligation"
done
