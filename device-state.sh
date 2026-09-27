#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
packages=${CATFOOD_ANDROID_PACKAGES:-"$root/android/packages.tsv"}
workspace=${CATFOOD_ROOT:-"$HOME/opt"}
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
device_state=${CATFOOD_DEVICE_STATE:-"$state_home/catfood/device"}
manager_state=${CATFOOD_MANAGER_STATE:-"$state_home/catfood/manager"}
tab=$(printf '\t')

usage() {
    cat <<'EOF'
usage: device-state.sh inspect
       device-state.sh record INVENTORY|-
       device-state.sh compare [DEVICE|INVENTORY]
       device-state.sh report

inspect   observe this Android device and emit a portable inventory
record    store an inventory in the Cat Food Manager device register
compare   compare an inventory with the current Android package profile
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

prop() {
    if command -v getprop >/dev/null 2>&1; then
        getprop "$1" 2>/dev/null | tr -d '\r' | head -n 1
    fi
}

detect_target() {
    case ${CATFOOD_TARGET:-} in
        phone|tablet)
            printf '%s\n' "$CATFOOD_TARGET"
            return 0
            ;;
    esac

    abi=${CATFOOD_DEVICE_ABI:-}
    [ -n "$abi" ] || abi=$(prop ro.product.cpu.abi)
    if [ -z "$abi" ]; then
        machine=$(uname -m 2>/dev/null || printf '%s\n' unknown)
        case $machine in
            armv7*|armv8l|arm) abi=armeabi-v7a ;;
            aarch64|arm64) abi=arm64-v8a ;;
        esac
    fi

    case $abi in
        armeabi-v7a) printf '%s\n' phone ;;
        arm64-v8a) printf '%s\n' tablet ;;
        *)
            printf 'Cat Food cannot classify this device from ABI: %s\n' "${abi:-unknown}" >&2
            return 2
            ;;
    esac
}

valid_device_id() {
    case $1 in
        ''|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-]*) return 1 ;;
        *) return 0 ;;
    esac
}

device_id() {
    if [ -n "${CATFOOD_DEVICE_ID:-}" ]; then
        valid_device_id "$CATFOOD_DEVICE_ID" || {
            printf 'unsafe CATFOOD_DEVICE_ID: %s\n' "$CATFOOD_DEVICE_ID" >&2
            return 2
        }
        printf '%s\n' "$CATFOOD_DEVICE_ID"
        return
    fi

    id_file=${CATFOOD_DEVICE_ID_FILE:-"$device_state/device-id"}
    if [ -f "$id_file" ]; then
        id=$(head -n 1 "$id_file" | tr -d '\r\n')
        valid_device_id "$id" || {
            printf 'invalid Cat Food device id file: %s\n' "$id_file" >&2
            return 2
        }
        printf '%s\n' "$id"
        return
    fi

    mkdir -p "$(dirname -- "$id_file")"
    if [ -r /proc/sys/kernel/random/uuid ]; then
        id=$(head -n 1 /proc/sys/kernel/random/uuid | tr -d '\r\n')
    else
        id="device-$(date -u +%Y%m%dT%H%M%SZ)-$$"
    fi
    valid_device_id "$id" || return 2
    temporary=$id_file.tmp.$$
    umask 077
    printf '%s\n' "$id" > "$temporary"
    mv "$temporary" "$id_file"
    printf '%s\n' "$id"
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
            if ($2 == "device_id") { device_id = $3; device_id_count++ }
            if ($2 == "observed_at") { observed_at = $3; observed_at_count++ }
            if ($2 == "target") { target = $3; target_count++ }
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
            if (target_count != 1 || (target != "phone" && target != "tablet")) {
                print FILENAME ": inventory target must be phone or tablet" > "/dev/stderr"
                failed = 1
            }
            exit failed
        }
    ' "$inventory"
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
    trap 'rm -f "$inventory"' EXIT HUP INT TERM

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
        row meta android_release "$(prop ro.build.version.release)" getprop
        row meta android_sdk "$(prop ro.build.version.sdk)" getprop
        row meta abi "$abi" getprop

        for receipt in "$workspace/receipts/$target-"*.tsv; do
            [ -f "$receipt" ] || continue
            package=$(awk -F '\t' '$1 == "package" { print $2; exit }' "$receipt")
            package_ref=$(awk -F '\t' '$1 == "package_ref" { print $2; exit }' "$receipt")
            installation=$(awk -F '\t' '$1 == "installation_result" { print $2; exit }' "$receipt")
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

        if command -v pm >/dev/null 2>&1; then
            pm list packages -3 2>/dev/null | while IFS= read -r package_line; do
                case $package_line in
                    package:*) row android_package "${package_line#package:}" - pm-user ;;
                esac
            done
        fi

        if command -v dpkg-query >/dev/null 2>&1; then
            dpkg-query -W -f='${Package}\t${Version}\n' 2>/dev/null |
            while IFS="$tab" read -r package version; do
                [ -n "$package" ] || continue
                row termux_package "$package" "${version:--}" dpkg-query
            done
        fi
    } > "$inventory"

    validate_inventory "$inventory"
    cp "$inventory" "$device_state/inventory.tsv"
    cp "$inventory" "$device_state/inspections/$stamp.tsv"
    cat "$inventory"
    rm -f "$inventory"
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

    awk -F '\t' -v target="$target" -v packages="$packages" -v inventory="$inventory" '
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
                    else if (actual_evidence[item] == "receipt:PASS")
                        emit("current", item, actual[item], expected_ref[item], actual_evidence[item])
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

report_manager() {
    register=$manager_state/register.tsv
    printf '%s\n' '# device_id<TAB>name<TAB>model<TAB>target<TAB>observed_at<TAB>current<TAB>missing<TAB>different<TAB>unconfirmed<TAB>unrecorded<TAB>undeclared<TAB>other_revision'
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
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$id" "$name" "$model" "$target" "$observed_at" "$counts"
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
