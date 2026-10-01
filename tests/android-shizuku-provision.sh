#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

stock_rish() {
    cat <<'EOF_RISH'
#!/system/bin/sh
BASEDIR=$(dirname "$0")
DEX="$BASEDIR"/rish_shizuku.dex
[ -z "$RISH_APPLICATION_ID" ] && export RISH_APPLICATION_ID="PKG"
/system/bin/app_process -Djava.class.path="$DEX" /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader "$@"
EOF_RISH
}

home=$temporary/home
export_dir=$home/storage/shared/Shizuku
install_dir=$home/opt
state_dir=$temporary/state
mkdir -p "$export_dir"
stock_rish > "$export_dir/rish"
printf '%s\n' dex-export-v1 > "$export_dir/rish_shizuku.dex"

# Dry run discovers internal shared storage but does not change the install tree.
dry=$(HOME="$home" CATFOOD_STATE_HOME="$state_dir" \
    CATFOOD_SHIZUKU_SKIP_RUNTIME_PROBE=1 \
    sh "$root/android/provision-shizuku-rish.sh" --dry-run)
printf '%s\n' "$dry" | grep -F 'source_kind=shared-export' >/dev/null
printf '%s\n' "$dry" | grep -F 'removable_storage=not_required' >/dev/null
printf '%s\n' "$dry" | grep -F 'would_install_rish' >/dev/null
test ! -e "$install_dir/rish"

# Apply copies the pair into private Termux storage, rewrites PKG for Termux,
# makes the DEX read-only, installs a stable PATH wrapper, and writes a receipt.
HOME="$home" CATFOOD_STATE_HOME="$state_dir" \
    CATFOOD_SHIZUKU_SKIP_RUNTIME_PROBE=1 \
    sh "$root/android/provision-shizuku-rish.sh" --apply >/dev/null

test -f "$install_dir/rish"
test -f "$install_dir/rish_shizuku.dex"
test -x "$install_dir/bin/rish"
grep -F 'RISH_APPLICATION_ID="com.termux"' "$install_dir/rish" >/dev/null
! grep -F 'RISH_APPLICATION_ID="PKG"' "$install_dir/rish" >/dev/null
test "$(stat -c '%a' "$install_dir/rish_shizuku.dex")" = 400
grep -F '# catfood shizuku rish wrapper' "$install_dir/bin/rish" >/dev/null
grep -F "'$install_dir/rish'" "$install_dir/bin/rish" >/dev/null
grep -F "$(printf 'source_kind\tshared-export')" "$state_dir/shizuku/installed.tsv" >/dev/null

a=$(sha256sum "$install_dir/rish" "$install_dir/rish_shizuku.dex")
HOME="$home" CATFOOD_STATE_HOME="$state_dir" \
    CATFOOD_SHIZUKU_SKIP_RUNTIME_PROBE=1 \
    sh "$root/android/provision-shizuku-rish.sh" --apply >/dev/null
b=$(sha256sum "$install_dir/rish" "$install_dir/rish_shizuku.dex")
test "$a" = "$b"

# If no shared export exists, Cat Food can take the exact matching assets from
# the installed Shizuku manager APK. The fixture uses fake pm/unzip commands so
# CI need not build or download an APK.
apk_home=$temporary/apk-home
apk_install=$apk_home/opt
apk_state=$temporary/apk-state
apk_assets=$temporary/apk-assets
fake_bin=$temporary/fake-bin
mkdir -p "$apk_home" "$apk_assets" "$fake_bin" "$apk_home/.cache"
stock_rish > "$apk_assets/rish"
printf '%s\n' dex-apk-v1 > "$apk_assets/rish_shizuku.dex"
: > "$temporary/base.apk"

cat > "$fake_bin/pm" <<'EOF_PM'
#!/bin/sh
if [ "${1:-}" = path ] && [ "${2:-}" = moe.shizuku.privileged.api ]; then
    printf 'package:%s\n' "${CATFOOD_TEST_APK:?}"
    exit 0
fi
exit 1
EOF_PM
cat > "$fake_bin/unzip" <<'EOF_UNZIP'
#!/bin/sh
[ "${1:-}" = -p ] || exit 2
asset=${3:-}
case $asset in
    assets/rish) cat "${CATFOOD_TEST_ASSETS:?}/rish" ;;
    assets/rish_shizuku.dex) cat "${CATFOOD_TEST_ASSETS:?}/rish_shizuku.dex" ;;
    *) exit 3 ;;
esac
EOF_UNZIP
chmod 0755 "$fake_bin/pm" "$fake_bin/unzip"

HOME="$apk_home" TMPDIR="$apk_home/.cache" CATFOOD_STATE_HOME="$apk_state" \
    CATFOOD_PM="$fake_bin/pm" CATFOOD_UNZIP="$fake_bin/unzip" \
    CATFOOD_TEST_APK="$temporary/base.apk" CATFOOD_TEST_ASSETS="$apk_assets" \
    CATFOOD_SHIZUKU_SKIP_RUNTIME_PROBE=1 \
    sh "$root/android/provision-shizuku-rish.sh" --apply > "$temporary/apk.out"
grep -F 'source_kind=installed-apk' "$temporary/apk.out" >/dev/null
grep -F 'RISH_APPLICATION_ID="com.termux"' "$apk_install/rish" >/dev/null
grep -Fqx 'dex-apk-v1' "$apk_install/rish_shizuku.dex"
grep -F "$(printf 'source_kind\tinstalled-apk')" "$apk_state/shizuku/installed.tsv" >/dev/null
test -z "$(find "$apk_home/.cache" -mindepth 1 -maxdepth 1 -name 'catfood-shizuku.*' -print 2>/dev/null || true)"

# A missing source is a visible pending state, not a removable-SD diagnostic.
empty_home=$temporary/empty-home
mkdir -p "$empty_home"
missing=$(HOME="$empty_home" CATFOOD_PM=/bin/false CATFOOD_UNZIP=/bin/false \
    sh "$root/android/provision-shizuku-rish.sh" --apply 2>&1)
printf '%s\n' "$missing" | grep -F "$(printf 'shizuku_rish\tpending\tsource=unavailable')" >/dev/null
printf '%s\n' "$missing" | grep -F 'removable SD storage is not involved' >/dev/null

# A half-export is treated as corrupt state rather than silently mixed with
# another source.
partial=$temporary/partial
mkdir -p "$partial"
stock_rish > "$partial/rish"
if HOME="$empty_home" CATFOOD_SHIZUKU_SOURCE_DIR="$partial" \
    sh "$root/android/provision-shizuku-rish.sh" --apply >/dev/null 2>&1; then
    printf '%s\n' 'partial Shizuku export unexpectedly passed' >&2
    exit 1
fi

printf '%s\n' 'Shizuku rish provisioning passes export, installed-APK, idempotence, and no-SD fixtures'
