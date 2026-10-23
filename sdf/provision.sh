#!/bin/sh
# Unprivileged SDF/NetBSD workbench. Never treat NetBSD as Debian.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$root/android/target.sh"
. "$root/ci/repositories.sh"
catfood_verify_sdf_target || exit $?

source_root=${CATFOOD_ROOT:-$HOME/code}
runtime_root=${CATFOOD_SDF_RUNTIME_ROOT:-$HOME/opt}
feed=${CATFOOD_SDF_FEED:-core}
depth=${CATFOOD_DEPTH:-1}
case "$feed" in core|all) ;; *)
    printf 'CATFOOD_SDF_FEED must be core or all, found %s\n' "$feed" >&2
    exit 2 ;;
esac
case "$depth" in ''|*[!0-9]*|0) printf 'invalid CATFOOD_DEPTH\n' >&2; exit 2 ;; esac
if [ "$source_root" = "$runtime_root" ]; then
    printf 'SDF source and runtime roots must differ\n' >&2
    exit 2
fi

# Inspection, prerequisite validation and manifest checks happen before writes.
sh "$root/sdf/preflight.sh"
sh "$root/check-manifest.sh"
mkdir -p "$source_root" "$runtime_root/bin" "$runtime_root/packages" \
    "$runtime_root/downloads" "$runtime_root/receipts"

feed_repository() {
    name=$1
    repository=$2
    branch=$3
    submodules=$4
    destination=$source_root/$name

    if [ -e "$destination/.git" ]; then
        actual=$(git -C "$destination" remote get-url origin 2>/dev/null || :)
        if ! same_repository_url "$actual" "$repository"; then
            printf '%s: origin mismatch; preserving %s\n' "$name" "$destination" >&2
            return 1
        fi
        actual_branch=$(git -C "$destination" symbolic-ref --quiet --short HEAD 2>/dev/null || :)
        if [ "$actual_branch" != "$branch" ]; then
            printf '%s: on %s, expected %s; preserving checkout\n' \
                "$name" "${actual_branch:-detached}" "$branch" >&2
            return 1
        fi
        if [ -n "$(git -C "$destination" status --porcelain)" ]; then
            printf '%s: local edits present; preserving checkout without update\n' "$name" >&2
            return 1
        fi
        git -C "$destination" fetch --depth "$depth" origin "$branch"
        git -C "$destination" merge --ff-only FETCH_HEAD
    elif [ -e "$destination" ] || [ -L "$destination" ]; then
        printf '%s: existing non-checkout path left untouched: %s\n' \
            "$name" "$destination" >&2
        return 1
    else
        git clone --depth "$depth" --single-branch --branch "$branch" \
            "$repository" "$destination"
    fi
    if [ "$submodules" = recursive ]; then
        git -C "$destination" submodule sync --recursive
        git -C "$destination" submodule update --init --recursive --depth "$depth"
    fi
    printf 'source:%s\t%s\t%s\n' "$name" \
        "$(git -C "$destination" rev-parse HEAD)" "$destination"
}

# Workbench inventory is authoritative. Core installs only the compiler; all
# feeds the entire declared source inventory, not an assertion of executables.
failed=0
while read -r name repository branch submodules || [ -n "${name:-}" ]; do
    case ${name:-} in ''|\#*) continue ;; esac
    if [ "$feed" = core ] && [ "$name" != Idric ]; then continue; fi
    feed_repository "$name" "$repository" "$branch" "$submodules" || failed=1
done < "$root/tools.tsv"
if [ "$feed" = all ]; then
    feed_repository grease https://github.com/dilapidated-shed/grease.git main recursive || failed=1
fi
if [ "$failed" -ne 0 ]; then
    printf '%s\n' 'SDF source feed incomplete; no compiler success claimed' >&2
    exit 1
fi

link_verified() {
    name=$1
    executable=$2
    destination=$runtime_root/bin/$name
    [ -x "$executable" ] || {
        printf '%s: source executable missing: %s\n' "$name" "$executable" >&2
        return 1
    }
    if [ -L "$destination" ]; then
        current=$(readlink "$destination")
        if [ "$current" = "$executable" ]; then return 0; fi
    fi
    if [ -e "$destination" ] || [ -L "$destination" ]; then
        printf '%s: existing stable command left untouched: %s\n' \
            "$name" "$destination" >&2
        return 1
    fi
    ln -s "$executable" "$destination"
}

write_management_wrapper() {
    name=$1
    script=$2
    destination=$runtime_root/bin/$name
    temporary=$runtime_root/bin/.$name.$$
    if [ -e "$destination" ] || [ -L "$destination" ]; then
        if [ ! -f "$destination" ] || \
           ! grep -F '# catfood sdf management wrapper' "$destination" >/dev/null 2>&1; then
            printf '%s: existing command left untouched: %s\n' "$name" "$destination" >&2
            return 1
        fi
    fi
    {
        printf '%s\n' '#!/bin/sh'
        printf '%s\n' '# catfood sdf management wrapper'
        printf 'exec sh "%s" "$@"\n' "$script"
    } > "$temporary"
    chmod 0700 "$temporary"
    mv "$temporary" "$destination"
}

write_management_wrapper catfood-update "$root/sdf/provision.sh"
write_management_wrapper catfood-doctor "$root/sdf/doctor.sh"

if [ "${CATFOOD_BUILD_TOOLS:-1}" = 0 ]; then
    printf '%s\n' 'SDF source feed complete; compiler build deliberately skipped'
    sh "$root/sdf/doctor.sh"
    exit 0
fi

idric=$source_root/Idric
[ -e "$idric/.git" ] || {
    printf '%s\n' 'Idriç checkout missing; build blocked' >&2
    exit 1
}
# SDF is a shared host. Limit the heavy compiler bootstrap to one build job.
MAKE=gmake
JOBS=${CATFOOD_JOBS:-1}
export MAKE JOBS
printf '%s\n' 'Bootstrapping pinned Chez and Idriç on native NetBSD/amd64'
if command -v nice >/dev/null 2>&1; then
    nice -n 10 sh "$idric/edric" all
else
    sh "$idric/edric" all
fi

compiler=$idric/_/build/exec/idris2
chez=$idric/_/.tools/bin/scheme
[ -x "$compiler" ] && [ -x "$chez" ] || {
    printf '%s\n' 'Idriç/Chez executable missing after bootstrap' >&2
    exit 1
}
"$compiler" --version
machine=$(printf '(display (machine-type))\n(newline)\n' | "$chez" --quiet | tail -n 1)
threaded=$(printf '(display (threaded?))\n(newline)\n' | "$chez" --quiet | tail -n 1)
[ "$machine" = ta6nb ] && [ "$threaded" = '#t' ] || {
    printf 'Chez machine type/thread mismatch: %s/%s (expected ta6nb/#t)\n' \
        "$machine" "$threaded" >&2
    exit 1
}

link_verified edric "$idric/edric"
link_verified idris2 "$compiler"

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v sha256 >/dev/null 2>&1; then
        sha256 -q "$1"
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}
source_sha=$(git -C "$idric" rev-parse HEAD)
compiler_digest=$(sha256_file "$compiler")
receipt=$runtime_root/receipts/idric-netbsd-amd64.tsv
receipt_tmp=$receipt.$$
umask 077
{
    printf 'schema\tcatfood-sdf-compiler-v1\n'
    printf 'os\tNetBSD\narchitecture\tamd64\n'
    printf 'source_repository\tisomorphisms/Idric\n'
    printf 'source_sha\t%s\n' "$source_sha"
    printf 'compiler_sha256\t%s\n' "$compiler_digest"
    printf 'chez_machine\t%s\n' "$machine"
    printf 'chez_threaded\t%s\n' "$threaded"
    printf 'build\tPASS\nfocused_tests\tPASS\n'
    printf 'physical_sdf_login_execution\tNOT_VERIFIED_EXTERNALLY\n'
} > "$receipt_tmp"
mv "$receipt_tmp" "$receipt"

sh "$root/sdf/doctor.sh"
printf 'SDF Idriç compiler installed under %s/bin\n' "$runtime_root"
