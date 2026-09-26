#!/bin/sh
set -eu

red='\033[1;31m'
green='\033[1;32m'
cyan='\033[1;36m'
yellow='\033[1;33m'
reset='\033[0m'

section() { printf '\n%b== %s ==%b\n' "$cyan" "$1" "$reset"; }
action() { printf '%b-> %s%b\n' "$yellow" "$1" "$reset"; }
pass() { printf '%bPASS%b %s\n' "$green" "$reset" "$1"; }
warn() { printf '%bWARN%b %s\n' "$yellow" "$reset" "$1" >&2; }
fail() { printf '%bFAIL%b %s\n' "$red" "$reset" "$1" >&2; exit 1; }

usage() {
    cat <<'EOF_USAGE'
usage: miro-phone-setup.sh [OPTIONS]

Idempotent first-run cleanup and setup for MIRO phones.

Defaults are audit-only: no state is changed unless --apply is present.

  --dry-run                 report intended changes (default)
  --apply                   make changes
  --level safe              obvious games/promotional junk only
  --level attention         safe + news/social/streaming distractions (default)
  --level aggressive        attention + search/Discover/YouTube distractions
  --scope auto              Termux when run in Termux, Android when run as shell/root
  --scope termux            configure the Termux side only
  --scope android           configure Android packages/settings only
  --with-proot              install a Debian proot named catfood-debian
  --without-proot           do not install a proot rootfs (default)
  -h, --help                show this help

Android package/settings changes require Android shell/root authority. A stock
phone normally runs that phase through adb shell. Termux never pretends to have
that authority.
EOF_USAGE
}

mode=dry_run
level=attention
scope=auto
with_proot=0

while [ "$#" -gt 0 ]; do
    case $1 in
        --dry-run) mode=dry_run ;;
        --apply) mode=apply ;;
        --level)
            [ "$#" -ge 2 ] || fail '--level needs safe, attention, or aggressive'
            level=$2
            shift
            ;;
        --scope)
            [ "$#" -ge 2 ] || fail '--scope needs auto, termux, or android'
            scope=$2
            shift
            ;;
        --with-proot) with_proot=1 ;;
        --without-proot) with_proot=0 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; fail "unknown option: $1" ;;
    esac
    shift
done

case $level in safe|attention|aggressive) ;; *) fail "unknown level: $level" ;; esac
case $scope in auto|termux|android) ;; *) fail "unknown scope: $scope" ;; esac

level_number() {
    case $1 in
        safe) printf '%s\n' 1 ;;
        attention) printf '%s\n' 2 ;;
        aggressive) printf '%s\n' 3 ;;
    esac
}
selected_level=$(level_number "$level")

in_termux=0
case ${PREFIX:-} in /data/data/com.termux/*) in_termux=1 ;; esac
if [ "$scope" = auto ]; then
    if [ "$in_termux" -eq 1 ]; then
        scope=termux
    elif command -v pm >/dev/null 2>&1 && command -v settings >/dev/null 2>&1; then
        scope=android
    else
        fail 'cannot infer scope; use --scope termux or --scope android'
    fi
fi

get_prop() {
    if command -v getprop >/dev/null 2>&1; then
        getprop "$1" 2>/dev/null | tr -d '\r'
    else
        printf '%s\n' unknown
    fi
}

model=$(get_prop ro.product.model)
manufacturer=$(get_prop ro.product.manufacturer)
android_release=$(get_prop ro.build.version.release)
abi=$(get_prop ro.product.cpu.abi)
characteristics=$(get_prop ro.build.characteristics)

section 'Device identity'
printf 'mode=%s\n' "$mode"
printf 'level=%s\n' "$level"
printf 'scope=%s\n' "$scope"
printf 'manufacturer=%s\n' "$manufacturer"
printf 'model=%s\n' "$model"
printf 'android=%s\n' "$android_release"
printf 'abi=%s\n' "$abi"
printf 'characteristics=%s\n' "$characteristics"
printf 'uid=%s\n' "$(id -u 2>/dev/null || printf unknown)"
case ,$characteristics, in *,tablet,*) fail 'MIRO phone setup refuses a tablet target' ;; esac

# Exact package policy. Unknown packages are reported for review and never
# guessed at. Fields: minimum-level | action | package | human label.
package_policy() {
    cat <<'EOF_PACKAGES'
1|uninstall|com.king.candycrushsaga|Candy Crush Saga
1|uninstall|com.king.candycrushsodasaga|Candy Crush Soda Saga
1|uninstall|com.king.candycrush4|Candy Crush Friends Saga
1|uninstall|com.king.farmheroessaga|Farm Heroes Saga
1|uninstall|com.dreamgames.royalmatch|Royal Match
1|uninstall|com.playrix.homescapes|Homescapes
1|uninstall|com.playrix.gardenscapes|Gardenscapes
1|uninstall|com.scopely.monopolygo|MONOPOLY GO
1|uninstall|com.moonactive.coinmaster|Coin Master
1|uninstall|com.supercell.clashofclans|Clash of Clans
1|uninstall|com.supercell.clashroyale|Clash Royale
2|disable|com.google.android.apps.magazines|Google News
2|disable|com.google.android.videos|Google TV
2|uninstall|com.facebook.katana|Facebook
2|uninstall|com.facebook.lite|Facebook Lite
2|uninstall|com.instagram.android|Instagram
2|uninstall|com.zhiliaoapp.musically|TikTok
2|uninstall|com.snapchat.android|Snapchat
2|disable|com.facebook.system|Facebook system service
2|disable|com.facebook.appmanager|Facebook app manager
2|disable|com.facebook.services|Facebook services
3|uninstall|com.netflix.mediaclient|Netflix
3|uninstall|com.amazon.mShop.android.shopping|Amazon Shopping
3|uninstall|com.ebay.mobile|eBay
3|uninstall|com.reddit.frontpage|Reddit
3|disable|com.google.android.googlequicksearchbox|Google app, Discover, and Assistant surface
3|disable|com.google.android.youtube|YouTube
EOF_PACKAGES
}

package_is_targeted() {
    wanted=$1
    package_policy | awk -F '|' -v wanted="$wanted" -v selected="$selected_level" \
        '$1 <= selected && $3 == wanted { found=1 } END { exit !found }'
}

android_user_id() {
    if command -v am >/dev/null 2>&1; then
        current=$(am get-current-user 2>/dev/null | tr -d '\r') || current=
        case $current in *[!0-9]*|'') ;; *) printf '%s\n' "$current"; return 0 ;; esac
    fi
    printf '%s\n' 0
}

android_package_installed() {
    package=$1
    pm list packages --user "$android_user" "$package" 2>/dev/null | grep -Fqx "package:$package"
}

android_package_disabled() {
    package=$1
    pm list packages -d --user "$android_user" "$package" 2>/dev/null | grep -Fqx "package:$package"
}

apply_android_package() {
    desired_action=$1
    package=$2
    label=$3

    if ! android_package_installed "$package"; then
        printf 'package_state\tabsent\t%s\t%s\n' "$package" "$label"
        return 0
    fi

    case $desired_action in
        disable)
            if android_package_disabled "$package"; then
                printf 'package_state\tdisabled\t%s\t%s\n' "$package" "$label"
                return 0
            fi
            if [ "$mode" = dry_run ]; then
                printf 'would_disable\t%s\t%s\n' "$package" "$label"
                return 0
            fi
            action "Disable $label ($package) for Android user $android_user"
            pm disable-user --user "$android_user" "$package" >/dev/null
            android_package_disabled "$package" || fail "package did not become disabled: $package"
            ;;
        uninstall)
            if [ "$mode" = dry_run ]; then
                printf 'would_uninstall_for_user\t%s\t%s\n' "$package" "$label"
                return 0
            fi
            action "Remove $label ($package) for Android user $android_user"
            pm uninstall --user "$android_user" "$package" >/dev/null
            if android_package_installed "$package"; then
                fail "package is still installed for Android user $android_user: $package"
            fi
            ;;
        *) fail "invalid package action in policy: $desired_action" ;;
    esac
}

setting_value() {
    namespace=$1 key=$2
    settings get "$namespace" "$key" 2>/dev/null | tr -d '\r'
}

apply_android_setting() {
    minimum=$1 namespace=$2 key=$3 desired=$4 label=$5
    [ "$minimum" -le "$selected_level" ] || return 0
    current=$(setting_value "$namespace" "$key")
    if [ "$current" = "$desired" ]; then
        printf 'setting_state\tcurrent\t%s\t%s\t%s\n' "$namespace" "$key" "$desired"
        return 0
    fi
    if [ "$mode" = dry_run ]; then
        printf 'would_set\t%s\t%s\t%s\t%s\n' "$namespace" "$key" "$desired" "$label"
        return 0
    fi
    action "Set $label: $namespace/$key=$desired"
    settings put "$namespace" "$key" "$desired"
    current=$(setting_value "$namespace" "$key")
    [ "$current" = "$desired" ] || fail "setting did not stick: $namespace/$key"
}

run_android_phase() {
    command -v pm >/dev/null 2>&1 || fail 'Android package manager command pm is unavailable'
    command -v settings >/dev/null 2>&1 || fail 'Android settings command is unavailable'
    android_user=$(android_user_id)

    section 'Android distraction cleanup'
    printf 'android_user=%s\n' "$android_user"
    if [ "$mode" = apply ]; then
        uid=$(id -u 2>/dev/null || printf unknown)
        case $uid in 0|2000) ;; *) fail "Android apply needs root or shell uid; found uid=$uid" ;; esac
    fi

    package_policy | while IFS='|' read -r minimum desired_action package label; do
        [ "$minimum" -le "$selected_level" ] || continue
        apply_android_package "$desired_action" "$package" "$label"
    done

    section 'Attention settings'
    apply_android_setting 2 secure lock_screen_show_notifications 0 'hide notifications on the lock screen'
    apply_android_setting 2 secure lock_screen_allow_private_notifications 0 'hide private lock-screen notification content'
    apply_android_setting 2 secure notification_badging 0 'disable app-icon notification badges'
    apply_android_setting 3 global heads_up_notifications_enabled 0 'disable heads-up notification popups'

    section 'Third-party package review'
    printf '%s\n' '# Packages below are audit output only. Unknown apps are never removed automatically.'
    pm list packages -3 --user "$android_user" 2>/dev/null | sed 's/^package://' | sort | while IFS= read -r package; do
        [ -n "$package" ] || continue
        if package_is_targeted "$package"; then
            classification=targeted
        else
            classification=review
        fi
        printf 'third_party\t%s\t%s\n' "$classification" "$package"
    done

    if [ "$mode" = dry_run ]; then
        pass 'Android dry run completed without changing package or setting state'
    else
        pass 'Android package and attention policy applied'
    fi
}

termux_package_installed() {
    package=$1
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -Fq 'install ok installed'
}

termux_install_packages() {
    missing=
    for package in "$@"; do
        if ! termux_package_installed "$package"; then
            missing="$missing${missing:+ }$package"
        fi
    done
    [ -n "$missing" ] || {
        pass 'Termux base package set already present'
        return 0
    }
    if [ "$mode" = dry_run ]; then
        printf 'would_pkg_install\t%s\n' "$missing"
        return 0
    fi
    action "Install Termux packages: $missing"
    # shellcheck disable=SC2086
    pkg install -y $missing
}

repository_matches_catfood() {
    candidate=$1
    [ -d "$candidate" ] || return 1
    [ -e "$candidate/.git" ] || return 1
    origin=$(git -C "$candidate" remote get-url origin 2>/dev/null || true)
    case ${origin%.git} in
        https://github.com/isomorphisms/catfood|git@github.com:isomorphisms/catfood|ssh://git@github.com/isomorphisms/catfood) return 0 ;;
        *) return 1 ;;
    esac
}

find_catfood_control() {
    script_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." 2>/dev/null && pwd -P || true)
    for candidate in "$script_root" "$HOME/.cache/catfood" "$HOME/opt/catfood"; do
        [ -n "$candidate" ] || continue
        if repository_matches_catfood "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

ensure_catfood_control() {
    catfood_control=$(find_catfood_control || true)
    if [ -n "$catfood_control" ]; then
        printf 'catfood_control=%s\n' "$catfood_control"
        return 0
    fi

    destination=$HOME/.cache/catfood
    if [ -e "$destination" ]; then
        fail "$destination exists but is not a verified Cat Food checkout"
    fi
    if [ "$mode" = dry_run ]; then
        printf 'would_clone_catfood\t%s\n' "$destination"
        catfood_control=
        return 0
    fi
    mkdir -p "$HOME/.cache"
    action "Clone Cat Food control checkout to $destination"
    git clone --depth 1 https://github.com/isomorphisms/catfood.git "$destination"
    repository_matches_catfood "$destination" || fail 'new Cat Food checkout has the wrong origin'
    catfood_control=$destination
}

ensure_runtime_path() {
    marker='# catfood phone runtime path'
    line='export PATH="$HOME/opt/bin:$PATH"'
    for profile in "$HOME/.profile" "$HOME/.bashrc"; do
        if [ -f "$profile" ] && grep -F "$marker" "$profile" >/dev/null 2>&1; then
            continue
        fi
        if [ "$mode" = dry_run ]; then
            printf 'would_add_runtime_path\t%s\n' "$profile"
            continue
        fi
        action "Add ~/opt/bin to PATH in $profile"
        touch "$profile"
        {
            printf '\n%s\n' "$marker"
            printf '%s\n' "$line"
        } >> "$profile"
    done
}

proot_exists() {
    proot-distro list -q 2>/dev/null | awk '$1 == "catfood-debian" { found=1 } END { exit !found }'
}

ensure_proot() {
    [ "$with_proot" -eq 1 ] || {
        printf '%s\n' 'proot=not_requested'
        return 0
    }
    command -v proot-distro >/dev/null 2>&1 || {
        [ "$mode" = dry_run ] && { printf '%s\n' 'would_install_proot_distro'; return 0; }
        fail 'proot-distro was requested but its Termux package is unavailable after installation'
    }
    if proot_exists; then
        pass 'catfood-debian proot already exists'
        return 0
    fi
    if [ "$mode" = dry_run ]; then
        printf '%s\n' 'would_proot_install\tdebian:bookworm\tcatfood-debian'
        return 0
    fi
    action 'Install Debian Bookworm proot as catfood-debian'
    proot-distro install debian:bookworm --name catfood-debian
    proot_exists || fail 'catfood-debian proot installation did not become visible'
}

cleanup_termux_development_packages() {
    [ "${CATFOOD_MIRO_KEEP_BUILD_PACKAGES:-0}" = 1 ] && {
        printf '%s\n' 'build_package_cleanup=disabled'
        return 0
    }
    command -v apt-mark >/dev/null 2>&1 || return 0
    development_packages=
    for package in $(apt-mark showmanual 2>/dev/null); do
        case $package in git|gh) continue ;; esac
        package_section=$(dpkg-query -W -f='${Section}' "$package" 2>/dev/null || true)
        if [ "$package_section" = devel ]; then
            development_packages="$development_packages${development_packages:+ }$package"
        fi
    done
    [ -n "$development_packages" ] || {
        pass 'No manually installed development packages need removal'
        return 0
    }
    if [ "$mode" = dry_run ]; then
        printf 'would_purge_development_packages\t%s\n' "$development_packages"
        return 0
    fi
    action "Purge runtime-phone development packages: $development_packages"
    # shellcheck disable=SC2086
    apt purge -y $development_packages
    apt autoremove --purge -y
    apt clean
}

empty_reproducible_directory() {
    directory=$1
    [ -d "$directory" ] || return 0
    if [ "$mode" = dry_run ]; then
        count=$(find "$directory" -mindepth 1 -maxdepth 1 -print 2>/dev/null | wc -l | tr -d ' ')
        printf 'would_empty_cache\t%s\tentries=%s\n' "$directory" "$count"
        return 0
    fi
    action "Empty reproducible cache $directory"
    find "$directory" -mindepth 1 -maxdepth 1 -exec rm -rf -- '{}' +
}

cleanup_termux_caches() {
    for directory in \
        "$HOME/opt/downloads" \
        "$HOME/.cache/pip" \
        "$HOME/.cache/clangd" \
        "$HOME/.cache/meson" \
        "$HOME/.cache/go-build" \
        "$HOME/.gradle/caches" \
        "$HOME/.gradle/daemon" \
        "$HOME/.npm/_cacache" \
        "$HOME/.cargo/registry" \
        "$HOME/.cargo/git"
    do
        empty_reproducible_directory "$directory"
    done
}

run_termux_phase() {
    [ "$in_termux" -eq 1 ] || fail 'Termux scope requires a Termux PREFIX'
    command -v pkg >/dev/null 2>&1 || fail 'Termux pkg command is unavailable'
    command -v dpkg-query >/dev/null 2>&1 || fail 'Termux dpkg-query command is unavailable'

    section 'Termux runtime setup'
    base_packages='git ca-certificates openssh tmux vim'
    if [ "$with_proot" -eq 1 ]; then
        base_packages="$base_packages proot-distro"
    fi
    # shellcheck disable=SC2086
    termux_install_packages $base_packages

    if [ "$mode" = apply ]; then
        command -v git >/dev/null 2>&1 || fail 'git is still unavailable after Termux package installation'
    fi
    ensure_catfood_control
    ensure_runtime_path

    if [ -n "${catfood_control:-}" ]; then
        if [ "$abi" = armeabi-v7a ]; then
            if [ "$mode" = dry_run ]; then
                printf 'would_run_catfood\tphone\t%s\n' "$catfood_control"
            else
                action 'Install current verified Cat Food ARMv7 phone runtime'
                CATFOOD_TARGET=phone CATFOOD_ROOT="$HOME/opt" "$catfood_control/catfood"
            fi
        else
            warn "Cat Food runtime feed skipped for ABI $abi: current concrete phone target is ARMv7; do not relabel an AArch64 MIRO phone as the tablet target"
            printf 'catfood_runtime\tskipped\tabi=%s\n' "$abi"
        fi
    fi

    ensure_proot

    section 'Termux cleanup'
    cleanup_termux_development_packages
    cleanup_termux_caches

    section 'Termux verification'
    printf 'home=%s\n' "$HOME"
    printf 'prefix=%s\n' "$PREFIX"
    [ -d "$HOME/opt" ] && df -h "$HOME/opt" 2>/dev/null | sed -n '1,2p' || true
    if [ "$mode" = dry_run ]; then
        pass 'Termux dry run completed without changing state'
    else
        pass 'Termux runtime setup and cleanup completed'
    fi
}

case $scope in
    android) run_android_phase ;;
    termux) run_termux_phase ;;
esac
