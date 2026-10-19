#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
packages=${CATFOOD_ANDROID_PACKAGES:-"$root/android/packages.tsv"}
workspace=${CATFOOD_ROOT:-"$HOME/opt"}
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
device_state=${CATFOOD_DEVICE_STATE:-"$state_home/catfood/device"}
manager_state=${CATFOOD_MANAGER_STATE:-"$state_home/catfood/manager"}
. "$root/android/target.sh"
tab=$(printf '\t')

usage() {
    cat <<'EOF'
usage: device-state.sh inspect
       device-state.sh record INVENTORY|-
       device-state.sh compare [DEVICE|INVENTORY]
       device-state.sh packages [DEVICE|INVENTORY]
       device-state.sh report

inspect   observe this Android device and emit a portable inventory
record    store an inventory in the Cat Food Manager device register
compare   compare an inventory with the current Android package profile
packages  show recorded Android and Termux package rows
report    summarize all devices recorded by Cat Food Manager

These commands observe and compare only. They do not install, remove, or repair anything.
EOF
}

clean_field() {
    printf '%s' "$1" | tr '\t\r\n' '   '
}

row() {
    printf '%s\t%s\t%s\t%s\n' \
        "$(clean_field "$1")" \
        "$(clean_field "$2")" \
        "$(clean_field "$3")" \
        "$(clean_field "$4")"
}

hash_file() {
    file=$1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{ print $1 }'
        return
    fi
    toybox=${CATFOOD_TOYBOX:-/system/bin/toybox}
    if [ -x "$toybox" ]; then
        "$toybox" sha256sum "$file" | awk '{ print $1 }'
        return
    fi
    return 127
}

prop() {
    if command -v getprop >/dev/null 2>&1; then
        getprop "$1" 2>/dev/null | tr -d '\r' | head -n 1
    fi
}

detect_target() {
    case ${CATFOOD_TARGET:-} in
        phone|c67|tablet) catfood_android_require_device "$CATFOOD_TARGET" || return $?; printf '%s\n' "$CATFOOD_TARGET" ;;
        *) catfood_detect_android_target ;;
    esac
}

device_id() { catfood_android_device_id; }
valid_device_id() {
    case $1 in ''|-|*[!a-zA-Z0-9_.-]*) return 1 ;; *) return 0 ;; esac
}

meta() {
    awk -F '\t' -v key="$2" '$1 == "meta" && $2 == key { print $3; exit }' "$1"
}

validate_inventory() {
    inventory=$1
    [ -f "$inventory" ] || {
        printf 'Cat Food inventory is missing: %s\n' "$inventory" >&2
        return 1
    }

    awk -F '\t' '
        NR == 1 {
            if ($0 != "# catfood-device-inventory-v1") {
                print FILENAME ": unsupported or missing inventory schema" > "/dev/stderr"
                failed = 1
            }
            next
        }
        /^#/ { next }
        NF != 4 {
            printf "%s:%d: expected four tab-separated fields, found %d\n", FILENAME, FNR, NF > "/dev/stderr"
            failed = 1
            next
        }
        $1 == "meta" {
            if (meta_seen[$2]++) { print FILENAME ": duplicate inventory identity: " $2 > "/dev/stderr"; failed=1 }
            if ($2 == "device_id") { device_id = $3; device_id_count++ }
            if ($2 == "observed_at") { observed_at = $3; observed_at_count++ }
            if ($2 == "target") { target = $3; target_count++ }
        }
        $1 != "meta" && seen[$1 SUBSEP $2 SUBSEP $3]++ {
            print FILENAME ": duplicate inventory row" > "/dev/stderr"; failed=1
        }
        $1 == "catfood_package" && package_seen[$2]++ {
            print FILENAME ": ambiguous package inventory" > "/dev/stderr"; failed=1
        }
        END {
            if (device_id_count != 1 || device_id !~ /^[[:alnum:]_.-]+$/) {
                print FILENAME ": invalid or missing device_id" > "/dev/stderr"
                failed = 1
            }
            if (observed_at_count != 1 || observed_at == "") {
                print FILENAME ": invalid or missing observed_at" > "/dev/stderr"
                failed = 1
            }
            if (target_count != 1 || (target != "phone" && target != "c67" && target != "tablet" && target != "termux")) {
                print FILENAME ": inventory target must be phone, c67, tablet or generic termux" > "/dev/stderr"
                failed = 1
            }
            exit failed
        }
    ' "$inventory" || return $?
    inventory_target=$(meta "$inventory" target)
    inventory_profile=$(catfood_android_profile "$(meta "$inventory" product)" "$(meta "$inventory" model)" "$(meta "$inventory" abi)") || return $?
    [ "$inventory_profile" = "$inventory_target" ] || {
        printf '%s\n' 'inventory identity does not match target' >&2
        return 1
    }
}

inspect_device() {
    target=$(detect_target)
    id=$(device_id)
    observed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    stamp=$(printf '%s' "$observed_at" | tr ':+' '--')
    abi=${CATFOOD_DEVICE_ABI:-}
    [ -n "$abi" ] || abi=$(prop ro.product.cpu.abi)

    mkdir -p "$device_state/inspections"
    inventory=$device_state/.inventory.$$
    android_packages=$device_state/.android-packages.$$
    termux_packages=$device_state/.termux-packages.$$
    : > "$android_packages"
    : > "$termux_packages"
    trap 'rm -f "$inventory" "$android_packages" "$termux_packages"' EXIT HUP INT TERM

    android_packages_evidence=unavailable
    android_packages_sha256=-
    if command -v pm >/dev/null 2>&1; then
        pm list packages -3 2>/dev/null |
        sed -n 's/^package://p' |
        LC_ALL=C sort -u > "$android_packages"
        android_packages_evidence=pm-user
        if android_packages_sha256=$(hash_file "$android_packages"); then
            android_packages_evidence=pm-user+sha256
        else
            android_packages_sha256=-
        fi
    fi

    termux_packages_evidence=unavailable
    termux_packages_sha256=-
    if command -v dpkg-query >/dev/null 2>&1; then
        dpkg-query -W -f='${Package}\t${Version}\n' 2>/dev/null |
        LC_ALL=C sort -u > "$termux_packages"
        termux_packages_evidence=dpkg-query
        if termux_packages_sha256=$(hash_file "$termux_packages"); then
            termux_packages_evidence=dpkg-query+sha256
        else
            termux_packages_sha256=-
        fi
    fi

    {
        printf '%s\n' '# catfood-device-inventory-v1'
        printf '%s\n' '# kind<TAB>name<TAB>value<TAB>evidence'
        row meta device_id "$id" local-state
        row meta observed_at "$observed_at" clock
        row meta target "$target" detected
        row meta name "${CATFOOD_DEVICE_NAME:--}" local-config
        row meta manufacturer "$(prop ro.product.manufacturer)" getprop
        row meta brand "$(prop ro.product.brand)" getprop
        row meta model "$(prop ro.product.model)" getprop
        row meta product "$(prop ro.product.device)" getprop
        row meta fingerprint "$(prop ro.build.fingerprint)" getprop
        row meta android_release "$(prop ro.build.version.release)" getprop
        row meta android_sdk "$(prop ro.build.version.sdk)" getprop
        row meta abi "$abi" getprop
        row meta android_packages_sha256 "$android_packages_sha256" "$android_packages_evidence"
        row meta termux_packages_sha256 "$termux_packages_sha256" "$termux_packages_evidence"

        for receipt in "$workspace/receipts/$target-"*.tsv; do
            [ -f "$receipt" ] || continue
            package=$(awk -F '\t' '$1 == "package" { print $2; exit }' "$receipt")
            package_ref=$(awk -F '\t' '$1 == "package_ref" { print $2; exit }' "$receipt")
            installation=NOT_VERIFIED
            if sh "$root/android/check.sh" receipt "$receipt" "$target" "$id" >/dev/null 2>&1; then
                installation=$(awk -F '\t' '$1 == "installation_result" { print $2; exit }' "$receipt")
            fi
            if [ -n "$package" ]; then
                row catfood_package "$package" "${package_ref:--}" "receipt:${installation:-unknown}"
            else
                row catfood_receipt "$(basename -- "$receipt")" malformed missing-package-field
            fi
        done

        for package_dir in "$workspace/packages"/*; do
            [ -d "$package_dir" ] || continue
            package=$(basename -- "$package_dir")
            for ref_dir in "$package_dir"/*; do
                [ -d "$ref_dir" ] || continue
                row catfood_tree "$package" "$(basename -- "$ref_dir")" package-directory
            done
        done

        while IFS= read -r package; do
            [ -n "$package" ] || continue
            row android_package "$package" - pm-user
        done < "$android_packages"

        while IFS="$tab" read -r package version; do
            [ -n "$package" ] || continue
            row termux_package "$package" "${version:--}" dpkg-query
        done < "$termux_packages"
    } > "$inventory"

    validate_inventory "$inventory"
    cp "$inventory" "$device_state/inventory.tsv"
    cp "$inventory" "$device_state/inspections/$stamp.tsv"
    cat "$inventory"
    rm -f "$inventory" "$android_packages" "$termux_packages"
    trap - EXIT HUP INT TERM
}

record_inventory() {
    [ "$#" -eq 1 ] || { usage >&2; return 2; }
    source=$1
    temporary=
    if [ "$source" = - ]; then
        mkdir -p "$manager_state"
        temporary=$manager_state/.incoming.$$
        cat > "$temporary"
        source=$temporary
    fi
    trap '[ -z "${temporary:-}" ] || rm -f "$temporary"' EXIT HUP INT TERM

    validate_inventory "$source"
    id=$(meta "$source" device_id)
    observed_at=$(meta "$source" observed_at)
    name=$(meta "$source" name)
    manufacturer=$(meta "$source" manufacturer)
    model=$(meta "$source" model)
    target=$(meta "$source" target)
    [ -n "$name" ] || name=-
    [ -n "$manufacturer" ] || manufacturer=-
    [ -n "$model" ] || model=-

    device_dir=$manager_state/devices/$id
    mkdir -p "$device_dir/inspections"
    stamp=$(printf '%s' "$observed_at" | tr ':+' '--')
    cp "$source" "$device_dir/inventory.tsv"
    cp "$source" "$device_dir/inspections/$stamp.tsv"

    register=$manager_state/register.tsv
    register_tmp=$manager_state/.register.$$
    if [ -f "$register" ]; then
        awk -F '\t' -v id="$id" '/^#/ { print; next } $1 != id { print }' "$register" > "$register_tmp"
    else
        printf '%s\n' '# catfood-device-register-v1: device_id<TAB>name<TAB>manufacturer<TAB>model<TAB>target<TAB>observed_at' > "$register_tmp"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$id" "$name" "$manufacturer" "$model" "$target" "$observed_at" >> "$register_tmp"
    mv "$register_tmp" "$register"

    printf '%s\t%s\t%s\n' "$id" "$target" "$observed_at"
    [ -z "$temporary" ] || rm -f "$temporary"
    trap - EXIT HUP INT TERM
}

resolve_inventory() {
    requested=${1:-}
    if [ -z "$requested" ]; then
        resolved_inventory=$device_state/inventory.tsv
    elif [ -f "$requested" ]; then
        resolved_inventory=$requested
    elif valid_device_id "$requested" && [ -f "$manager_state/devices/$requested/inventory.tsv" ]; then
        resolved_inventory=$manager_state/devices/$requested/inventory.tsv
    else
        printf 'Cat Food cannot find inventory or recorded device: %s\n' "$requested" >&2
        return 1
    fi
}

compare_inventory() {
    inventory=$1
    validate_inventory "$inventory"
    [ -f "$packages" ] || {
        printf 'Cat Food Android package profile is missing: %s\n' "$packages" >&2
        return 1
    }
    target=$(meta "$inventory" target)
    . "$root/android/target.sh"
    if [ "$target" = termux ]; then
        comparison_lane=unassigned
    else
        comparison_lane=$(catfood_android_delivery_target "$target")
    fi

    awk -F '\t' -v target="$comparison_lane" -v packages="$packages" -v inventory="$inventory" '
        function emit(state, item, observed, expected, evidence) {
            print state "\t" item "\t" observed "\t" expected "\t" evidence
        }
        FILENAME == packages {
            if ($0 ~ /^[[:space:]]*($|#)/) next
            if ($2 == target && !expected[$1]++) expected_ref[$1] = $7
            next
        }
        FILENAME == inventory {
            if ($0 ~ /^#/ || $0 == "") next
            if ($1 == "catfood_package") {
                actual[$2] = $3
                actual_evidence[$2] = $4
            } else if ($1 == "catfood_tree") {
                tree[$2 SUBSEP $3] = 1
                tree_evidence[$2 SUBSEP $3] = $4
                tree_rows[++tree_count] = $2 SUBSEP $3
            }
            next
        }
        END {
            print "# state\titem\tobserved\texpected\tevidence"
            for (item in expected) {
                if (item in actual) {
                    if (actual[item] != expected_ref[item])
                        emit("different", item, actual[item], expected_ref[item], actual_evidence[item])
                    else
                        emit("unconfirmed", item, actual[item], expected_ref[item], actual_evidence[item])
                } else if (tree[item SUBSEP expected_ref[item]]) {
                    emit("unrecorded", item, expected_ref[item], expected_ref[item], tree_evidence[item SUBSEP expected_ref[item]])
                } else {
                    emit("missing", item, "-", expected_ref[item], "not-observed")
                }
            }
            for (item in actual) {
                if (!(item in expected))
                    emit("undeclared", item, actual[item], "-", actual_evidence[item])
            }
            for (i = 1; i <= tree_count; i++) {
                split(tree_rows[i], pair, SUBSEP)
                item = pair[1]
                ref = pair[2]
                if (!(item in expected)) {
                    if (!(item in actual) || actual[item] != ref)
                        emit("undeclared_tree", item, ref, "-", tree_evidence[tree_rows[i]])
                } else if (ref != expected_ref[item]) {
                    emit("other_revision", item, ref, expected_ref[item], tree_evidence[tree_rows[i]])
                }
            }
        }
    ' "$packages" "$inventory"
}

compare_command() {
    [ "$#" -le 1 ] || { usage >&2; return 2; }
    resolve_inventory "${1:-}"
    validate_inventory "$resolved_inventory"
    printf '# device\t%s\n' "$(meta "$resolved_inventory" device_id)"
    printf '# observed_at\t%s\n' "$(meta "$resolved_inventory" observed_at)"
    compare_inventory "$resolved_inventory"
}

packages_command() {
    [ "$#" -le 1 ] || { usage >&2; return 2; }
    resolve_inventory "${1:-}"
    validate_inventory "$resolved_inventory"
    printf '# device\t%s\n' "$(meta "$resolved_inventory" device_id)"
    printf '# observed_at\t%s\n' "$(meta "$resolved_inventory" observed_at)"
    printf '%s\n' '# kind<TAB>name<TAB>version<TAB>evidence'
    awk -F '\t' '$1 == "android_package" || $1 == "termux_package" { print }' "$resolved_inventory"
}

report_manager() {
    register=$manager_state/register.tsv
    printf '%s\n' '# device_id<TAB>name<TAB>model<TAB>target<TAB>observed_at<TAB>android_packages_sha256<TAB>termux_packages_sha256<TAB>current<TAB>missing<TAB>different<TAB>unconfirmed<TAB>unrecorded<TAB>undeclared<TAB>other_revision'
    [ -f "$register" ] || return 0

    while IFS="$tab" read -r id name manufacturer model target observed_at; do
        case ${id:-} in ''|'#'*) continue ;; esac
        inventory=$manager_state/devices/$id/inventory.tsv
        [ -f "$inventory" ] || continue
        comparison=$manager_state/.report.$$.tsv
        compare_inventory "$inventory" > "$comparison"
        counts=$(awk -F '\t' '
            /^#/ { next }
            $1 == "current" { current++ }
            $1 == "missing" { missing++ }
            $1 == "different" { different++ }
            $1 == "unconfirmed" { unconfirmed++ }
            $1 == "unrecorded" { unrecorded++ }
            $1 == "undeclared" || $1 == "undeclared_tree" { undeclared++ }
            $1 == "other_revision" { other_revision++ }
            END { printf "%d\t%d\t%d\t%d\t%d\t%d\t%d", current, missing, different, unconfirmed, unrecorded, undeclared, other_revision }
        ' "$comparison")
        rm -f "$comparison"
        android_packages_sha256=$(meta "$inventory" android_packages_sha256)
        termux_packages_sha256=$(meta "$inventory" termux_packages_sha256)
        [ -n "$android_packages_sha256" ] || android_packages_sha256=-
        [ -n "$termux_packages_sha256" ] || termux_packages_sha256=-
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$id" "$name" "$model" "$target" "$observed_at" \
            "$android_packages_sha256" "$termux_packages_sha256" "$counts"
    done < "$register"
}

command=${1:-}
case $command in
    inspect)
        [ "$#" -eq 1 ] || { usage >&2; exit 2; }
        inspect_device
        ;;
    record)
        shift
        record_inventory "$@"
        ;;
    compare)
        shift
        compare_command "$@"
        ;;
    packages)
        shift
        packages_command "$@"
        ;;
    report)
        [ "$#" -eq 1 ] || { usage >&2; exit 2; }
        report_manager
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
