# Stage-zero source acquisition: usable before the language toolchain exists.
# Loaded by the existing dependency-free Cat Food entrypoint.

source_closure_git() {
    env -i PATH="$PATH" HOME="$HOME" GIT_CONFIG_NOSYSTEM=1 \
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
        GIT_NO_REPLACE_OBJECTS=1 GIT_TERMINAL_PROMPT=0 \
        http_proxy="${http_proxy:-}" https_proxy="${https_proxy:-}" \
        HTTP_PROXY="${HTTP_PROXY:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" \
        all_proxy="${all_proxy:-}" ALL_PROXY="${ALL_PROXY:-}" \
        no_proxy="${no_proxy:-}" NO_PROXY="${NO_PROXY:-}" \
        git -c core.hooksPath=/dev/null -c core.fsmonitor=false \
        -c core.fileMode=true -c core.symlinks=true "$@"
}

source_closure_error() {
    printf 'source closure: %s\n' "$*" >&2
    return 1
}

source_closure_path() {
    closure_newline='
'
    case $1 in
        ''|/*|.|..|./*|../*|*/../*|*/..|*/./*|*/.|*//*|*\\*|*'"'*|*"$closure_newline"*|*[[:cntrl:]]*) return 1 ;;
    esac
    return 0
}

source_closure_checkout() (
    closure_checkout=$1
    closure_repository=$2
    closure_commit=$3
    [ -d "$closure_checkout" ] || source_closure_error "missing checkout: $closure_checkout" || return 1
    closure_physical=$(CDPATH='' cd -- "$closure_checkout" && pwd -P) || return 1
    closure_top=$(source_closure_git -C "$closure_physical" rev-parse --show-toplevel) || return 1
    [ "$closure_top" = "$closure_physical" ] || source_closure_error 'partial checkout or parent repository' || return 1
    closure_origin=$(source_closure_git -C "$closure_physical" config --local --no-includes --get-all remote.origin.url) || return 1
    same_repository_url "$closure_origin" "$closure_repository" || source_closure_error 'wrong repository origin' || return 1
    closure_actual=$(source_closure_git -C "$closure_physical" rev-parse HEAD) || return 1
    [ "$closure_actual" = "$closure_commit" ] || source_closure_error 'wrong locked commit' || return 1
    closure_index=$(source_closure_git -C "$closure_physical" ls-files -v) || return 1
    if printf '%s\n' "$closure_index" | grep '^[a-zS]' >/dev/null; then
        source_closure_error 'index hides tracked content'; return 1
    fi
    closure_status=$(source_closure_git -C "$closure_physical" status --porcelain --untracked-files=all) || return 1
    [ -z "$closure_status" ] || source_closure_error 'partial or changed checkout' || return 1
    closure_sparse=$(source_closure_git -C "$closure_physical" config --bool core.sparseCheckout || :)
    [ "$closure_sparse" != true ] || source_closure_error 'sparse checkout is incomplete' || return 1
    # Status applies clean filters and line-ending normalization. Compare raw
    # working bytes to committed blobs as well, batching ordinary files.
    closure_raw=$(mktemp -d)
    trap 'rm -rf "$closure_raw"' EXIT HUP INT TERM
    source_closure_git -C "$closure_physical" -c core.quotePath=false ls-tree -r HEAD > "$closure_raw/tree" || return 1
    : > "$closure_raw/paths"
    : > "$closure_raw/expected"
    closure_tab=$(printf '\t')
    while IFS="$closure_tab" read -r closure_metadata closure_path; do
        source_closure_path "$closure_path" || source_closure_error 'unsupported tracked source path' || return 1
        closure_mode=${closure_metadata%% *}
        closure_blob=${closure_metadata##* }
        case $closure_mode in
            100644|100755)
                [ -f "$closure_physical/$closure_path" ] && [ ! -L "$closure_physical/$closure_path" ] || source_closure_error 'missing regular source file' || return 1
                printf '%s\n' "$closure_path" >> "$closure_raw/paths"
                printf '%s\n' "$closure_blob" >> "$closure_raw/expected"
                ;;
            120000)
                [ -L "$closure_physical/$closure_path" ] || source_closure_error 'missing source symlink' || return 1
                closure_target=$(readlink -n "$closure_physical/$closure_path" | source_closure_git -C "$closure_physical" hash-object --stdin) || return 1
                [ "$closure_target" = "$closure_blob" ] || source_closure_error 'source symlink bytes differ from commit' || return 1
                ;;
            160000) ;;
            *) source_closure_error 'unsupported source tree mode'; return 1 ;;
        esac
    done < "$closure_raw/tree"
    source_closure_git -C "$closure_physical" hash-object --no-filters --stdin-paths < "$closure_raw/paths" > "$closure_raw/actual" || return 1
    cmp -s "$closure_raw/expected" "$closure_raw/actual" || source_closure_error 'raw source bytes differ from commit' || return 1
)

# A child is a leaf when it has neither declarations nor gitlinks. An empty or
# comment-only .gitmodules file does not turn that leaf into a recursive owner.
source_closure_child_policy() (
    closure_child_checkout=$1
    closure_child_requested=$2
    closure_child_entries=$(source_closure_git -C "$closure_child_checkout" ls-tree -r HEAD) || return 1
    closure_child_links=$(printf '%s\n' "$closure_child_entries" | awk '$1 == "160000" { print }')
    closure_child_declarations=
    if source_closure_git -C "$closure_child_checkout" cat-file -e HEAD:.gitmodules 2>/dev/null; then
        source_closure_git -C "$closure_child_checkout" config --blob HEAD:.gitmodules --list >/dev/null || source_closure_error 'malformed submodule declarations' || return 1
        # Count incomplete submodule sections too; walk must reject those rather
        # than treating a missing path as an empty leaf.
        closure_child_declarations=$(source_closure_git -C "$closure_child_checkout" config --blob HEAD:.gitmodules --name-only --get-regexp '^submodule[.]' || :)
    fi
    if [ -n "$closure_child_links" ] || [ -n "$closure_child_declarations" ]; then
        printf '%s\n' "$closure_child_requested"
    else
        printf 'none\n'
    fi
)

# Walk the committed declarations, not caller-controlled submodule config.
# Each recursive invocation has private variables; the output has no host paths.
source_closure_walk() (
    closure_checkout=$1
    closure_prefix=$2
    closure_policy=$3
    closure_record=$4
    closure_tree_entries=$(source_closure_git -C "$closure_checkout" ls-tree -r HEAD) || return 1
    closure_links=$(printf '%s\n' "$closure_tree_entries" | awk '$1 == "160000" { print }')
    closure_keys=
    closure_all_keys=
    if source_closure_git -C "$closure_checkout" cat-file -e HEAD:.gitmodules 2>/dev/null; then
        source_closure_git -C "$closure_checkout" config --blob HEAD:.gitmodules --list >/dev/null || return 1
        closure_keys=$(source_closure_git -C "$closure_checkout" config --blob HEAD:.gitmodules --name-only --get-regexp '^submodule[.].*[.]path$' || :)
        closure_all_keys=$(source_closure_git -C "$closure_checkout" config --blob HEAD:.gitmodules --name-only --get-regexp '^submodule[.]' || :)
    fi
    if [ -z "$closure_keys" ]; then
        [ -z "$closure_links" ] || source_closure_error 'gitlink without declaration' || return 1
        [ -z "$closure_all_keys" ] || source_closure_error 'orphan submodule declaration' || return 1
        [ "$closure_policy" = none ] || source_closure_error 'submodule policy requires declarations' || return 1
        return 0
    fi
    [ "$closure_policy" != none ] || source_closure_error 'none policy has declared submodules' || return 1
    closure_groups='
'
    while IFS= read -r closure_key; do
        closure_groups="$closure_groups${closure_key%.path}
"
    done <<EOF
$closure_keys
EOF
    while IFS= read -r closure_key; do
        case $closure_groups in
            *"
${closure_key%.*}
"*) ;;
            *) source_closure_error 'orphan submodule declaration'; return 1 ;;
        esac
    done <<EOF
$closure_all_keys
EOF
    closure_count=0
    closure_seen='
'
    while IFS= read -r closure_key; do
        closure_path=$(source_closure_git -C "$closure_checkout" config --blob HEAD:.gitmodules --get-all "$closure_key") || return 1
        source_closure_path "$closure_path" || source_closure_error 'unsafe or duplicate submodule path' || return 1
        case $closure_seen in
            *"
$closure_path
"*) source_closure_error 'duplicate submodule path'; return 1 ;;
        esac
        closure_seen="$closure_seen$closure_path
"
        closure_entry=$(source_closure_git -C "$closure_checkout" ls-tree HEAD -- "$closure_path") || return 1
        closure_mode=$(printf '%s\n' "$closure_entry" | cut -d ' ' -f 1)
        closure_pin=$(printf '%s\n' "$closure_entry" | cut -d ' ' -f 3 | cut -f 1)
        [ "$closure_mode" = 160000 ] || source_closure_error 'declaration without gitlink' || return 1
        closure_url_key=${closure_key%.path}.url
        closure_url=$(source_closure_git -C "$closure_checkout" config --blob HEAD:.gitmodules --get-all "$closure_url_key") || return 1
        # Relative/non-GitHub transports need an explicitly reviewed adapter.
        case $closure_url in *'
'*) source_closure_error 'multiple submodule repository URLs'; return 1 ;; esac
        printf '%s\n' "$closure_url" | grep -E '^https://github[.]com/[^/[:space:]]+/[^/[:space:]]+[.]git$' >/dev/null || source_closure_error 'unsupported submodule repository URL' || return 1
        closure_url=$(canonical_repository_url "$closure_url") || return 1
        printf 'gitlink\t%s%s\t%s\t%s\t%s\n' "$closure_prefix" "$closure_path" "$closure_url" "$closure_pin" "$closure_policy" >> "$closure_record"
        if [ "$closure_policy" = preflight ] && [ -e "$closure_checkout/$closure_path/.git" ]; then
            source_closure_checkout "$closure_checkout/$closure_path" "$closure_url" "$closure_pin" || return 1
            closure_child_policy=$(source_closure_child_policy "$closure_checkout/$closure_path" preflight) || return 1
            source_closure_walk "$closure_checkout/$closure_path" "$closure_prefix$closure_path/" "$closure_child_policy" "$closure_record" || return 1
        fi
        if [ "$closure_policy" = recursive ]; then
            source_closure_checkout "$closure_checkout/$closure_path" "$closure_url" "$closure_pin" || return 1
            closure_child_policy=$(source_closure_child_policy "$closure_checkout/$closure_path" recursive) || return 1
            source_closure_walk "$closure_checkout/$closure_path" "$closure_prefix$closure_path/" "$closure_child_policy" "$closure_record" || return 1
        fi
        closure_count=$((closure_count + 1))
    done <<EOF
$closure_keys
EOF
    closure_link_count=$(printf '%s\n' "$closure_links" | awk 'NF { n++ } END { print n+0 }')
    [ "$closure_count" = "$closure_link_count" ] || source_closure_error 'gitlink/declaration mismatch' || return 1
)

source_closure_materialize() (
    closure_checkout=$1
    closure_preflight_file=$2
    # Validate this level before contacting any declared child. Existing child
    # origins are checked before sync can alter their configuration.
    source_closure_walk "$closure_checkout" '' preflight "$closure_preflight_file" || return 1
    source_closure_git -C "$closure_checkout" submodule sync >&2 || return 1
    # Explicit checkout prevents a local submodule.update=!command from running.
    source_closure_git -C "$closure_checkout" -c submodule.recurse=false -c fetch.recurseSubmodules=false submodule update --init --checkout --depth=1 >&2 || return 1
    closure_keys=$(source_closure_git -C "$closure_checkout" config --blob HEAD:.gitmodules --name-only --get-regexp '^submodule[.].*[.]path$') || return 1
    while IFS= read -r closure_key; do
        closure_path=$(source_closure_git -C "$closure_checkout" config --blob HEAD:.gitmodules --get "$closure_key") || return 1
        closure_child_policy=$(source_closure_child_policy "$closure_checkout/$closure_path" recursive) || return 1
        if [ "$closure_child_policy" = recursive ]; then
            source_closure_materialize "$closure_checkout/$closure_path" "$closure_preflight_file" || return 1
        fi
    done <<EOF
$closure_keys
EOF
)

source_closure_acquire() (
    closure_tool=$1
    closure_commit=$2
    closure_destination=$3
    closure_operation=$4
    case ${CATFOOD_TARGET:-} in
        container|cloud|hetzner) catfood_verify_workbench_target || return 1 ;;
        *) source_closure_error 'source acquisition requires an explicit host workbench target'; return 2 ;;
    esac
    case $closure_commit in ''|*[!0-9a-f]*) source_closure_error 'commit must be full lowercase SHA-1'; return 2 ;; esac
    [ "${#closure_commit}" -eq 40 ] || source_closure_error 'commit must be full lowercase SHA-1' || return 2
    case $closure_destination in /*) ;; *) source_closure_error 'destination must be absolute'; return 2 ;; esac
    printf '%s\n' "$closure_destination" | LC_ALL=C grep '[[:cntrl:]]' >/dev/null && return 2
    case $closure_operation in workbench|producer) ;; *) source_closure_error 'operation must be workbench or producer'; return 2 ;; esac
    CATFOOD_MANIFEST=${CATFOOD_MANIFEST:-$root/tools.tsv} sh "$root/check-manifest.sh" >&2 || return 1
    lookup_tool "$closure_tool" || return 2
    closure_repository=$lookup_repository
    closure_policy=$(awk -v name="$closure_tool" '$1 == name { print $4 }' "${CATFOOD_MANIFEST:-$root/tools.tsv}")
    case $closure_policy in none|skip|recursive) ;; *) source_closure_error 'missing or ambiguous inventory policy'; return 2 ;; esac
    if [ "$closure_operation" = producer ] && [ "$closure_policy" = skip ]; then closure_policy=recursive; fi
    # This operation is source-only and never invokes a producer or materializer.
    if [ -L "$closure_destination" ]; then source_closure_error 'symlink destination'; return 1; fi
    if [ ! -e "$closure_destination" ]; then
        mkdir -p "$closure_destination"
        source_closure_git init -q "$closure_destination" || return 1
        source_closure_git -C "$closure_destination" remote add origin "$closure_repository" || return 1
        source_closure_git -C "$closure_destination" -c fetch.recurseSubmodules=false fetch --depth=1 --no-tags origin "$closure_commit" >&2 || return 1
        source_closure_git -C "$closure_destination" cat-file -e "$closure_commit^{commit}" || return 1
        source_closure_git -C "$closure_destination" -c submodule.recurse=false checkout -q --detach "$closure_commit" >&2 || return 1
    fi
    source_closure_checkout "$closure_destination" "$closure_repository" "$closure_commit" || return 1
    closure_work=$(mktemp -d)
    trap 'rm -rf "$closure_work"' EXIT HUP INT TERM
    closure_record=$closure_work/material.tsv
    closure_tree=$(source_closure_git -C "$closure_destination" rev-parse 'HEAD^{tree}') || return 1
    printf 'schema\tcatfood-source-v1\nrepository\t%s\ncommit\t%s\ntree\t%s\nsubmodules\t%s\n' \
        "$(canonical_repository_url "$closure_repository")" "$closure_commit" "$closure_tree" "$closure_policy" > "$closure_record"
    # Validate all declarations before following any submodule URL.
    closure_preflight=$closure_policy
    [ "$closure_preflight" != recursive ] || closure_preflight=preflight
    source_closure_walk "$closure_destination" '' "$closure_preflight" "$closure_work/preflight.tsv" || return 1
    if [ "$closure_tool" = ick ]; then
        [ -f "$closure_destination/ick/SOURCE.lock" ] && [ ! -L "$closure_destination/ick/SOURCE.lock" ] || source_closure_error 'missing regular ICK source lock' || return 1
        closure_locked=$(sed -n 's/^gcc_commit=//p' "$closure_destination/ick/SOURCE.lock")
        closure_locked_repository=$(sed -n 's/^gcc_repository=//p' "$closure_destination/ick/SOURCE.lock")
        closure_gcc=$(source_closure_git -C "$closure_destination" ls-tree HEAD -- gcc | awk '$1 == "160000" { print $3 }')
        [ "$closure_locked" = "$closure_gcc" ] || source_closure_error 'GCC source lock differs from gitlink' || return 1
        closure_gcc_url=$(source_closure_git -C "$closure_destination" config --blob HEAD:.gitmodules --get submodule.gcc.url) || return 1
        same_repository_url "$closure_locked_repository" "$closure_gcc_url" || source_closure_error 'GCC source lock repository differs from declaration' || return 1
        for closure_material in ick/SOURCE.lock ick/OVERLAY.sha256 ick/PRUNE ick/materialize.sh; do
            [ -f "$closure_destination/$closure_material" ] && [ ! -L "$closure_destination/$closure_material" ] || source_closure_error "missing regular producer material: $closure_material" || return 1
            closure_digest=$(sha256sum "$closure_destination/$closure_material") || return 1
            printf 'material\t%s\t%s\n' "$closure_material" "${closure_digest%% *}" >> "$closure_record"
        done
    fi
    if [ "$closure_policy" = recursive ]; then
        source_closure_materialize "$closure_destination" "$closure_work/preflight.tsv" || return 1
    fi
    source_closure_walk "$closure_destination" '' "$closure_policy" "$closure_record" || return 1
    source_closure_checkout "$closure_destination" "$closure_repository" "$closure_commit" || return 1
    # The digest excludes local paths, attempt IDs and times. No receipt is trusted
    # on reuse: the complete source checks above run again on every invocation.
    LC_ALL=C sort "$closure_record" > "$closure_work/canonical.tsv" || return 1
    cat "$closure_work/canonical.tsv" || return 1
    closure_digest=$(sha256sum "$closure_work/canonical.tsv") || return 1
    printf 'sha256\t%s\n' "${closure_digest%% *}"
)
