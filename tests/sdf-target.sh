#!/bin/sh
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
mkdir -p "$temporary/bin" "$temporary/home"
cat > "$temporary/bin/uname" <<'FAKE_UNAME'
#!/bin/sh
case $1 in
    -s) printf '%s\n' "${CATFOOD_TEST_SYSTEM:-NetBSD}" ;;
    -m) printf '%s\n' "${CATFOOD_TEST_ARCH:-amd64}" ;;
    -r) printf '%s\n' 9.3 ;;
    *) exit 2 ;;
esac
FAKE_UNAME
chmod 0700 "$temporary/bin/uname"
probe() {
    env HOME="$temporary/home" PREFIX= TERMUX_VERSION= \
        CATFOOD_TARGET=sdf PATH="$temporary/bin:$PATH" \
        "$@" sh "$root/catfood" --target
}
[ "$(probe)" = sdf ]
if probe CATFOOD_TEST_SYSTEM=Linux >"$temporary/out" 2>"$temporary/err"; then
    printf '%s\n' 'SDF accepted Linux' >&2; exit 1
fi
grep -F 'requires observed NetBSD/amd64' "$temporary/err" >/dev/null
if probe CATFOOD_TEST_ARCH=aarch64 >"$temporary/out" 2>"$temporary/err"; then
    printf '%s\n' 'SDF accepted non-amd64' >&2; exit 1
fi
grep -F 'requires observed NetBSD/amd64' "$temporary/err" >/dev/null
if env HOME="$temporary/home" PREFIX= TERMUX_VERSION= \
    CATFOOD_TARGET=auto PATH="$temporary/bin:$PATH" \
    sh "$root/catfood" --target >"$temporary/out" 2>"$temporary/err"; then
    printf '%s\n' 'NetBSD was silently classified as SDF' >&2; exit 1
fi
grep -F 'unsupported automatic Cat Food host' "$temporary/err" >/dev/null

# Doctor must not turn a missing toolchain into a success or create paths.
missing_sources=$temporary/home/code
missing_runtime=$temporary/home/opt
if env HOME="$temporary/home" PREFIX= TERMUX_VERSION= \
    CATFOOD_TARGET=sdf CATFOOD_ROOT="$missing_sources" \
    CATFOOD_SDF_RUNTIME_ROOT="$missing_runtime" \
    PATH="$temporary/bin:$PATH" \
    sh "$root/sdf/doctor.sh" >"$temporary/out" 2>"$temporary/err"; then
    printf '%s\n' 'SDF doctor accepted absent compiler' >&2; exit 1
fi
grep -F 'compiler:idric' "$temporary/out" | grep -F 'NOT_BUILT_OR_UNVERIFIED' >/dev/null
[ ! -e "$missing_sources" ] && [ ! -e "$missing_runtime" ]

# The probe itself never installs packages or changes personal directories.
if env HOME="$temporary/home" PREFIX= TERMUX_VERSION= \
    CATFOOD_TARGET=sdf PATH="$temporary/bin:$PATH" \
    sh "$root/sdf/preflight.sh" >"$temporary/out" 2>"$temporary/err"; then
    grep -F 'SDF build preflight passed' "$temporary/out" >/dev/null
else
    grep -F 'SDF build preflight blocked' "$temporary/err" >/dev/null
fi
[ ! -e "$temporary/home/code" ] && [ ! -e "$temporary/home/opt" ]
printf '%s\n' 'SDF target and non-mutating checks pass (synthetic only)'
