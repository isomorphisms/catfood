#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

workspace=$tmp/workspace
home=$tmp/home
fake_bin=$tmp/bin
daemon_state=$tmp/daemon-ready
adb_log=$tmp/adb.log
forbidden_log=$tmp/forbidden.log
mkdir -p "$workspace/bin" "$home/.config/crawlspace" "$fake_bin"
printf '%s\n' fixture-token > "$home/.config/crawlspace/token"
chmod 600 "$home/.config/crawlspace/token"

cat > "$workspace/bin/crawlspace" <<'EOF_CLIENT'
#!/bin/sh
set -eu
case ${1:-} in
    --version)
        printf '%s\n' 'crawlspace transport=2 discovery=1'
        ;;
    discover)
        if [ -f "$CATFOOD_TEST_DAEMON_STATE" ]; then
            cat <<'EOF_DISCOVERY'
status=ready
transport_version=2
discovery_version=1
daemon_identity=0123456789abcdef0123456789abcdef
daemon_uid=2000
authorization_scope=local-bearer-token
capability=crawlspace.discovery.v1
capability=crawlspace.run.absolute-path.v1
capability=crawlspace.runtime-identity.v1
EOF_DISCOVERY
        else
            printf '%s\n' 'status=unavailable' 'reason=daemon-absent'
            exit 69
        fi
        ;;
    identify)
        [ -f "$CATFOOD_TEST_DAEMON_STATE" ] || {
            printf '%s\n' 'status=unavailable' 'reason=daemon-absent'
            exit 69
        }
        cat <<EOF_IDENTITY
status=ready
transport_version=2
identity_version=1
daemon_start_identity=0123456789abcdef0123456789abcdef
daemon_pid=4321
daemon_uid=2000
daemon_authority=shell
daemon_role=native-command-bridge
build_id=${CATFOOD_TEST_EXPECTED_BUILD_ID}
authorization_scope=local-bearer-token
EOF_IDENTITY
        ;;
    run)
        [ "${2:-}" = /system/bin/id ] || exit 2
        [ -f "$CATFOOD_TEST_DAEMON_STATE" ] || exit 69
        printf '%s\n' 'uid=2000(shell) gid=2000(shell)'
        ;;
    *)
        exit 2
        ;;
esac
EOF_CLIENT
chmod 0755 "$workspace/bin/crawlspace"

cat > "$fake_bin/adb" <<'EOF_ADB'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$CATFOOD_TEST_ADB_LOG"
case ${1:-} in
    get-state)
        printf '%s\n' device
        ;;
    push)
        ;;
    shell)
        case "$*" in
            *'./crawlspace serve '*)
                : > "$CATFOOD_TEST_DAEMON_STATE"
                ;;
        esac
        ;;
    *)
        exit 2
        ;;
esac
EOF_ADB
chmod 0755 "$fake_bin/adb"

for forbidden in cc gcc clang make cmake javac gradle d8; do
    cat > "$fake_bin/$forbidden" <<'EOF_FORBIDDEN'
#!/bin/sh
printf '%s\n' "$0 $*" >> "$CATFOOD_TEST_FORBIDDEN_LOG"
exit 98
EOF_FORBIDDEN
    chmod 0755 "$fake_bin/$forbidden"
done

: > "$adb_log"
: > "$forbidden_log"
HOME="$home" \
PATH="$fake_bin:$PATH" \
CATFOOD_ROOT="$workspace" \
CATFOOD_ADB="$fake_bin/adb" \
CATFOOD_TEST_ADB_LOG="$adb_log" \
CATFOOD_TEST_DAEMON_STATE="$daemon_state" \
CATFOOD_TEST_EXPECTED_BUILD_ID="94f475dcad4f1661c5a638e9d24fe8fb22b3a279" \
CATFOOD_TEST_FORBIDDEN_LOG="$forbidden_log" \
    sh "$root/android/bootstrap-crawlspace.sh" >/dev/null

grep -F 'push ' "$adb_log" >/dev/null
test -f "$daemon_state"
test ! -s "$forbidden_log"

# Once the shell daemon answers with the exact expected build identity, repeated
# use must not invoke ADB.
: > "$adb_log"
HOME="$home" \
PATH="$fake_bin:$PATH" \
CATFOOD_ROOT="$workspace" \
CATFOOD_ADB="$fake_bin/adb" \
CATFOOD_TEST_ADB_LOG="$adb_log" \
CATFOOD_TEST_DAEMON_STATE="$daemon_state" \
CATFOOD_TEST_EXPECTED_BUILD_ID="94f475dcad4f1661c5a638e9d24fe8fb22b3a279" \
CATFOOD_TEST_FORBIDDEN_LOG="$forbidden_log" \
    sh "$root/android/bootstrap-crawlspace.sh" >/dev/null
test ! -s "$adb_log"
test ! -s "$forbidden_log"

# Normal Cat Food setup may leave a post-reboot bootstrap pending when no ADB
# connection exists; it must not fall back to compiling on the phone.
rm -f "$daemon_state"
pending=$(
    HOME="$home" \
    PATH="$fake_bin:$PATH" \
    CATFOOD_ROOT="$workspace" \
    CATFOOD_ADB="$tmp/missing-adb" \
    CATFOOD_TEST_DAEMON_STATE="$daemon_state" \
    CATFOOD_TEST_FORBIDDEN_LOG="$forbidden_log" \
        sh "$root/android/bootstrap-crawlspace.sh" --if-connected
)
printf '%s\n' "$pending" | grep -F 'PENDING:' >/dev/null
test ! -s "$forbidden_log"

if HOME="$home" \
   PATH="$fake_bin:$PATH" \
   CATFOOD_ROOT="$workspace" \
   CATFOOD_ADB="$tmp/missing-adb" \
   CATFOOD_TEST_DAEMON_STATE="$daemon_state" \
   CATFOOD_TEST_FORBIDDEN_LOG="$forbidden_log" \
       sh "$root/android/bootstrap-crawlspace.sh" >/dev/null 2>&1; then
    printf '%s\n' 'mandatory Crawl Space bootstrap passed without ADB or a live daemon' >&2
    exit 1
fi

# Cat Food owns the stable phone helper, while the tablet keeps its explicitly
# deferred ADB boundary.
CATFOOD_ROOT="$workspace" CATFOOD_TARGET=phone CATFOOD_CRAWLSPACE_BOOTSTRAP=0 \
    sh "$root/android/install-crawlspace-bootstrap.sh" >/dev/null
test -x "$workspace/bin/crawlspace-bootstrap"
grep -F '# Cat Food Crawl Space phone bootstrap.' "$workspace/bin/crawlspace-bootstrap" >/dev/null

tablet_workspace=$tmp/tablet
mkdir -p "$tablet_workspace/bin"
CATFOOD_ROOT="$tablet_workspace" CATFOOD_TARGET=tablet \
    sh "$root/android/install-crawlspace-bootstrap.sh" >/dev/null
test ! -e "$tablet_workspace/bin/crawlspace-bootstrap"

printf '%s\n' 'Cat Food Crawl Space runtime-only delivery and bootstrap contract passes'
