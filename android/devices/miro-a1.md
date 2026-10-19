# MIRO A1 conversation-runtime target

Primary performance target: MIRO A1, Android 14 / SDK 34, ARMv7 Android
`armeabi-v7a`, SC9863A, PowerVR GE8322. These are retained session/device facts,
not a fresh physical receipt from the 2026-10-07 producer environment.

Use Android API 21 as this native program's build floor; physical API 34 does
not require raising that floor. The runtime uses ARMv7 NEON Float32 and does
not require ARMv8 FP16 arithmetic. Build tools stay in the producer environment.

Private Termux storage is required for executable delivery. The preferred
phone executable location is `~/opt/bin`, as recorded in `AGENTS.md`. Shared
Downloads and the historical removable mount are not executable-location
proof; verify mutable paths on the A1 before delivery. No device path is used
by the cloud build.

`android/conversation-targets.tsv` pairs this primary A1 build with the C67's
native `arm64-v8a` build. This is a build-target table, not a Cat Food package
publication or installed-runtime claim. The C67 remains a phone, under the shared identity model in `TARGETS.md`.

Physical acceptance requires the exact stripped executable and model/index
digests, a UTF-8 raw query, cold process and already-loaded timings, load/text/
model/scoring stages, resident memory and peak memory. A cross-build or x86
receipt cannot satisfy those A1 requirements.
