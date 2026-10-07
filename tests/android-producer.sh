#!/bin/sh
# Compatibility entry point; actual APK tests are maintained in Grease.
exec "${GREASE_BIN:-grease}" "$(dirname "$0")/android-producer.ysh" "$@"
