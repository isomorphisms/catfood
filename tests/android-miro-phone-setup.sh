#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
fake_bin=$temporary/bin
state=$temporary/state
mkdir -p "$fake_bin" "$state"

cat > "$state/installed" <<'EOF_INSTALLED'
com.king.candycrushsaga
com.google.android.apps.magazines
com.google.android.googlequicksearchbox
com.openai.chatgpt
com.termux
com.vendor.mystery.newsfeed
EOF_INSTALLED
: > "$state/disabled"
: > "$state/mutations"
cat > "$state/settings" <<'EOF_SETTINGS'
secure|lock_screen_show_notifications|1
secure|lock_screen_allow_private_notifications|1
secure|notification_badging|1
global|heads_up_notifications_enabled|1
EOF_SETTINGS

cat > "$fake_bin/getprop" <<'EOF_GETPROP'
#!/bin/sh
case $1 in
  ro.product.model) echo A1 ;;
  ro.product.manufacturer) echo MIRO ;;
  ro.build.version.release) echo 14 ;;
  ro.product.cpu.abi) echo armeabi-v7a ;;
  ro.build.characteristics) echo default ;;
  *) echo unknown ;;
esac
EOF_GETPROP

cat > "$fake_bin/id" <<'EOF_ID'
#!/bin/sh
[ "${1:-}" = -u ] && { echo 2000; exit 0; }
exec /usr/bin/id "$@"
EOF_ID

cat > "$fake_bin/am" <<'EOF_AM'
#!/bin/sh
[ "${1:-}" = get-current-user ] && { echo 0; exit 0; }
exit 2
EOF_AM

cat > "$fake_bin/pm" <<'EOF_PM'
#!/bin/sh
set -eu
state=${CATFOOD_TEST_STATE:?}
command=${1:-}
shift || true
case $command in
  list)
    [ "${1:-}" = packages ] || exit 2
    shift
    disabled=0
    third_party=0
    filter=
    while [ "$#" -gt 0 ]; do
      case $1 in
        -d) disabled=1 ;;
        -3) third_party=1 ;;
        --user) shift ;;
        *) filter=$1 ;;
      esac
      shift
    done
    source=$state/installed
    [ "$disabled" -eq 1 ] && source=$state/disabled
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      if [ -n "$filter" ] && [ "$p" != "$filter" ]; then continue; fi
      if [ "$third_party" -eq 1 ]; then
        case $p in
          com.king.*|com.openai.*|com.termux|com.vendor.*) ;;
          *) continue ;;
        esac
      fi
      printf 'package:%s\n' "$p"
    done < "$source"
    ;;
  disable-user)
    [ "${1:-}" = --user ] || exit 2
    shift 2
    p=${1:?}
    printf 'disable\t%s\n' "$p" >> "$state/mutations"
    grep -Fqx "$p" "$state/disabled" 2>/dev/null || printf '%s\n' "$p" >> "$state/disabled"
    echo "Package $p new state: disabled-user"
    ;;
  uninstall)
    [ "${1:-}" = --user ] || exit 2
    shift 2
    p=${1:?}
    printf 'uninstall\t%s\n' "$p" >> "$state/mutations"
    awk -v p="$p" '$0 != p' "$state/installed" > "$state/installed.tmp"
    mv "$state/installed.tmp" "$state/installed"
    awk -v p="$p" '$0 != p' "$state/disabled" > "$state/disabled.tmp"
    mv "$state/disabled.tmp" "$state/disabled"
    echo Success
    ;;
  *) exit 2 ;;
esac
EOF_PM

cat > "$fake_bin/settings" <<'EOF_SETTINGS_CMD'
#!/bin/sh
set -eu
state=${CATFOOD_TEST_STATE:?}
command=${1:?}
namespace=${2:?}
key=${3:?}
case $command in
  get)
    awk -F '|' -v n="$namespace" -v k="$key" '$1==n && $2==k {print $3; found=1} END {if(!found) print "null"}' "$state/settings"
    ;;
  put)
    value=${4:?}
    printf 'setting\t%s\t%s\t%s\n' "$namespace" "$key" "$value" >> "$state/mutations"
    awk -F '|' -v OFS='|' -v n="$namespace" -v k="$key" -v v="$value" '
      $1==n && $2==k {$3=v; found=1} {print} END {if(!found) print n,k,v}
    ' "$state/settings" > "$state/settings.tmp"
    mv "$state/settings.tmp" "$state/settings"
    ;;
  *) exit 2 ;;
esac
EOF_SETTINGS_CMD
chmod 0755 "$fake_bin"/*

run_setup() {
  PATH="$fake_bin:$PATH" CATFOOD_TEST_STATE="$state" \
    sh "$root/android/miro-phone-setup.sh" "$@"
}

# Dry run must expose exact intended actions but perform no mutation.
dry=$(run_setup --scope android --dry-run --level attention)
printf '%s\n' "$dry" | grep -F 'would_uninstall_for_user' | grep -F 'com.king.candycrushsaga' >/dev/null
printf '%s\n' "$dry" | grep -F 'would_disable' | grep -F 'com.google.android.apps.magazines' >/dev/null
printf '%s\n' "$dry" | grep -F 'third_party' | grep -F 'review' | grep -F 'com.vendor.mystery.newsfeed' >/dev/null
test ! -s "$state/mutations"
grep -Fqx 'com.king.candycrushsaga' "$state/installed"

# Attention apply removes the game, disables News, changes exactly three settings,
# and leaves the aggressive Google-app target and unknown vendor package alone.
run_setup --scope android --apply --level attention >/dev/null
! grep -Fqx 'com.king.candycrushsaga' "$state/installed"
grep -Fqx 'com.google.android.apps.magazines' "$state/disabled"
grep -Fqx 'com.google.android.googlequicksearchbox' "$state/installed"
grep -Fqx 'com.vendor.mystery.newsfeed' "$state/installed"
grep -Fqx 'secure|lock_screen_show_notifications|0' "$state/settings"
grep -Fqx 'secure|lock_screen_allow_private_notifications|0' "$state/settings"
grep -Fqx 'secure|notification_badging|0' "$state/settings"
grep -Fqx 'global|heads_up_notifications_enabled|1' "$state/settings"

first_count=$(wc -l < "$state/mutations" | tr -d ' ')
run_setup --scope android --apply --level attention >/dev/null
second_count=$(wc -l < "$state/mutations" | tr -d ' ')
[ "$first_count" = "$second_count" ] || {
  printf 'second apply mutated state again: first=%s second=%s\n' "$first_count" "$second_count" >&2
  exit 1
}

# Aggressive adds the remaining selected targets/settings and is itself repeatable.
run_setup --scope android --apply --level aggressive >/dev/null
grep -Fqx 'com.google.android.googlequicksearchbox' "$state/disabled"
grep -Fqx 'global|heads_up_notifications_enabled|0' "$state/settings"
third_count=$(wc -l < "$state/mutations" | tr -d ' ')
run_setup --scope android --apply --level aggressive >/dev/null
fourth_count=$(wc -l < "$state/mutations" | tr -d ' ')
[ "$third_count" = "$fourth_count" ]


# The same script's Termux dry-run must describe bootstrap/profile work without
# invoking the package manager or mutating the fake home.
termux_home=$temporary/termux-home
termux_bin=$temporary/termux-bin
mkdir -p "$termux_home" "$termux_bin"
cat > "$termux_bin/pkg" <<'EOF_PKG'
#!/bin/sh
printf '%s\n' "$*" >> "${CATFOOD_TEST_STATE:?}/termux-mutations"
EOF_PKG
cat > "$termux_bin/dpkg-query" <<'EOF_DPKG'
#!/bin/sh
exit 1
EOF_DPKG
cat > "$termux_bin/apt-mark" <<'EOF_APTMARK'
#!/bin/sh
[ "${1:-}" = showmanual ] && exit 0
exit 0
EOF_APTMARK
chmod 0755 "$termux_bin"/*
: > "$state/termux-mutations"
termux_dry=$(HOME="$termux_home" PREFIX=/data/data/com.termux/files/usr \
  PATH="$termux_bin:$fake_bin:$PATH" CATFOOD_TEST_STATE="$state" \
  sh "$root/android/miro-phone-setup.sh" --scope termux --dry-run --level attention)
printf '%s\n' "$termux_dry" | grep -F 'would_pkg_install' | grep -F 'git ca-certificates openssh tmux vim' >/dev/null
printf '%s\n' "$termux_dry" | grep -F 'would_clone_catfood' >/dev/null
printf '%s\n' "$termux_dry" | grep -F 'would_add_runtime_path' | grep -F '.bashrc' >/dev/null
test ! -s "$state/termux-mutations"

printf '%s\n' 'MIRO setup passes Android idempotence and Termux no-mutation dry-run tests'
