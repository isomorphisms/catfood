#!/bin/sh
# Cat Food physical MIRO C67 acceptance for the real, published ICU command.
# Execute from a Cat Food control checkout; never build ICU on the device.
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$root/android/target.sh"
[ "${CATFOOD_TARGET:-c67}" = c67 ] || {
    printf '%s\n' 'ICU C67 acceptance requires CATFOOD_TARGET=c67' >&2
    exit 2
}
catfood_android_require_device c67

workspace=${CATFOOD_ROOT:-"$HOME/opt"}
PATH="$workspace/bin:$PATH"
export PATH
umask 077
stamp=$(date -u '+%Y%m%dT%H%M%SZ' 2>/dev/null || printf unknown)
evidence="$workspace/receipts/icu-c67-$stamp-$$"
mkdir -p "$evidence"
summary="$evidence/summary.tsv"
printf 'test\tresult\tevidence\n' > "$summary"
record() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$summary"; }
fail() { record "$1" FAIL "$2"; printf 'FAIL %s: %s\n' "$1" "$2" >&2; }
pass() { record "$1" PASS "$2"; printf 'PASS %s\n' "$1"; }
blocked() { record "$1" BLOCKED "$2"; printf 'BLOCKED %s: %s\n' "$1" "$2" >&2; }

printf 'target\tc67\nmodel\t%s\nproduct\t%s\nabi\t%s\nsdk\t%s\n' \
    "$(catfood_android_getprop ro.product.model)" \
    "$(catfood_android_getprop ro.product.device)" \
    "$(catfood_android_getprop ro.product.cpu.abi)" \
    "$(catfood_android_getprop ro.build.version.sdk)" > "$evidence/device.tsv"
pass device_identity "$evidence/device.tsv"

sh "$root/android/check.sh" check > "$evidence/manifest.log" 2>&1 || {
    fail manifest "$evidence/manifest.log"
    cat "$evidence/manifest.log" >&2
    exit 4
}
pass manifest "$evidence/manifest.log"

# C67 is the arm64-v8a delivery lane, column 4 in delivery.tsv.
disposition=$(awk -F '\t' '$1 == "icu" {print $4}' "$root/android/delivery.tsv")
case "$disposition" in
    gap:*)
        blocked icu_publication "$disposition; no verified arm64-v8a ICU package"
        printf 'Cat Food ICU C67 evidence: %s\n' "$summary"
        exit 3
        ;;
    package:*) package=${disposition#package:} ;;
    *) blocked icu_publication "unsupported ICU delivery disposition: ${disposition:-missing}"; exit 3 ;;
esac

# Refuse a mismatched manifest row; never guess a release URL or ABI.
row=$(awk -F '\t' -v p="$package" '$1 == p && $2 == "arm64-v8a" && $3 == "arm64-v8a" && $4 == "dex-jni" && $10 == "icu" {print $1}' "$root/android/packages.tsv")
[ "$row" = "$package" ] || {
    blocked icu_publication "missing ARM64 dex-jni icu command row for $package"
    exit 3
}

# Cat Food owns verification, staged installation and ~/opt/bin/icu.
if ! CATFOOD_TARGET=c67 CATFOOD_ROOT="$workspace" CATFOOD_ANDROID_ONLY="$package" \
    sh "$root/android/install.sh" > "$evidence/install.log" 2>&1; then
    fail installation "$evidence/install.log"
    cat "$evidence/install.log" >&2
    exit 4
fi
receipt="$workspace/receipts/c67-$package.tsv"
device_id=$(catfood_android_device_id)
if ! sh "$root/android/check.sh" receipt "$receipt" c67 "$device_id" > "$evidence/receipt.log" 2>&1; then
    fail installation_receipt "$evidence/receipt.log"
    exit 4
fi
[ -f "$workspace/bin/icu" ] && grep -Fq '# catfood android dex-jni wrapper' "$workspace/bin/icu" || {
    fail command_owner 'Expected a Cat Food-owned DEX/JNI wrapper in ~/opt/bin/icu'
    exit 4
}
pass installation "$receipt"

icu="$workspace/bin/icu"
# ICU DNS does not yet impose its own deadline. Refuse unbounded live tests.
if command -v timeout >/dev/null 2>&1; then
    timeout_command=timeout
elif [ -x /system/bin/toybox ] && /system/bin/toybox --list 2>/dev/null | grep -Fxq timeout; then
    timeout_command='/system/bin/toybox timeout'
else
    blocked time_bound 'No timeout command available; refusing unbounded network tests'
    exit 3
fi
failed=0
incomplete=0
case_run() {
    name=$1 expected=$2
    shift 2
    output="$evidence/$name.body"
    diagnostic="$evidence/$name.stderr"
    # Deliberately split words only for the fixed trusted timeout command.
    # shellcheck disable=SC2086
    if $timeout_command 25 "$icu" "$@" > "$output" 2> "$diagnostic"; then code=0
    else code=$?; fi
    printf '%s\n' "$code" > "$evidence/$name.exit"
    if [ "$code" -eq 124 ] || [ "$code" -eq 137 ]; then
        fail "$name" "timed out (exit $code); $diagnostic"
        failed=1
    elif [ "$expected" = ok ] && [ "$code" -eq 0 ]; then
        pass "$name" "$output"
    elif [ "$expected" = reject ] && [ "$code" -ne 0 ]; then
        pass "$name" "$diagnostic (exit $code)"
    else
        fail "$name" "exit $code (expected $expected); $diagnostic"
        failed=1
    fi
}

# Real public TLS: distinguishes installed ART/JNI launch from package existence.
case_run https_get ok get https://example.com/
if [ -s "$evidence/https_get.body" ]; then
    pass https_body "$evidence/https_get.body"
else
    fail https_body 'empty HTTPS response'; failed=1
fi

# Deterministic local HTTP suite when Python is already installed. No pkg install.
if command -v python3 >/dev/null 2>&1; then
    cat > "$evidence/fixture.py" <<'PY'
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys

class Fixture(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, fmt, *args):
        pass
    def send(self, status, data, headers=()):
        self.send_response(status)
        for k, v in headers:
            self.send_header(k, v)
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Connection', 'close')
        self.end_headers()
        self.wfile.write(data)
        self.close_connection = True
    def do_GET(self):
        if self.path == '/get':
            self.send(200, b'hello ICU')
        elif self.path == '/redirect':
            self.send(302, b'', [('Location', '/get')])
        elif self.path == '/binary':
            self.send(200, bytes([0,1,2,255,10,13,0,128]))
        elif self.path == '/chunked':
            self.send_response(200)
            self.send_header('Transfer-Encoding', 'chunked')
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(b'5\r\nhello\r\n0\r\n\r\n')
            self.close_connection = True
        elif self.path == '/error':
            self.send(500, b'error')
        else:
            self.send(404, b'not found')
    def do_POST(self):
        n = int(self.headers.get('Content-Length', '0'))
        self.send(200, self.rfile.read(n))

server = ThreadingHTTPServer(('127.0.0.1', 0), Fixture)
Path(sys.argv[1]).write_text(str(server.server_port))
server.serve_forever()
PY
    portfile="$evidence/port"
    python3 "$evidence/fixture.py" "$portfile" > "$evidence/fixture.log" 2>&1 &
    fixture_pid=$!
    trap 'kill "$fixture_pid" 2>/dev/null || :' EXIT HUP INT TERM
    i=0
    while [ ! -s "$portfile" ] && [ "$i" -lt 40 ]; do
        sleep 0.1
        i=$((i+1))
    done
    if [ ! -s "$portfile" ]; then
        fail local_fixture "$evidence/fixture.log"; failed=1
    else
        base="http://127.0.0.1:$(cat "$portfile")"
        case_run http_get ok get "$base/get"
        [ "$(cat "$evidence/http_get.body")" = 'hello ICU' ] || { fail http_bytes 'wrong GET bytes'; failed=1; }
        case_run http_redirect ok get "$base/redirect"
        [ "$(cat "$evidence/http_redirect.body")" = 'hello ICU' ] || { fail redirect_bytes 'wrong redirected bytes'; failed=1; }
        case_run http_chunked ok get "$base/chunked"
        [ "$(cat "$evidence/http_chunked.body")" = 'hello' ] || { fail chunked_bytes 'wrong decoded bytes'; failed=1; }
        case_run http_post_utf8 ok post "$base/echo" 'café π'
        [ "$(cat "$evidence/http_post_utf8.body")" = 'café π' ] || { fail post_bytes 'wrong UTF-8 response'; failed=1; }
        case_run http_binary ok get "$base/binary"
        binary_hex=$(od -An -t x1 "$evidence/http_binary.body" | tr -d ' \n')
        [ "$binary_hex" = '000102ff0a0d0080' ] || { fail binary_bytes "unexpected binary hex: $binary_hex"; failed=1; }
        case_run http_500 reject get "$base/error"
    fi
    kill "$fixture_pid" 2>/dev/null || :
    wait "$fixture_pid" 2>/dev/null || :
    trap - EXIT HUP INT TERM
else
    record local_fixture NOT_RUN 'python3 unavailable; no test dependency installed'
    incomplete=1
    printf '%s\n' 'Local fixture NOT_RUN (python3 is not installed).'
fi

printf '\nICU C67 results: %s\n' "$summary"
cat "$summary"
[ "$failed" -eq 0 ] || exit 1
[ "$incomplete" -eq 0 ] || exit 3
