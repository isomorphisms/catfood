#!/system/bin/sh
set -u

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
payload="$root/payload"
config="$root/config.sh"

[ -f "$config" ] || {
    printf 'acceptance bundle is missing %s\n' "$config" >&2
    exit 2
}
# shellcheck disable=SC1090
. "$config"

case ${TARGET:-} in
    phone|tablet) ;;
    *) printf 'invalid bundle target: %s\n' "${TARGET:-unset}" >&2; exit 2 ;;
esac

stamp=$(date -u '+%Y%m%dT%H%M%SZ' 2>/dev/null || printf '%s' unknown)
receipt_root=${ACCEPTANCE_RECEIPTS:-"$HOME/opt/receipts/device-acceptance-$TARGET-$stamp"}
work="$root/.work.$$"
summary="$receipt_root/summary.tsv"
failures=0

mkdir -p "$receipt_root" "$work"
printf 'test\tresult\texit_status\tlog\n' > "$summary"

cleanup() {
    rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM

sha256_value() {
    file=$1
    if command -v sha256sum >/dev/null 2>&1; then
        line=$(sha256sum "$file") || return 1
    elif [ -x /system/bin/toybox ]; then
        line=$(/system/bin/toybox sha256sum "$file") || return 1
    else
        printf '%s\n' 'no SHA-256 implementation is available' >&2
        return 127
    fi
    set -- $line
    printf '%s\n' "$1"
}

verify_sha256() {
    expected=$1
    file=$2
    actual=$(sha256_value "$file") || return $?
    if [ "$actual" != "$expected" ]; then
        printf 'SHA-256 mismatch for %s\nexpected %s\nactual   %s\n' "$file" "$expected" "$actual" >&2
        return 1
    fi
}

tar_extract() {
    archive=$1
    destination=$2
    mkdir -p "$destination"
    if command -v tar >/dev/null 2>&1; then
        tar -xzf "$archive" -C "$destination"
    elif [ -x /system/bin/toybox ]; then
        /system/bin/toybox tar -xzf "$archive" -C "$destination"
    else
        printf '%s\n' 'tar is unavailable' >&2
        return 127
    fi
}

tar_create() {
    archive=$1
    directory=$2
    if command -v tar >/dev/null 2>&1; then
        tar -czf "$archive" -C "$directory" .
    elif [ -x /system/bin/toybox ]; then
        /system/bin/toybox tar -czf "$archive" -C "$directory" .
    else
        printf '%s\n' 'tar is unavailable' >&2
        return 127
    fi
}

prepare_archive() {
    name=$1
    file=$2
    digest=$3
    destination="$work/$name"
    rm -rf "$destination"
    verify_sha256 "$digest" "$file" || return $?
    tar_extract "$file" "$destination" || return $?
}

run_case() {
    case_name=$1
    shift
    case_log="$receipt_root/$case_name.log"
    printf '\n=== %s ===\n' "$case_name"
    "$@" >"$case_log" 2>&1
    case_status=$?
    if [ "$case_status" -eq 0 ]; then
        case_result=PASS
    else
        case_result=FAIL
        failures=$((failures + 1))
    fi
    printf '%s\t%s\t%s\t%s\n' "$case_name" "$case_result" "$case_status" "$case_log" >> "$summary"
    cat "$case_log"
    printf '%s: %s\n' "$case_name" "$case_result"
}

device_identity_case() {
    [ -x /system/bin/getprop ] || {
        printf '%s\n' 'Android getprop is unavailable; this must run on the physical Android target'
        return 1
    }
    abi=$(/system/bin/getprop ro.product.cpu.abi | tr -d '\r')
    sdk=$(/system/bin/getprop ro.build.version.sdk | tr -d '\r')
    model=$(/system/bin/getprop ro.product.model | tr -d '\r')
    printf 'target=%s\nexpected_abi=%s\ndevice_abi=%s\nsdk=%s\nmodel=%s\n' \
        "$TARGET" "$EXPECTED_ABI" "$abi" "$sdk" "$model"
    [ "$abi" = "$EXPECTED_ABI" ]
}

grease_readable_case() {
    prepare_archive grease "$payload/$GREASE_FILE" "$GREASE_SHA256" || return $?
    ysh="$work/grease/bin/ysh"
    [ -x "$ysh" ] || { printf 'missing executable %s\n' "$ysh"; return 1; }
    output=$($ysh "$payload/grease-readable-smoke.ysh" 2>&1)
    status=$?
    printf '%s\n' "$output"
    [ "$status" -eq 0 ] || return "$status"
    printf '%s\n' "$output" | grep -Fq 'grease=42'
}

grease_ib_case() {
    [ "${GREASE_IB:-0}" = 1 ] || { printf '%s\n' 'not selected for this target'; return 0; }
    prepare_archive grease-ib "$payload/$GREASE_FILE" "$GREASE_SHA256" || return $?
    ysh="$work/grease-ib/bin/ysh"
    [ -x "$ysh" ] || { printf 'missing executable %s\n' "$ysh"; return 1; }
    index="$work/ib-index.bin"
    if command -v dd >/dev/null 2>&1; then
        dd if=/dev/zero of="$index" bs=4096 count=1 2>/dev/null || return $?
        printf fragment | dd of="$index" conv=notrunc 2>/dev/null || return $?
    elif [ -x /system/bin/toybox ]; then
        /system/bin/toybox dd if=/dev/zero of="$index" bs=4096 count=1 2>/dev/null || return $?
        printf fragment | /system/bin/toybox dd of="$index" conv=notrunc 2>/dev/null || return $?
    else
        printf '%s\n' 'dd is unavailable'
        return 127
    fi
    "$ysh" "$payload/ib-mapped-index.ysh" "$index" || return $?
    if command -v dd >/dev/null 2>&1; then
        prefix=$(dd if="$index" bs=1 count=8 2>/dev/null)
    else
        prefix=$(/system/bin/toybox dd if="$index" bs=1 count=8 2>/dev/null)
    fi
    printf 'persisted=%s\n' "$prefix"
    [ "$prefix" = pensieve ]
}

cloud_storage_help_case() {
    verify_sha256 "$CLOUD_STORAGE_SHA256" "$payload/$CLOUD_STORAGE_FILE" || return $?
    prepare_archive grease-cloud "$payload/$GREASE_FILE" "$GREASE_SHA256" || return $?
    ysh="$work/grease-cloud/bin/ysh"
    output=$($ysh "$payload/$CLOUD_STORAGE_FILE" --help 2>&1)
    status=$?
    printf '%s\n' "$output"
    [ "$status" -eq 0 ] || return "$status"
    printf '%s\n' "$output" | grep -Fq 'usage: google-drive-unzip'
}

ike_case() {
    prepare_archive ike "$payload/$IKE_FILE" "$IKE_SHA256" || return $?
    ike="$work/ike/bin/ike"
    [ -x "$ike" ] || { printf 'missing executable %s\n' "$ike"; return 1; }
    fixture="$work/ike-fixture"
    mkdir -p "$fixture"
    printf 'dependency\n' > "$fixture/input.txt"
    cat > "$fixture/Ikefile" <<'EOF_IKE'
accepted depends on input.txt
    printf 'ike=pass\n' > output.txt
EOF_IKE
    (cd "$fixture" && "$ike" accepted) || return $?
    [ "$(cat "$fixture/output.txt" 2>/dev/null)" = 'ike=pass' ] || {
        printf '%s\n' 'Ike recipe did not produce the expected output'
        return 1
    }
    printf '%s\n' 'ike=pass'
}

reddit_case() {
    prepare_archive reddit "$payload/$REDDIT_FILE" "$REDDIT_SHA256" || return $?
    dex="$work/reddit/classes.dex"
    library="$work/reddit/libreddit_cli.so"
    app_process=/system/bin/app_process
    [ -f "$dex" ] && [ -f "$library" ] && [ -x "$app_process" ] || {
        printf '%s\n' 'Reddit DEX/JNI bundle or app_process is incomplete'
        return 1
    }

    url_output="$work/reddit-url.txt"
    CLASSPATH="$dex" "$app_process" "-Dreddit.library=$library" /system/bin \
        org.isomorphisms.reddit.RedditCli url 'computer science degree regret' \
        >"$url_output" 2>&1
    url_status=$?
    cat "$url_output"
    [ "$url_status" -eq 0 ] || return "$url_status"
    grep -Fq 'q=computer%20science%20degree%20regret' "$url_output" || return 1

    token_output="$work/reddit-no-token.txt"
    REDDIT_ACCESS_TOKEN='' CLASSPATH="$dex" "$app_process" "-Dreddit.library=$library" /system/bin \
        org.isomorphisms.reddit.RedditCli search 'computer science degree regret' \
        >"$token_output" 2>&1
    token_status=$?
    cat "$token_output"
    [ "$token_status" -ne 0 ] || {
        printf '%s\n' 'Reddit search unexpectedly succeeded without a token'
        return 1
    }
    grep -Fq 'reddit: missing REDDIT_ACCESS_TOKEN' "$token_output"
}

catfood_migration_case() {
    bundle_ref=$(cat "$root/bundle-source-commit") || return $?
    case "$bundle_ref" in
        ???????*) ;;
        *) printf 'invalid bundle source commit: %s\n' "$bundle_ref"; return 1 ;;
    esac

    fixture_root="$work/catfood-fixture"
    fixture_stage="$fixture_root/stage"
    fixture_archive="$fixture_root/fixture.tar.gz"
    manifest="$fixture_root/manifests"
    mkdir -p "$fixture_stage/bin" "$manifest"
    cat > "$fixture_stage/bin/grease" <<'EOF_FIXTURE'
#!/system/bin/sh
printf '%s\n' 'fixture-pass'
EOF_FIXTURE
    chmod +x "$fixture_stage/bin/grease"
    tar_create "$fixture_archive" "$fixture_stage" || return $?
    fixture_sha=$(sha256_value "$fixture_archive") || return $?

    : > "$manifest/tools.tsv"
    printf 'grease\truntime\tpackage:fixture-phone\tpackage:fixture-tablet\tlegacy-migration-fixture\n' > "$manifest/delivery.tsv"
    {
        printf '# package\ttarget\tabi\tmode\tsource\tsource_ref\tpackage_ref\turl\tsha256\tcommand\tentrypoint\tmain_class\tjni_library\tjni_property\tinstall_requires\ttermux_packages\truntime_requires\tpackage_requires\n'
        printf 'fixture-phone\tphone\tarmeabi-v7a\tarchive\tisomorphisms/catfood\t%s\t%s\thttps://invalid.example/fixture-phone.tar.gz\t%s\tgrease\tbin/grease\t-\t-\t-\ttar\t-\t-\t-\n' "$bundle_ref" "$bundle_ref" "$fixture_sha"
        printf 'fixture-tablet\ttablet\tarm64-v8a\tarchive\tisomorphisms/catfood\t%s\t%s\thttps://invalid.example/fixture-tablet.tar.gz\t%s\tgrease\tbin/grease\t-\t-\t-\ttar\t-\t-\t-\n' "$bundle_ref" "$bundle_ref" "$fixture_sha"
    } > "$manifest/packages.tsv"

    package="fixture-$TARGET"
    installer="$payload/catfood/android/install.sh"
    [ -f "$installer" ] && [ -f "$payload/catfood/android/check.sh" ] || {
        printf '%s\n' 'bundle is missing the exact Cat Food installer/checker pair'
        return 1
    }

    workspace="$fixture_root/positive"
    mkdir -p "$workspace/bin" "$workspace/legacy" "$workspace/downloads"
    cp "$fixture_archive" "$workspace/downloads/$package-$fixture_sha"
    for name in R Rscript edric idris2 fieldmouse icu ib-smoke ick ithon osh ysh grease go_down_load gdl; do
        ln -s "$workspace/legacy/$name" "$workspace/bin/$name" || return $?
    done
    for name in az abe aa; do
        printf '#!/system/bin/sh\n# catfood az wrapper\nexit 99\n' > "$workspace/bin/$name"
        chmod +x "$workspace/bin/$name"
    done
    printf '%s\n' keep > "$workspace/bin/keep-me"

    CATFOOD_TARGET="$TARGET" \
    CATFOOD_DEVICE_ABI="$EXPECTED_ABI" \
    CATFOOD_ROOT="$workspace" \
    CATFOOD_TOOLS="$manifest/tools.tsv" \
    CATFOOD_ANDROID_DELIVERY="$manifest/delivery.tsv" \
    CATFOOD_ANDROID_PACKAGES="$manifest/packages.tsv" \
        sh "$installer" || return $?

    [ "$($workspace/bin/grease)" = fixture-pass ] || return 1
    [ "$(cat "$workspace/bin/keep-me")" = keep ] || return 1
    for name in R Rscript edric idris2 fieldmouse icu ib-smoke ick ithon osh ysh go_down_load gdl az abe aa; do
        [ ! -e "$workspace/bin/$name" ] && [ ! -L "$workspace/bin/$name" ] || {
            printf 'legacy Cat Food command remained: %s\n' "$name"
            return 1
        }
    done

    protected="$fixture_root/protected"
    mkdir -p "$protected/bin" "$protected/downloads"
    cp "$fixture_archive" "$protected/downloads/$package-$fixture_sha"
    printf '%s\n' user-owned > "$protected/bin/grease"
    CATFOOD_TARGET="$TARGET" \
    CATFOOD_DEVICE_ABI="$EXPECTED_ABI" \
    CATFOOD_ROOT="$protected" \
    CATFOOD_TOOLS="$manifest/tools.tsv" \
    CATFOOD_ANDROID_DELIVERY="$manifest/delivery.tsv" \
    CATFOOD_ANDROID_PACKAGES="$manifest/packages.tsv" \
        sh "$installer" >"$fixture_root/protected.log" 2>&1
    protected_status=$?
    cat "$fixture_root/protected.log"
    [ "$protected_status" -eq 4 ] || {
        printf 'expected protected-command refusal status 4, got %s\n' "$protected_status"
        return 1
    }
    [ "$(cat "$protected/bin/grease")" = user-owned ] || {
        printf '%s\n' 'protected user command was modified'
        return 1
    }
    printf '%s\n' 'legacy migration and arbitrary-user-command protection both passed'
}

powervr_case() {
    [ "${POWERVR_ENABLED:-0}" = 1 ] || { printf '%s\n' 'not selected for this target'; return 0; }
    prepare_archive powervr "$payload/$POWERVR_FILE" "$POWERVR_SHA256" || return $?
    command="$work/powervr/bin/powervr-accept"
    [ -x "$command" ] || { printf 'missing executable %s\n' "$command"; return 1; }
    evidence="$receipt_root/powervr-$TARGET-acceptance.txt"
    POWERVR_EVIDENCE="$evidence" "$command"
}

printf 'Cat Food physical acceptance batch\ntarget=%s\nbundle_source=%s\n\n' \
    "$TARGET" "$(cat "$root/bundle-source-commit")"

run_case device_identity device_identity_case
run_case catfood_legacy_migration catfood_migration_case
run_case grease_readable_syntax grease_readable_case
if [ "${GREASE_IB:-0}" = 1 ]; then
    run_case grease_ib_mapped_index grease_ib_case
fi
run_case cloud_storage_help cloud_storage_help_case
run_case ike_runtime ike_case
run_case reddit_direct_dex_jni reddit_case
if [ "${POWERVR_ENABLED:-0}" = 1 ]; then
    run_case powervr_vendor_driver powervr_case
fi

printf '\n=== summary ===\n'
cat "$summary"

receipt_archive="$receipt_root.tar.gz"
tar_create "$receipt_archive" "$receipt_root" >/dev/null 2>&1 || receipt_archive='(could not archive receipts)'
printf '\nreceipts: %s\nreceipt archive: %s\n' "$receipt_root" "$receipt_archive"

if [ "$failures" -ne 0 ]; then
    printf 'acceptance batch: FAIL (%s failed cases)\n' "$failures" >&2
    exit 1
fi
printf '%s\n' 'acceptance batch: PASS'
