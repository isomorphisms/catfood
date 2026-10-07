#!/bin/sh
# Stage-zero byte validation: required before Grease itself can be delivered.
# Receipt hashes are consistency fields, never the authority for payload bytes.
cf_hash() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    else /system/bin/toybox sha256sum "$1" | awk '{print $1}'; fi
}
cf_field() { awk -F '\t' -v key="$2" '$1 == key {print $2}' "$1"; }
cf_plan_hash() {
    (
        for cf_file in "$packages" "$delivery" "$restrictions" "$root/android/application-targets.tsv" "$root/android/conversation-targets.tsv"; do
            cf_hash "$cf_file" || exit
        done
    ) > "$1"
    cf_hash "$1"
}
cf_profile_hash() {
    cf_hash "$root/android/target.sh" > "$1"
    cf_hash "$1"
}
cf_procedure_hash() (
    cf_procedure=$(mktemp) || exit
    trap 'rm -f "$cf_procedure"' EXIT HUP INT TERM
    for cf_source in "$root/android/install.sh" "$root/android/content.sh" "$root/android/check.sh" "$root/android/target.sh"; do
        cf_hash "$cf_source" || exit
    done > "$cf_procedure"
    cf_hash "$cf_procedure"
)
cf_tree() {
    # Full directory membership, symlink identity and every regular file byte.
    # Restrict names to the package wire alphabet so lines cannot be ambiguous.
    (cd "$1" && find . -print | LC_ALL=C sort) > "$2.names" || return
    awk '$0 !~ /^[a-zA-Z0-9_.+\/-]+$/ || $0 ~ /(^|\/)\.\.(\/|$)/ {exit 1}' "$2.names" || return
    while IFS= read -r cf_name; do
        cf_path=$1/$cf_name
        if [ -L "$cf_path" ]; then
            cf_link=$(readlink "$cf_path") || return
            case $cf_link in ''|/*|*..*|*[!a-zA-Z0-9_.+/-]*) return 1 ;; esac
            printf 'link\t%s\t%s\n' "$cf_name" "$cf_link"
        elif [ -d "$cf_path" ]; then printf 'directory\t%s\n' "$cf_name"
        elif [ -f "$cf_path" ]; then
            printf 'file\t%s\t%s\n' "$cf_name" "$(cf_hash "$cf_path")"
        else return 1
        fi
    done < "$2.names" > "$2"
}
cf_extract() {
    cf_archive=$1; cf_mode=$2; cf_entry=$3; cf_destination=$4
    case $cf_mode in
        file) mkdir -p "$cf_destination/$(dirname "$cf_entry")"; cp "$cf_archive" "$cf_destination/$cf_entry" ;;
        archive|dex-jni)
            # Inspect names/types/links before extraction, not after a link may
            # have redirected a write. Unsupported archive features fail closed.
            tar -tzf "$cf_archive" > "$cf_destination.names" || return
            awk '$0 !~ /^[a-zA-Z0-9_.+\/-]+$/ || $0 ~ /(^|\/)\.\.(\/|$)/ || $0 ~ /^\// {exit 1}' "$cf_destination.names" || return
            tar -tvzf "$cf_archive" > "$cf_destination.types" || return
            awk 'substr($0,1,1) !~ /[-dl]/ {exit 1}
                 substr($0,1,1)=="l" {n=split($0,a," -> "); if(n!=2 || a[2] !~ /^[a-zA-Z0-9_.+\/-]+$/ || a[2] ~ /^\// || a[2] ~ /\.\./) exit 1}' "$cf_destination.types" || return
            tar -xzof "$cf_archive" -C "$cf_destination" ;;
        *) return 1 ;;
    esac
}
cf_wrapper() {
    # This is the existing fixed pre-Grease app_process compatibility boundary.
    cat <<EOF_WRAPPER
#!/bin/sh
# catfood android dex-jni wrapper
set -eu
root=\$(CDPATH='' cd -- "\$(dirname -- "\$0")/.." && pwd)
package_dir="\$root/packages/$1/$2"
app_process=\${CATFOOD_APP_PROCESS:-/system/bin/app_process}
exec env CLASSPATH="\$package_dir/$3" "\$app_process" "-D$4=\$package_dir/$5" /system/bin "$6" "\$@"
EOF_WRAPPER
}
cf_validate_content() (
    # Subshell protects the caller's installation variables from helper state.
    cf_receipt=$1
    cf_package=$(cf_field "$cf_receipt" package)
    cf_ref=$(cf_field "$cf_receipt" package_ref)
    cf_sha=$(cf_field "$cf_receipt" sha256)
    cf_mode=$(cf_field "$cf_receipt" mode)
    cf_dir=$(cf_field "$cf_receipt" installation_evidence)
    cf_workspace=$(dirname "$(dirname "$(dirname "$cf_dir")")")
    [ "$cf_dir" = "$cf_workspace/packages/$cf_package/$cf_ref" ] && [ ! -L "$cf_dir" ] && [ -d "$cf_dir" ] || exit 1
    for cf_parent in "$cf_workspace" "$cf_workspace/packages" "$cf_workspace/packages/$cf_package" "$cf_workspace/bin" "$cf_workspace/downloads"; do
        [ -d "$cf_parent" ] && [ ! -L "$cf_parent" ] || exit 1
    done
    if [ -n "${CATFOOD_ROOT:-}" ] && [ "$cf_workspace" != "$CATFOOD_ROOT" ]; then
        printf '%s\n' 'installation belongs to another workspace' >&2; exit 1
    fi
    cf_download=$cf_workspace/downloads/$cf_package-$cf_sha
    [ -f "$cf_download" ] && [ ! -L "$cf_download" ] && [ "$(cf_hash "$cf_download")" = "$cf_sha" ] || {
        printf '%s\n' 'pinned package bytes are missing or changed' >&2; exit 1;
    }
    cf_work=$(mktemp -d) || exit
    trap 'rm -rf "$cf_work"' EXIT HUP INT TERM
    mkdir "$cf_work/expected"
    cf_entry=$(awk -F '\t' -v p="$cf_package" '$1==p {print $11; exit}' "$packages")
    cf_extract "$cf_download" "$cf_mode" "$cf_entry" "$cf_work/expected" || exit
    [ "$(cf_hash "$cf_download")" = "$cf_sha" ] || { printf '%s\n' 'package bytes changed during validation' >&2; exit 1; }
    cf_tree "$cf_work/expected" "$cf_work/expected.tsv" || exit
    cf_tree "$cf_dir" "$cf_work/actual.tsv" || exit
    cmp -s "$cf_work/expected.tsv" "$cf_work/actual.tsv" || {
        printf '%s\n' 'installed payload differs from pinned package bytes' >&2; exit 1;
    }
    [ "$(cf_hash "$cf_work/actual.tsv")" = "$(cf_field "$cf_receipt" content_sha256)" ] || exit 1
    [ "$(cf_plan_hash "$cf_work/plan")" = "$(cf_field "$cf_receipt" plan_sha256)" ] || {
        printf '%s\n' 'application plan changed' >&2; exit 1;
    }
    [ "$(cf_profile_hash "$cf_work/profile")" = "$(cf_field "$cf_receipt" profile_sha256)" ] || exit 1
    awk -F '\t' -v p="$cf_package" '$1==p {print $10 "\t" $11 "\t" $12 "\t" $13 "\t" $14}' "$packages" > "$cf_work/entries"
    cf_tab=$(printf '\t')
    while IFS="$cf_tab" read -r cf_command cf_entry cf_main cf_jni cf_property; do
        cf_launcher=$cf_workspace/bin/$cf_command
        case $cf_mode in
            archive|file)
                [ -L "$cf_launcher" ] && [ "$(readlink "$cf_launcher")" = "$cf_dir/$cf_entry" ] && [ -x "$cf_launcher" ] || {
                    printf '%s\n' 'installed launcher changed' >&2; exit 1;
                } ;;
            dex-jni)
                cf_wrapper "$cf_package" "$cf_ref" "$cf_entry" "$cf_property" "$cf_jni" "$cf_main" > "$cf_work/wrapper"
                [ ! -L "$cf_launcher" ] && [ -x "$cf_launcher" ] && cmp -s "$cf_work/wrapper" "$cf_launcher" || {
                    printf '%s\n' 'installed launcher changed' >&2; exit 1;
                }
                [ "$(stat -c '%a' "$cf_dir/$cf_entry")" = 444 ] && [ "$(stat -c '%a' "$cf_dir/$cf_jni")" = 444 ] || exit 1 ;;
        esac
        printf '%s\t%s\n' "$cf_command" "$(cf_hash "$cf_launcher")"
    done < "$cf_work/entries" > "$cf_work/launchers"
    [ "$(cf_hash "$cf_work/launchers")" = "$(cf_field "$cf_receipt" launcher_sha256)" ] || exit 1
    cf_dependencies "$cf_receipt" "$cf_workspace" > "$cf_work/dependencies" || exit
    [ "$(cf_hash "$cf_work/dependencies")" = "$(cf_field "$cf_receipt" dependency_sha256)" ] || {
        printf '%s\n' 'installed dependency changed' >&2; exit 1;
    }
)
cf_dependencies() (
    cf_receipt=$1; cf_workspace=$2
    cf_requirements=$(cf_field "$cf_receipt" runtime_requires)
    cf_package_requirements=$(cf_field "$cf_receipt" package_requires)
    cf_target=$(cf_field "$cf_receipt" target)
    cf_device=$(cf_field "$cf_receipt" device_id)
    cf_package=$(cf_field "$cf_receipt" package)
    case :${CATFOOD_VALIDATION_CHAIN:-}: in *:"$cf_package":*) exit 1 ;; esac
    CATFOOD_VALIDATION_CHAIN=${CATFOOD_VALIDATION_CHAIN:-}:$cf_package
    export CATFOOD_VALIDATION_CHAIN
    if [ "$(cf_field "$cf_receipt" mode)" = dex-jni ]; then
        cf_executor=$(cf_field "$cf_receipt" executor_path)
        [ -x "$cf_executor" ] || exit 1
        printf 'executor\t%s\t%s\n' "$cf_executor" "$(cf_hash "$cf_executor")"
    fi
    IFS=,
    for cf_requirement in $cf_requirements; do
        case $cf_requirement in
            -) continue ;;
            command:*) cf_path=$(PATH="$cf_workspace/bin:$PATH" command -v "${cf_requirement#command:}") || exit ;;
            path:*) cf_path=${cf_requirement#path:} ;;
            *) exit 1 ;;
        esac
        [ -f "$cf_path" ] || exit 1
        printf '%s\t%s\t%s\n' "$cf_requirement" "$cf_path" "$(cf_hash "$cf_path")"
    done
    for cf_required in $cf_package_requirements; do
        [ "$cf_required" != - ] || continue
        cf_dependency=$cf_workspace/receipts/$cf_target-$cf_required.tsv
        sh "$root/android/check.sh" receipt "$cf_dependency" "$cf_target" "$cf_device" >/dev/null || exit
        printf 'package\t%s\t%s\n' "$cf_required" "$(cf_hash "$cf_dependency")"
    done
)
cf_observe_receipt() {
    cf_observed_receipt=$1
    cf_observed_target=$(cf_field "$cf_observed_receipt" target)
    cf_observed_scope=physical-observation
    if [ -n "${CATFOOD_GETPROP:-}${CATFOOD_APP_PROCESS:-}" ] || [ ! -x /system/bin/getprop ]; then
        cf_observed_scope=synthetic
    fi
    [ "$(cf_field "$cf_observed_receipt" evidence_scope)" = "$cf_observed_scope" ] || {
        printf '%s\n' 'receipt scope does not match current observation procedure' >&2; return 1;
    }
    catfood_android_require_device "$cf_observed_target" || return
    [ "$(catfood_android_device_id)" = "$(cf_field "$cf_observed_receipt" device_id)" ] || return 1
    if [ "$(cf_field "$cf_observed_receipt" mode)" = dex-jni ]; then
        [ "${CATFOOD_APP_PROCESS:-/system/bin/app_process}" = "$(cf_field "$cf_observed_receipt" executor_path)" ] || {
            printf '%s\n' 'execution dependency path changed' >&2; return 1;
        }
    fi
    for cf_pair in 'device_product:ro.product.device' 'device_model:ro.product.model' 'device_fingerprint:ro.build.fingerprint' 'abi:ro.product.cpu.abi'; do
        cf_actual=$(catfood_android_getprop "${cf_pair#*:}") || return
        [ -n "$cf_actual" ] || cf_actual=-
        [ "$cf_actual" = "$(cf_field "$cf_observed_receipt" "${cf_pair%%:*}")" ] || {
            printf 'mutable device fact changed: %s\n' "${cf_pair%%:*}" >&2; return 1;
        }
    done
}
