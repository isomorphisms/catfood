#!/bin/sh
# Canonical Android package/runtime obligations.  The candidate tree may build
# this projection, but only a separately supplied exact digest authorizes it.
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tools=${CATFOOD_TOOLS:-"$root/tools.tsv"}
delivery=${CATFOOD_ANDROID_DELIVERY:-"$root/android/delivery.tsv"}
packages=${CATFOOD_ANDROID_PACKAGES:-"$root/android/packages.tsv"}
restrictions=${CATFOOD_ANDROID_RESTRICTIONS:-"$root/android/package-restrictions.tsv"}
targets=${CATFOOD_ANDROID_TARGETS:-"$root/android/application-targets.tsv"}
conversations=${CATFOOD_ANDROID_CONVERSATIONS:-"$root/android/conversation-targets.tsv"}
labels=${CATFOOD_ANDROID_LABELS:-"$root/android/application-labels.tsv"}

fail() { printf 'catfood Android obligations: %s\n' "$*" >&2; exit 2; }
hash_file() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    elif [ -x /system/bin/toybox ]; then /system/bin/toybox sha256sum "$1" | awk '{print $1}'
    else fail 'sha256sum is required'
    fi
}
require_files() {
    for file in "$tools" "$delivery" "$packages" "$restrictions" "$targets" "$conversations" "$labels"; do
        [ -f "$file" ] || fail "missing material input: $file"
    done
}
build_projection() (
    output=$1
    require_files
    CATFOOD_TOOLS="$tools" CATFOOD_ANDROID_DELIVERY="$delivery" \
        CATFOOD_ANDROID_PACKAGES="$packages" CATFOOD_ANDROID_RESTRICTIONS="$restrictions" \
        sh "$root/android/check.sh" check >/dev/null
    work=$(mktemp -d "${TMPDIR:-/tmp}/catfood-obligations.XXXXXXXX") || exit
    trap 'rm -rf "$work"' EXIT HUP INT TERM

    {
        awk -F '\t' '!/^[[:space:]]*($|#)/ {printf "package"; for(i=1;i<=NF;i++) printf "\t%s", $i; printf "\n"}' "$packages"
        awk -F '\t' '!/^[[:space:]]*($|#)/ {printf "delivery"; for(i=1;i<=NF;i++) printf "\t%s", $i; printf "\n"}' "$delivery"
        awk -F '\t' '!/^[[:space:]]*($|#)/ {printf "restriction"; for(i=1;i<=NF;i++) printf "\t%s", $i; printf "\n"}' "$restrictions"
        awk -F '\t' 'NR>1 && !/^[[:space:]]*($|#)/ {printf "target"; for(i=1;i<=NF;i++) printf "\t%s", $i; printf "\n"}' "$targets"
        awk -F '\t' 'NR>1 && !/^[[:space:]]*($|#)/ {printf "conversation"; for(i=1;i<=NF;i++) printf "\t%s", $i; printf "\n"}' "$conversations"
        awk -F '\t' '!/^[[:space:]]*($|#)/ {printf "label"; for(i=1;i<=NF;i++) printf "\t%s", $i; printf "\n"}' "$labels"
    } | LC_ALL=C sort -u > "$work/material.tsv"

    awk -F '\t' '$1=="package" {print $2}' "$work/material.tsv" | LC_ALL=C sort -u > "$work/packages"
    : > "$work/bindings.tsv"
    while IFS= read -r package; do
        [ -n "$package" ] || continue
        awk -F '\t' -v initial="$package" '
            $1=="package" {
                row[++rows]=$0; owner[rows]=$2; requires[rows]=$19
            }
            {all[NR]=$0; count=NR}
            END {
                wanted[initial]=1
                changed=1
                while(changed) {
                    changed=0
                    for(i=1;i<=rows;i++) if(wanted[owner[i]]) {
                        n=split(requires[i], dependency, ",")
                        for(j=1;j<=n;j++) if(dependency[j]!="-" && dependency[j]!="" && !wanted[dependency[j]]) {
                            wanted[dependency[j]]=1; changed=1
                        }
                    }
                }
                for(i=1;i<=count;i++) {
                    split(all[i], field, "\t")
                    kind=field[1]
                    if(kind=="package" && wanted[field[2]]) print all[i]
                    else if(kind=="restriction" && wanted[field[2]]) print all[i]
                    else if(kind=="delivery") {
                        for(column=4;column<=5;column++) {
                            value=field[column]
                            sub(/^package:/,"",value); sub(/^packages:/,"",value)
                            n=split(value, item, ",")
                            for(j=1;j<=n;j++) if(wanted[item[j]]) {print all[i]; column=6; break}
                        }
                    }
                    else if(kind=="target" || kind=="conversation") print all[i]
                }
            }
        ' "$work/material.tsv" | LC_ALL=C sort -u > "$work/package.tsv"
        printf 'binding\t%s\t%s\n' "$package" "$(hash_file "$work/package.tsv")" >> "$work/bindings.tsv"
    done < "$work/packages"

    {
        printf 'schema\tcatfood-android-obligations-v1\n'
        cat "$work/material.tsv"
        LC_ALL=C sort "$work/bindings.tsv"
    } > "$work/output.tsv"
    mkdir -p "$(dirname -- "$output")"
    cp "$work/output.tsv" "$output"
)
verify_projection() {
    approved=$1
    approved_sha=$2
    [ -f "$approved" ] || fail 'independently approved obligations are unavailable'
    printf '%s\n' "$approved_sha" | grep -Eq '^[0123456789abcdef]{64}$' || fail 'approved obligations digest must be exact lowercase SHA-256'
    [ "$(hash_file "$approved")" = "$approved_sha" ] || fail 'approved obligations digest does not match supplied policy identity'
    [ "$(awk -F '\t' '$1=="schema" {print $2; n++} END {if(n!=1) exit 1}' "$approved")" = catfood-android-obligations-v1 ] || fail 'invalid approved obligations schema'
    candidate=$(mktemp "${TMPDIR:-/tmp}/catfood-obligations-candidate.XXXXXXXX") || exit
    trap 'rm -f "$candidate"' EXIT HUP INT TERM
    build_projection "$candidate"
    if ! cmp -s "$approved" "$candidate"; then
        missing=$(awk -F '\t' 'NR==FNR {candidate[$0]=1; next} !($0 in candidate) && $1!="binding" {print; exit}' "$candidate" "$approved")
        case $missing in
            restriction*) fail 'approved package restriction is missing or changed' ;;
            package*) fail 'approved package/runtime obligation is missing or changed' ;;
            delivery*) fail 'approved inventory obligation is missing or changed' ;;
            target*|conversation*|label*) fail 'approved target policy material is missing or changed' ;;
            *) fail 'candidate obligations differ from independently approved material' ;;
        esac
    fi
    printf 'approved_obligations_sha256\t%s\n' "$approved_sha"
}
package_binding() {
    approved=$1
    package=$2
    value=$(awk -F '\t' -v package="$package" '$1=="binding" && $2==package {n++; value=$3} END {if(n!=1) exit 1; print value}' "$approved") ||
        fail "missing or duplicate approved package binding: $package"
    printf '%s\n' "$value" | grep -Eq '^[0123456789abcdef]{64}$' || fail "invalid approved package binding: $package"
    printf '%s\n' "$value"
}

case ${1:-} in
    build) [ "$#" -eq 2 ] || fail 'usage: obligations.sh build OUTPUT'; build_projection "$2" ;;
    verify) [ "$#" -eq 3 ] || fail 'usage: obligations.sh verify APPROVED SHA256'; verify_projection "$2" "$3" ;;
    package-sha) [ "$#" -eq 3 ] || fail 'usage: obligations.sh package-sha APPROVED PACKAGE'; package_binding "$2" "$3" ;;
    *) fail 'usage: obligations.sh build OUTPUT | verify APPROVED SHA256 | package-sha APPROVED PACKAGE' ;;
esac
