#!/bin/sh
set -eu

self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$self_dir/../.." && pwd)
out_dir="$repo_root/android/apks"
tmp_dir="$out_dir/.collect.$$"
pinned_manifest="$out_dir/pinned-general.tsv"

cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup 0 1 2 15

for command_name in curl jq unzip sha256sum awk sort grep tr wc cp rm mkdir; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf '%s\n' "missing required command: $command_name" >&2
        exit 1
    }
done

github_api_get() {
    url=$1
    output=$2
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl -fsSL             -A 'catfood-apk-shelf/1'             -H 'Accept: application/vnd.github+json'             -H "Authorization: Bearer $GITHUB_TOKEN"             "$url"             -o "$output"
    else
        curl -fsSL             -A 'catfood-apk-shelf/1'             -H 'Accept: application/vnd.github+json'             "$url"             -o "$output"
    fi
}

rm -rf "$tmp_dir"
mkdir -p "$tmp_dir/general-dex" "$tmp_dir/miro-a1" "$tmp_dir/tab-p10-row"

header='repository\tsource_kind\tsource_ref\tasset\tfile\tsha256\tbytes\tnative_abis\turl'
general_manifest="$tmp_dir/general-dex/manifest.tsv"
miro_manifest="$tmp_dir/miro-a1/manifest.tsv"
tablet_manifest="$tmp_dir/tab-p10-row/manifest.tsv"
runtime_names="$tmp_dir/runtime-names"
runtime_repos="$tmp_dir/runtime-repos"

printf '%b\n' "$header" > "$general_manifest"
printf '%b\n' "$header" > "$miro_manifest"
printf '%b\n' "$header" > "$tablet_manifest"

awk '
    $0 !~ /^#/ && NF >= 4 && $2 == "runtime" { print $1 }
' "$repo_root/android/delivery.tsv" | sort -u > "$runtime_names"

: > "$runtime_repos"
while read -r name repository branch_name submodules; do
    case "$name" in
        ''|'#'*) continue ;;
    esac
    if ! grep -Fqx "$name" "$runtime_names"; then
        continue
    fi
    case "$repository" in
        https://github.com/*.git|https://github.com/*)
            github_repo=${repository#https://github.com/}
            github_repo=${github_repo%.git}
            printf '%s\n' "$github_repo" >> "$runtime_repos"
            ;;
    esac
done < "$repo_root/tools.tsv"

printf '%s\n' 'isomorphisms/grease' >> "$runtime_repos"
sort -u "$runtime_repos" -o "$runtime_repos"

failed=0

while IFS= read -r github_repo; do
    [ -n "$github_repo" ] || continue

    releases_json="$tmp_dir/releases.json"
    assets_tsv="$tmp_dir/assets.tsv"

    if ! github_api_get         "https://api.github.com/repos/$github_repo/releases?per_page=100"         "$releases_json"
    then
        printf '%s\n' "failed to query releases: $github_repo" >&2
        failed=1
        continue
    fi

    if ! jq -r '
        [
          .[]
          | select(
              [ .assets[]? | (.name // "" | ascii_downcase | endswith(".apk")) ]
              | any
            )
        ][0] as $release
        | if $release == null then
            empty
          else
            $release.assets[]
            | select(.name // "" | ascii_downcase | endswith(".apk"))
            | [$release.tag_name, .name, .browser_download_url]
            | @tsv
          end
    ' "$releases_json" > "$assets_tsv"
    then
        printf '%s\n' "failed to parse releases: $github_repo" >&2
        failed=1
        continue
    fi

    [ -s "$assets_tsv" ] || continue

    tab=$(printf '\t')
    while IFS="$tab" read -r release_tag asset_name asset_url; do
        [ -n "$asset_name" ] || continue

        flat_repo=$(printf '%s' "$github_repo" | tr '/' '-')
        shelf_name="$flat_repo--$asset_name"
        downloaded="$tmp_dir/$shelf_name"

        if ! curl -fsSL -A 'catfood-apk-shelf/1' "$asset_url" -o "$downloaded"; then
            printf '%s\n' "failed to download APK: $github_repo $release_tag $asset_name" >&2
            failed=1
            continue
        fi

        if ! unzip -tq "$downloaded" >/dev/null 2>&1; then
            printf '%s\n' "release asset is not a readable APK/ZIP: $github_repo $release_tag $asset_name" >&2
            failed=1
            rm -f "$downloaded"
            continue
        fi

        native_abis=$(
            unzip -Z1 "$downloaded"             | awk -F/ '$1 == "lib" && NF >= 3 { print $2 }'             | sort -u             | awk 'BEGIN { first=1 } { if (!first) printf ","; printf "%s", $0; first=0 } END { if (first) printf "-" }'
        )
        sha256=$(sha256sum "$downloaded" | awk '{print $1}')
        bytes=$(wc -c < "$downloaded" | tr -d ' ')

        if [ "$native_abis" = "-" ]; then
            cp "$downloaded" "$tmp_dir/general-dex/$shelf_name"
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n'                 "$github_repo" release "$release_tag" "$asset_name" "$shelf_name" "$sha256" "$bytes" "$native_abis" "$asset_url"                 >> "$general_manifest"
        else
            case ",$native_abis," in
                *,armeabi-v7a,*)
                    cp "$downloaded" "$tmp_dir/miro-a1/$shelf_name"
                    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n'                         "$github_repo" release "$release_tag" "$asset_name" "$shelf_name" "$sha256" "$bytes" "$native_abis" "$asset_url"                         >> "$miro_manifest"
                    ;;
            esac
            case ",$native_abis," in
                *,arm64-v8a,*)
                    cp "$downloaded" "$tmp_dir/tab-p10-row/$shelf_name"
                    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n'                         "$github_repo" release "$release_tag" "$asset_name" "$shelf_name" "$sha256" "$bytes" "$native_abis" "$asset_url"                         >> "$tablet_manifest"
                    ;;
            esac
        fi

        rm -f "$downloaded"
    done < "$assets_tsv"
done < "$runtime_repos"

if [ -f "$pinned_manifest" ]; then
    tab=$(printf '\t')
    while IFS="$tab" read -r repository source_kind source_ref asset file sha256 bytes native_abis url; do
        case "$repository" in
            ''|'#'*|repository) continue ;;
        esac
        source_file="$out_dir/general-dex/$file"
        if [ ! -f "$source_file" ]; then
            printf '%s\n' "pinned general APK is missing: $source_file" >&2
            failed=1
            continue
        fi
        got_sha=$(sha256sum "$source_file" | awk '{print $1}')
        got_bytes=$(wc -c < "$source_file" | tr -d ' ')
        if [ "$got_sha" != "$sha256" ] || [ "$got_bytes" != "$bytes" ]; then
            printf '%s\n' "pinned general APK identity mismatch: $file" >&2
            failed=1
            continue
        fi
        if [ "$native_abis" != "-" ]; then
            printf '%s\n' "pinned general APK declares native ABI payload: $file" >&2
            failed=1
            continue
        fi
        cp "$source_file" "$tmp_dir/general-dex/$file"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n'             "$repository" "$source_kind" "$source_ref" "$asset" "$file" "$sha256" "$bytes" "$native_abis" "$url"             >> "$general_manifest"
    done < "$pinned_manifest"
fi

if [ "$failed" -ne 0 ]; then
    printf '%s\n' 'APK shelf collection failed; existing shelves were left unchanged.' >&2
    exit 1
fi

general_count=$(awk 'END { print NR - 1 }' "$general_manifest")
miro_count=$(awk 'END { print NR - 1 }' "$miro_manifest")
tablet_count=$(awk 'END { print NR - 1 }' "$tablet_manifest")

if [ "$general_count" -le 0 ] || [ "$miro_count" -le 0 ] || [ "$tablet_count" -le 0 ]; then
    printf '%s\n' "APK shelf collection produced general=$general_count miro=$miro_count tablet=$tablet_count; existing shelves were left unchanged." >&2
    exit 1
fi

rm -rf "$out_dir/general-dex" "$out_dir/miro-a1" "$out_dir/tab-p10-row"
mkdir -p "$out_dir/general-dex" "$out_dir/miro-a1" "$out_dir/tab-p10-row"
cp -R "$tmp_dir/general-dex/." "$out_dir/general-dex/"
cp -R "$tmp_dir/miro-a1/." "$out_dir/miro-a1/"
cp -R "$tmp_dir/tab-p10-row/." "$out_dir/tab-p10-row/"

printf '%s\n' "General DEX APKs: $general_count"
printf '%s\n' "MIRO A1 native APKs: $miro_count"
printf '%s\n' "TAB_P10_ROW native APKs: $tablet_count"
