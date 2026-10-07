# Runtime delivery work, 2026-10-07

The request is to close intended runtime package gaps through ai-ci, Flexible
Pipes and Cat Food and then execute each physical target. A package-gap count
is delivery work for that system. It does not justify omitting a runtime or
relabeling it as a host tool.

## Executable repair in this branch

Ish's two published runtime archives already existed while main classified
both lanes as missing. Cat Food now binds them to source/package commit
`0e6ba10f8edde26e940685ac386ad4279afbe259`:

| Consumer | Package | Published archive SHA-256 | Observed archive bytes |
| --- | --- | --- | --- |
| A1 / `phone` | `ish-armeabi-v7a` | `72ab71f63cfc6a970bb01bc1a30a686fa2550e0f0a881b89395e0c1335304582` | 3,044,868 |
| C67 / `c67` | `ish-arm64-v8a` | `1a15060ffc201f15c679f432c2237bdddb6cf3a2a90bf7b81d21381c7c4ddac2` | 3,108,703 |
| TAB_P10 / `tablet` | Same ARM64 artifact | Same digest; independent instance/acceptance | 3,108,703 |

Archive verification inspected all six payload digests, ABI of launcher/Chez/FFI,
absence of native symbol/debug sections, source provenance, and the private
compiled Ish program. ARM32 launcher/Chez sizes are 7,192/930,988 bytes;
ARM64 sizes are 8,664/940,016 bytes. The source builder strips these ELFs.
Pre-strip sizes were not retained in those historical receipts; they are not
invented here.

The historical [paired package CI](https://github.com/dilapidated-shed/grease/actions/runs/37472545733)
is cross-build evidence. It used NDK and predates a complete stage-specific ICK
gap/size receipt. This consumption change does not certify a new producer
qualification or fresh build; the install receipt retains
`build_result=NOT_VERIFIED`. The bundled runtime has API floor 28 and installs
no compiler or source fleet.

`tests/android-ish-artifact.sh` downloads actual published bytes, exercises
the actual installer for synthetic A1/C67/TAB_P10 properties, rejects damaged
executables, wrong ABI, shell alias, wrong instance and cross-target receipt
use, and verifies repeat installation without physical promotion.
`tests/android-target-cli.sh` exercises the narrow command interface to the
existing identity oracle.

`android/acceptance/ish-installed.grease` is the physical acceptance action.
It requires a named physical target and an absolute observed installed
workspace, uses direct Android properties, validates the exact instance,
checks the cached archive's manifest-bound digest and the installed payload
record against that archive, and executes Chez plus Ish's literal/environment/
stdin/status and negative semantics. It writes a new device-specific receipt
only after every check. It preserves the install receipt, producer and
emulator results. Kitchen retains the preparation requirements and hostile
orchestration fixtures. Host fixtures cannot accept ARM behavior or a device.

## Full-inventory discovery and remaining work

The [source snapshot](observations/runtime-artifacts-2026-10-07.json) accounts
for all 37 runtime rows missing at main
`5c0fbc010437ed776b620a9d4965fd4225ba1bf4`. The bounded query covers the first
five releases and recent workflow runs, then artifacts for up to three distinct
successful workflows. Nine rows have queried releases; twenty have discovered
Actions artifacts. Artifacts include pictures, traces, unsigned APKs, debug
APKs, runtime binaries and store bundles; their existence is not admission.
No claim is made that earlier artifacts or other branches are absent.

| Runtime | Queried releases | Queried Actions artifacts | Disposition |
| --- | --- | --- | --- |
| `ish` | `ish-tablet-aarch64-0e6ba10f8edd`, `ish-phone-armv7-0e6ba10f8edd` | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Paired immutable archives wired and tested; A1/C67/TAB_P10 execution pending |
| `ir` | `ir-4.7.0-devel-armv7.1` | 1 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | ARMv7 .deb inspected; consumer format/dependencies and ARM64 producer still required |
| `ithon` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `Idric` | `termux-armv7-115b6ea4a195`, `termux-armv7-bfe5caac589b` | 1 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | ARMv7 compiler/runtime release is not a paired runtime-only delivery decision |
| `idric-cli` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `issh` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `fieldmouse` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `sent.idr` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `programmers-keyboard` | None in queried release window | 2 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `icu` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `ib` | None in queried release window | 1 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `internetarchive` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `bookreader` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `ddg` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `chawan` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `gopeed` | `termux-869a35e44a8b` | 2 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | API binaries are not the intended Android app; app obligation remains |
| `wegert` | `v0.1.50` | 4 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Reuse owner output after shared producer/signing/ABI/update admission; C67 evidence independent |
| `utilities-android-phone-user` | `accelerometer-native-v0.2.0`, `accelerometer-native-v0.1.0` | 8 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Reuse owner output after shared producer/signing/ABI/update admission; C67 evidence independent |
| `algebraic-variety-explorer-mobile` | None in queried release window | 6 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Reuse owner output after shared producer/signing/ABI/update admission; C67 evidence independent |
| `learn-toki-pona` | `v1.0.1` | 3 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Reuse owner output after shared producer/signing/ABI/update admission; C67 evidence independent |
| `game` | `salon-preview-v0.2.3`, `salon-preview-v0.2.2` | 2 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Reuse owner output after shared producer/signing/ABI/update admission; C67 evidence independent |
| `hegel` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `geofence` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `analytic-continuation` | `holomorphic`, `v0.2.1` | 4 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Reuse owner output after shared producer/signing/ABI/update admission; C67 evidence independent |
| `non-poly` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `coefficient-root-dance` | None in queried release window | 2 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Reuse owner output after shared producer/signing/ABI/update admission; C67 evidence independent |
| `Cayley` | None in queried release window | 1 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Reuse owner output after shared producer/signing/ABI/update admission; C67 evidence independent |
| `tablature` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `zoneedit` | None in queried release window | 1 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Reuse owner output after shared producer/signing/ABI/update admission; C67 evidence independent |
| `L` | None in queried release window | 4 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Reuse owner output after shared producer/signing/ABI/update admission; C67 evidence independent |
| `soap` | None in queried release window | 3 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Reuse owner output after shared producer/signing/ABI/update admission; C67 evidence independent |
| `klein-quartic` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `hopf_fibration` | None in queried release window | 1 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Reuse owner output after shared producer/signing/ABI/update admission; C67 evidence independent |
| `ortho` | None in queried release window | 2 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Reuse owner output after shared producer/signing/ABI/update admission; C67 evidence independent |
| `kleinian-groups` | None in queried release window | 0 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |
| `theta` | None in queried release window | 3 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | Reuse owner output after shared producer/signing/ABI/update admission; C67 evidence independent |
| `indras-pearls` | None in queried release window | 5 discovered; [details](observations/runtime-artifacts-2026-10-07.json) | No accepted paired runtime artifact established by this bounded scan; retain owner producer obligation |

After Ish is wired, 36 inventory rows still lack accepted delivery. C67 also
retains its distinct GPU package restriction. `android/check.sh ready` stays
red for every physical target. This branch is a concrete partial delivery
repair, not a claim that the whole inventory is complete.

## Existing shared path and concrete boundaries

The existing owner is [Cat Food issue 33](https://github.com/isomorphisms/catfood/issues/33).
[Issue 118](https://github.com/isomorphisms/catfood/issues/118) retains the selected
profile-driven companion-plan work. A1 remains primary and normal maintained
application producers pair A1+C67; tablet acceptance is independent.

Flexible Pipes main `424e1972da3bab1bc7ec97a6094422fe7bb211f5`
has a legacy `android-apk-preflight` that requires an already-built APK. It is
not a package producer. Replacing missing builds with that check would repeat
the problem at a different stage.

The actual registered producer and consumer candidates remain retained,
closed and unmerged:

- [isomorphisms/flexible-pipes PR #33, “Register Android producer and diagnostic operations with actual behavioral replay”](https://github.com/isomorphisms/flexible-pipes/pull/33),
  `fc4443f27ae11dcae32ab62d62f510812be9a57d`.
- [isomorphisms/ai-ci PR #211, “Bind Android producer execution and diagnostic claims to verified identities”](https://github.com/isomorphisms/ai-ci/pull/211),
  `e4723d886658edffd65ffa3d35dc3a2cf83f15ce`.
- [isomorphisms/catfood PR #112, “Consume exact AICI Android producer receipts”](https://github.com/isomorphisms/catfood/pull/112),
  `fffa3c9ae49b954a447608642f9597dc428427ab`.

Their independent issuer/runtime qualification and protected approval boundary
are unresolved. The retained FP terminal reports `MISSING_RUNTIME` /
`PRODUCER_PREPARATION_BLOCKED`. No candidate is allowed to certify itself by
supplying its own expected digest. Original A1 signing/update continuity is a
separate required input. This host has no aapt2/apksigner, and its installed
bubblewrap fails the namespace execution probe; tool presence did not establish
an isolated producer. No service was activated, issuer forged or new signer
created in this work.

The current ai-ci main legacy gate still checks merged policy/packager ancestry,
a declared build toolchain, exact APK/ABI/signer and update continuity. It is
neither independent candidate execution qualification nor physical runtime
acceptance. Existing DEX/JNI runtime shapes do not authorize new Java/Kotlin/
Gradle/d8/generated-C application builds.

[isomorphisms/flexible-pipes PR #47, “Produce paired A1 and C67 conversation runtime builds”](https://github.com/isomorphisms/flexible-pipes/pull/47)
retains actual NDK cross-build outputs and specific ICK failure evidence at
`6810dc0dd81dad0ccbba882e7c696fbaef13e329`. Those example outputs have not
become registered producer publication or physical acceptance.

All observed source and artifact identities above are reusable inputs to the
existing owners. The unresolved protected producer qualification, per-application
runtime/signing requirements, .deb consumer support, absent paired archives
and device access remain separate obligations; this job did not satisfy them
with fixtures or a discovery table.

