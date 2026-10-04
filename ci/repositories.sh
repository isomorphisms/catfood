# Stage-zero repository identity: loaded before Grease is available.
# The caller supplies its verified Cat Food root.
catfood_repository_aliases=$root/repository-aliases.tsv

validate_repository_aliases() {
    awk -F '\t' '
        /^[[:space:]]*($|#)/ { next }
        NF != 3 || $1 !~ /^https:\/\/github[.]com\/[^/]+\/[^/]+$/ ||
        $2 !~ /^https:\/\/github[.]com\/[^/]+\/[^/]+$/ ||
        $3 !~ /^[0-9]+$/ || $1 == $2 {
            print "invalid repository alias at line " NR > "/dev/stderr"
            failed = 1
            next
        }
        seen[tolower($1)]++ {
            print "duplicate former repository: " $1 > "/dev/stderr"
            failed = 1
        }
        { current[tolower($2)] = 1 }
        END {
            for (repository in current)
                if (repository in seen) {
                    print "repository aliases must not chain: " repository > "/dev/stderr"
                    failed = 1
                }
            exit failed
        }
    ' "$catfood_repository_aliases"
}

canonical_repository_url() {
    repository_url=${1%/}
    repository_url=${repository_url%.git}
    case $repository_url in
        git@github.com:*)
            repository_url=https://github.com/${repository_url#git@github.com:}
            ;;
        ssh://git@github.com/*)
            repository_url=https://github.com/${repository_url#ssh://git@github.com/}
            ;;
    esac
    awk -F '\t' -v repository_url="$repository_url" '
        BEGIN { canonical = repository_url }
        /^[[:space:]]*($|#)/ { next }
        tolower($1) == tolower(repository_url) { canonical = $2 }
        END { print canonical }
    ' "$catfood_repository_aliases"
}

same_repository_url() {
    catfood_left_url=$(canonical_repository_url "$1") || return 1
    catfood_right_url=$(canonical_repository_url "$2") || return 1
    [ "$catfood_left_url" = "$catfood_right_url" ]
}

# All callers use errexit. Keep this call unconditional: Grease rejects shell
# functions in boolean contexts where errexit would be disabled.
validate_repository_aliases
