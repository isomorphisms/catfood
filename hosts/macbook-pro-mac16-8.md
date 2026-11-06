# Apple Silicon MacBook Pro (Mac16,8): observed macOS host

This is a **dated, user-supplied host observation**, not a Cat Food provisioning
target or a successful macOS build receipt. Collected 2026-10-19 11:45:18 UTC.
The normalized observation ledger is
[`docs/observations/macbook-pro-mac16-8-2026-10-19.tsv`](../docs/observations/macbook-pro-mac16-8-2026-10-19.tsv).

Source: `IB / CAT FOOD MACOS REPORT`, 98,809 bytes; SHA-256
`fb580def033f6ed1f006b3d418e9c7ee767386cdaa5d9fe642ce4328742076d6`.
The full submitted transcript includes verbose IOKit counters and a failed Swift
probe; the normalized fields below preserve its useful device facts. The raw
transcript is not committed to Cat Food. Neither the source digest nor this
profile independently attests the present host state.

## Identity and process environment

| Property | Observed value |
| --- | --- |
| System | macOS 15.7.9, build 24G830, Darwin 24.6.0 |
| Machine | MacBook Pro, model `Mac16,8`, model number `Z1FF000JMY/A` |
| Chip | Apple M4 Pro |
| Process ISA | Native `arm64`; Rosetta translation = 0 |
| RAM | 48 GiB (51,539,607,552 bytes, unified memory) |
| CPU | 14 logical / 14 physical: 10 performance + 4 efficiency |
| Byte order | Little endian (`hw.byteorder=1234`) |
| VM page | 16,384 bytes |
| Cache line | 128 bytes |

Reported cache topology, by performance level:

| CPU level | L1 instruction | L1 data | L2 |
| --- | --- | --- | --- |
| Performance (10 cores) | 192 KiB/core | 128 KiB/core | 16 MiB per 5 cores |
| Efficiency (4 cores) | 128 KiB/core | 64 KiB/core | 4 MiB per 4 cores |

Reported `sysctl` ARM capabilities include Advanced SIMD/NEON, FP16,
BF16, I8MM, AES, PMULL, SHA-1/256/512, SHA3, CRC32, LSE/LSE2,
PAuth, BTI, SME and SME2. The report specifically shows
`FEAT_EBF16=0`, `FEAT_SPECRES=0`, `FEAT_SPECRES2=0`,
`FEAT_SSBS=0`, `FEAT_CSSC=0`, and `FEAT_HBC=0`. A feature bit
reported by the kernel is *not* execution acceptance of Cat Food's compiler,
runtime, or numerical kernel.

## GPU and displays

- Built-in Apple M4 Pro GPU: 20 cores, reported Metal 3 support.
- IOKit accelerator: `AGXAcceleratorG16X`, `AGXMetalG16X`,
  `com.apple.AGXG16X` driver 329.2.
- Internal Liquid Retina XDR panel: 3024 × 1964 Retina.
- External LG HDR 4K: 3840 × 2160, reported UI scaling 1920 × 1080
  at 30.00 Hz. This is the captured UI mode, not a promised general refresh rate.
- **Direct Metal device-family/capability probe: NOT VERIFIED.** Its Swift
  expression at line 4 failed to type-check in reasonable time and the
  probe exited 1. This is a probe-source compilation failure; it neither
  rejects nor validates particular Metal GPU families/features.

## Development state at capture

| Facility | Observation |
| --- | --- |
| Active developer directory | `/Library/Developer/CommandLineTools` |
| Apple Clang | 17.0.0 (`arm64-apple-darwin24.6.0`) |
| Swift | 6.2.1, compiler target `arm64-apple-macosx15.0` |
| macOS SDK | 26.1, available through Command Line Tools |
| Frameworks present | AppKit, Metal, MetalKit, QuartzCore, CoreGraphics, CoreText, WebKit, Foundation |
| Build utilities | `make` (Miniforge), `cmake` 4.4.3 (Homebrew), `git`, `clang`, `cc`, `lipo`, `codesign` |
| Package environment | Homebrew 7.0.9, Miniforge `python3` and `curl` |
| Not found on PATH | `ninja`, `pkg-config` |
| Xcode build | `xcodebuild` unavailable with selected CLT developer directory; full-Xcode installation state not established |
| Storage snapshot | Root volume reported 926 GiB total, 156 GiB available (mutable) |

The selected SDK version is not the installed operating-system version. A
`codesign` executable on PATH does not establish suitable certificates or
entitlements. No release signature, deployment, GUI launch, build, or runtime
acceptance is implied by these observations.

## Cat Food integration boundary

The current `./catfood` target selectors are Android devices, explicit
Debian/Ubuntu Linux workbenches, and generic Termux. They do **not** include
macOS. Automatic unknown-host selection and an explicit Linux-workbench
override must remain fail-closed on Darwin; do not route this Mac into
`cloud`, `container`, or the Android `arm64-v8a` package lane simply
because the processor is ARM64.

This profile supplies host facts for a *future* distinct macOS workbench lane.
Before claiming support, that lane needs positive Darwin/ARM64 selection,
macOS-specific dependency acquisition, exact-source compiler/link receipts,
native Mach-O and platform API verification, an actual execution smoke,
and platform-specific artifact/acceptance records. Do not infer iOS
build/deployment qualification from macOS hardware or SDK presence.
