# macOS ARM64 workbench: bounded first implementation

This is Cat Food's distinct **native Darwin/ARM64 host** lane. It is not an
Android device profile, `cloud`/Debian workbench, or an established iOS
producer. The [M4 Pro host profile](../hosts/macbook-pro-mac16-8.md)
is the dated October 19 hardware baseline; other ARM64 Macs can be tested
as separate host instances, without inheriting its observed capabilities.

## Run

On a clean Cat Food Git checkout on a native Apple Silicon macOS process:

```sh
./catfood --target                  # reports macos-arm64
./catfood                           # SDK/Clang, ARM64 CoreFoundation smoke
CATFOOD_MACOS_FEED=1 ./catfood      # optional manifest-based source feed
```

The default root is `$HOME/opt` (override with `CATFOOD_ROOT`).
The initial operation does **not** install Homebrew packages, invoke
`apt-get`/`pkg`, download Linux ELF binaries, install developer
toolchains, modify a login profile, or build the whole source fleet.

The smoke is an actual `clang -arch arm64` C compile/link against the
selected macOS SDK's CoreFoundation framework, `lipo` Mach-O architecture
inspection, and native execution check for `catfood-macos=42`.
It records `receipts/macos-host-smoke.tsv` with an exact Cat Food checkout
commit, clean source tree, observed OS/model, SDK/compiler versions and
separate compile/link and execution results. Clang and SDK availability
are verified at runtime, not assumed from the dated profile. Passing this
probe is **not** passing Idriç, ICK, Grease, Ithon, IB, Metal, an app,
or an iOS deployment acceptance test.

`CATFOOD_MACOS_FEED=1` additionally uses the existing `tools.tsv`/Grease
stage-zero Git source feed and `activate.sh` command wrappers.
It does not call `build-tools.sh` or `doctor.sh`: those core builds are
currently Linux-oriented and **not qualified for macOS**.
`CATFOOD_BUILD_TOOLS=1` fails explicitly, rather than silently
falling back to Apple Clang for maintained ICK-governed consumer builds.
Likewise, pinned `runtime-binaries.tsv` provides Linux ELF artifacts only;
it has no declared macOS arm64 bytes. Mac-specific dependencies must be
acquired and version-bound in a future implementation, not inferred from
Homebrew being on PATH.

## Checks and evidence

- Synthetic host classification and failure cases (any POSIX runner):
  `sh tests/macos-targets.sh`.
- Real Apple Silicon host CI: `sh tests/macos-host.sh` on
  `macos-15`, via `.github/workflows/macos-arm64.yml`.
- The CI standard `macos-15` is an ARM64 runner, but it is not the
  user's M4 Pro machine. It can qualify the compiler/framework path on
  the runner, not physical M4 Pro runtime behavior.
- Intel macOS, Linux/Android cross-host overrides, a missing SDK,
  dirty Cat Food source and unqualified core-build requests reject.
- The earlier direct Metal probe in the user-supplied profile failed
  during Swift type checking. No Metal feature acceptance is inferred.

## Next implementation work

Add macOS-specific, verified dependency acquisition; qualify the
required Grease/ICK/Idriç/IB build stages and runtime tests individually,
including exact source and compiler provenance; add any required Mach-O
runtime package policy; then perform independent source-pinned acceptance
on the physical `Mac16,8`. Maintain build and physical observations as
separate receipts, and do not mark the entire workbench ready from
this bounded smoke. iOS cross-compilation is another target contract.
