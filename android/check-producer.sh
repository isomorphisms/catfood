#!/bin/sh
# Compatibility entrypoint. An unsigned v1 sidecar cannot authorize an APK.
exec grease "$(dirname "$0")/check-producer.ysh" "$@"
