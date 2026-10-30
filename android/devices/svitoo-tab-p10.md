# SVITOO TAB_P10 recovery

TAB_P10 is the active physical Android development target as of 2026-10-30.
The human reports that both MIRO phones were damaged by water. Preserve their
historical artifacts and acceptance; neither phone is currently available for
new physical runs. The maintained build compatibility policy is separate.

## Retained observations

The 2026-09-18 observation in [AGENTS.md](../../AGENTS.md) identifies TAB_P10,
sun65iw1p1 and aarch64. The maintained device contract retains Android 15,
arm64-v8a and Mali-G57. These are historical/model facts, not a new probe of
the current tablet, firmware, driver or installed runtime.

The last reliable tablet storage observation resolved Downloads to
`/storage/emulated/0/Download`, found no `~/storage/external-1`, and did not
establish a working SD-card mount. The A1's `/storage/4A21-0000` is not a
tablet path. Absence in one app's mount namespace does not establish that a
card is physically absent or defective.

The current recovery request reopens tablet storage discovery. Ordinary
Termux observation remains independent of ADB pairing and does not require
Shizuku, root or a source/build toolchain on the tablet.

## Implemented acquisition

`catfood inspect` now extends the existing `catfood-device-inventory-v1`
inventory with hardware, bounded service observations, resolved storage paths,
mount records, free KiB and installed command paths/digests. It captures:

- observed identity, firmware, ABI lists, board/SoC properties and kernel;
- CPU and memory, display size/density/modes, features, sensors and input;
- compositor graphics, battery and thermal service observations;
- Android disk/volume service responses;
- HOME, runtime root, Termux prefix and existing storage aliases independently;
- visible public volume mounts and installed runtime command bytes.

Every optional query distinguishes observed output, empty success, denial,
failure, timeout and an unavailable command. Output is capped at 200 lines per
stream; truncation is explicit. Capture also has an eight-second timeout and a
256-block per-file limit so a verbose service cannot fill tablet storage.
A compositor dump is not an application EGL
context test. A command path/digest is not runtime acceptance. Missing
properties are unknown, not filled from the model profile.

Storage matching uses the longest observed mount prefix and decodes mount
escapes. A `noexec` mount is recorded as blocked; a mount without `noexec`
remains untested for execution. A UUID mount is a visible public volume, not
proof of SD media. `sd_card_presence` stays unknown. Discovery neither creates
files on the card nor moves data, formats media or installs packages.

Completed snapshots are private, atomically replace the current inventory,
and retain distinct history even within one clock second. Cat Food Manager's
existing record/compare/report commands consume the same four-column schema.
The candidate scoped profile reader in isomorphisms/catfood PR #144,
“Consume scoped Android profiles before diagnostics (BC-CF01-S01)”
(https://github.com/isomorphisms/catfood/pull/144), already accepts this inventory
schema and ignores non-meta observation rows. It is not treated as merged or
replaced by a second profile interpreter.

## Remaining bring-up boundaries

SUN CATFOOD-TABP10-RECOVERY-01 is incomplete. This source change does not claim
current physical discovery, runtime delivery, installation, launch or behavior.
No live tablet endpoint or authenticated device channel was available in its
execution environment; SSH had no configured device identity and ADB was absent.

Known independent runtime work remains visible:

- https://github.com/isomorphisms/catfood/issues/130 records Android AArch64
  being routed to the generic Linux jq binary. A Termux-installed jq did not
  satisfy that pinned lane. This is not fixed by hardware discovery.
- https://github.com/isomorphisms/catfood/issues/131 records the unqualified
  Grease implementation/dependency boundary. Do not install a rejected C++
  implementation or infer that a version/manifest check accepts its replacement.
- `android/check.sh gaps tablet` retains missing product artifacts. Installing
  the published subset would not establish whole-distribution readiness.

The next physical observation must use the actual tablet's verified Cat Food
entrypoint and return the completed inventory. Current paths, mount state,
free space and firmware must precede artifact selection or device mutations.
Runtime delivery then requires exact compatible artifacts and separate
installation, launch, behavior and physical-device receipts. No automatic
merge, application-data deletion, reset, formatting, signing change or release
promotion is part of this change. Flexible Pipes is not used for this one-off
execution.
