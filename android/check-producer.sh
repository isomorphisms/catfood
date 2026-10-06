#!/bin/sh
# Compatibility entrypoint. An unsigned v1 sidecar cannot authorize an APK.
test -x /opt/aici/android-producer/current/runtime/grease || { echo 'MISSING_RUNTIME: authenticated producer deployment unavailable' >&2; exit 2; }
exec /opt/aici/android-producer/current/runtime/grease "$(dirname "$0")/check-producer.ysh" "$@"
