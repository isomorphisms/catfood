#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
workspace=${CATFOOD_ROOT:-/opt}
manifest=${CATFOOD_MANIFEST:-$root/tools.tsv}
projects=${CATFOOD_RELEASE_PROJECTS:-$root/release-projects.txt}
build_root=${CATFOOD_BUILD_ROOT:-$workspace/.build}
receipt_dir=$build_root/receipts
receipt=$receipt_dir/release-status.tsv
api=${CATFOOD_GITHUB_API:-https://api.github.com}
failures=0

command -v git >/dev/null 2>&1 || {
    printf '%s\n' 'release checking needs git' >&2
    exit 127
}
command -v curl >/dev/null 2>&1 || {
    printf '%s\n' 'release checking needs curl' >&2
    exit 127
}
command -v jq >/dev/null 2>&1 || {
    printf '%s\n' 'release checking needs jq' >&2
    exit 127
}

temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
mkdir -p "$receipt_dir"
next_receipt=$temporary/release-status.tsv
printf 'project\tcheckout_sha\tremote_sha\trelease_tag\trelease_sha\tstatus\n' > "$next_receipt"

github_release() {
    url=$1
    body=$2
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl -sS -L \
            -H 'Accept: application/vnd.github+json' \
            -H 'X-GitHub-Api-Version: 2022-11-28' \
            -H "Authorization: Bearer $GITHUB_TOKEN" \
            -H 'User-Agent: catfood-release-check' \
            -o "$body" -w '%{http_code}' "$url"
    else
        curl -sS -L \
            -H 'Accept: application/vnd.github+json' \
            -H 'X-GitHub-Api-Version: 2022-11-28' \
            -H 'User-Agent: catfood-release-check' \
            -o "$body" -w '%{http_code}' "$url"
    fi
}

manifest_row() {
    wanted=$1
    awk -v wanted="$wanted" '
        /^[[:space:]]*($|#)/ { next }
        $1 == wanted { print; matches++ }
        END { if (matches != 1) exit 1 }
    ' "$manifest"
}

while IFS= read -r name || [ -n "${name:-}" ]; do
    case ${name:-} in
        ''|'#'*) continue ;;
    esac

    row=$(manifest_row "$name") || {
        printf '%-22s missing or duplicated in %s\n' "$name" "$manifest" >&2
        failures=1
        continue
    }
    set -- $row
    repository=$2
    branch=$3
    checkout=$workspace/$name

    checkout_sha=-
    remote_sha=-
    release_tag=-
    release_sha=-
    status=unresolved

    if [ ! -e "$checkout/.git" ]; then
        status=checkout-missing
        failures=1
    else
        checkout_sha=$(git -C "$checkout" rev-parse HEAD)
        remote_sha=$(git ls-remote --exit-code --heads "$repository" "refs/heads/$branch" |
            awk 'NR == 1 { print $1 }') || remote_sha=-

        if [ "$remote_sha" = - ]; then
            status=remote-branch-missing
            failures=1
        elif [ "$checkout_sha" != "$remote_sha" ]; then
            status=checkout-stale
            failures=1
        else
            owner_repository=${repository#https://github.com/}
            owner_repository=${owner_repository%.git}
            body=$temporary/$(printf '%s' "$name" | tr '/.' '__').json
            http_status=$(github_release "$api/repos/$owner_repository/releases/latest" "$body") || {
                http_status=000
            }

            case $http_status in
                200)
                    release_tag=$(jq -er '.tag_name | select(type == "string" and length > 0)' "$body") || {
                        release_tag=-
                    }
                    if [ "$release_tag" = - ]; then
                        status=release-response-invalid
                        failures=1
                    else
                        tag_refs=$(git ls-remote --tags "$repository" \
                            "refs/tags/$release_tag" "refs/tags/$release_tag^{}") || tag_refs=
                        release_sha=$(printf '%s\n' "$tag_refs" | awk '
                            /[\^][{][}]$/ { peeled = $1 }
                            NR == 1 { direct = $1 }
                            END { if (peeled != "") print peeled; else if (direct != "") print direct }
                        ')
                        if [ -z "$release_sha" ]; then
                            release_sha=-
                            status=release-tag-missing
                            failures=1
                        elif [ "$release_sha" = "$remote_sha" ]; then
                            status=released-current
                        else
                            status=release-behind
                            failures=1
                        fi
                    fi
                    ;;
                404)
                    # These repositories are young and currently have no GitHub
                    # releases. Record that fact without pretending a release is
                    # current or preventing a fresh source workbench from existing.
                    status=unreleased
                    ;;
                *)
                    status=release-query-failed-$http_status
                    failures=1
                    ;;
            esac
        fi
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$name" "$checkout_sha" "$remote_sha" "$release_tag" "$release_sha" "$status" \
        >> "$next_receipt"
    printf '%-22s %s\n' "$name" "$status"
done < "$projects"

mv "$next_receipt" "$receipt"
printf 'release receipt: %s\n' "$receipt"

if [ "$failures" -ne 0 ]; then
    printf '%s\n' 'cat food release/source freshness has failures' >&2
    exit 1
fi

printf '%s\n' 'cat food release/source freshness checked'
