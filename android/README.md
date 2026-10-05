# Android delivery

Phone and tablet are runtime targets, not build hosts.

The device path is intentionally short:

1. `delivery.tsv` accounts for every row of the workbench inventory plus the separately bootstrapped Grease entry. A repository that exposes several independently packaged commands may use `packages:<id>,<id>` for a target.
2. `packages.tsv` names only artifacts that actually exist, with exact source commit, packaging commit, target ABI, URL, SHA-256, commands, and dependency declarations.
3. `check.sh` rejects inventory drift and invalid package/disposition relationships. `check.sh ready phone|tablet` is the manifest-level readiness gate; current gaps make it fail.
4. `install.sh` installs explicitly declared commodity Termux dependencies, downloads and verifies published Cat Food packages, installs their runtime files, and reports unresolved inventory. It never clones sources, bootstraps a compiler/toolchain, or repairs a missing package by building locally.

`runtime`, `host`, `reference`, and `review` are distinct inventory roles. `review` means the role is not settled yet; it is explicit debt and blocks readiness. Runtime entries must be `package:<id>`, `packages:<id>,<id>`, or `gap:<reason>` independently for phone and tablet. Host/reference entries are `n/a`; this is classification, not evidence that an intended application was successfully delivered.

## Termux packages

`termux_packages` is an explicit comma-separated list of commodity dependencies that Cat Food is allowed to obtain with `pkg install -y` on the Android device. `-` means none. This is intended for ordinary Termux runtime facilities such as `curl`, `libiconv`, `coreutils`, or `tar`; it is not a source-build escape hatch.

Cat Food installs those declared packages before checking `install_requires` and `runtime_requires`. Package-manager use is therefore visible in the manifest instead of being an implicit repair step. Compiler toolchains and unfinished compiler backends remain build-host concerns unless a future delivery decision explicitly changes that boundary.

The normal `./catfood` path installs jq and Miller from the separate pinned platform-binary feed before Android product delivery begins. jq therefore remains a declared runtime command requirement for consumers such as `az`, but it is no longer declared as a Termux package to fetch. If the pinned jq binary is absent, product delivery fails instead of silently replacing that mechanism with `pkg install jq`. Miller is installed by the same feed as the `mlr` command. These utility binaries are control-plane/runtime conveniences, not product rows in `delivery.tsv`.

## Package modes

`archive` and `file` install ordinary runtime artifacts. `file` is appropriate for an interpreted command whose exact source file is itself the runtime artifact. `dex-jni` is the direct Android path for code that runs under ART and needs native code: the archive contains the declared DEX entrypoint and JNI library plus `catfood-package.tsv`. The embedded receipt must match target, ABI, source commit, and packaging commit before installation. The stable command invokes `/system/bin/app_process` (or the test override) directly.

The `dex-jni` mode is a delivery/runtime shape, not a third build toolchain.
Build-host compile/link stages follow the shared AICI ICK-or-NDK contract. Use
qualified ICK for a stage when the exact required target/runtime surface is
proven. Use Android NDK only when that stage records the exact ICK revision and
a specific evidenced ICK capability gap. A hybrid ICK-object/NDK-link producer
records two stages rather than relabeling the whole build.

An existing reviewed DEX payload or common trampoline may remain a package
component, but this does not authorize new application-code generation through
Java, Kotlin, Gradle, d8, RefC, generated-C lowering, or another undeclared
compiler path. Experimental ICK work becomes relevant only when it supplies the
capability that a maintained producer actually needs; missing capability remains
an explicit gap rather than a device prerequisite or a silent fallback.

Cat Food may expose a control-plane helper from its own checked-out version after that helper's interpreter has been delivered. The current example is `gopeed` with aliases `gdl` and `go_down_load`, installed only after YSH is available. This does not turn the separately installed Gopeed Android app into a Cat Food package and does not satisfy the `gopeed` runtime gap in `delivery.tsv`.

## Device profiles

Device-specific facts do not redefine Cat Food's ABI targets. They document how
a physical product maps onto those targets after an actual runtime receipt.

- [MIRO C67 target note](devices/miro-c67.md) — Helio G36/Cortex-A53/GE8320
  model facts are known; physical Android ABI mapping remains unverified.

## Evidence boundaries

A package receipt records exact package identity and one result/evidence pair for each of `build`, `package`, `publication`, `installation`, `launch`, `runtime`, `emulator`, and `physical_device`. Results use the shared `PASS`, `FAIL`, `SKIP`, and `NOT_VERIFIED` vocabulary. Every stage is mandatory, `NOT_VERIFIED` carries no invented evidence, and a later stage cannot pass merely because an earlier stage passed. Validate a receipt with `sh android/check.sh receipt RECEIPT`.

The installer can prove a matching package digest and its own completed installation. A fresh successful download also proves that exact package URL was published at install time. It cannot prove the producer build, application launch, runtime behavior, emulator execution, or physical-device execution, so those remain `NOT_VERIFIED` until their own actions produce evidence. A package installed on one Android target does not accept the other target.

Known gaps remain visible. Installing all currently published packages is not a whole-distribution readiness claim while `check.sh ready <target>` still fails.

## MIRO phone first-run setup

`android/miro-phone-setup.sh` is the repeatable cleanup/setup pass for MIRO
phones. It defaults to a dry run and has three removal levels:
`safe`, `attention`, and `aggressive`. Package policy is exact-ID only;
unrecognized third-party packages are reported for review and are never guessed
at or removed.

The current MIRO cleanup policy explicitly removes known bundled games at the
`safe` level and, at the default `attention` level, removes the C67 news
preloads identified as Headlines (`us.sliide.harp`), NewsBreak
(`com.particlenews.newsbreak`), and Pulse / News Pulse
(`com.huub.flamingo`). Amazon Shopping is deliberately not a removal target;
even `aggressive` leaves `com.amazon.mShop.android.shopping` alone. Additional
game/news packages remain audit-only until their exact package IDs are known.

From the Cat Food checkout in Termux:

```sh
sh android/miro-phone-setup.sh --dry-run --scope termux --level attention
sh android/miro-phone-setup.sh --apply --scope termux --level attention
```

Add `--with-proot` when the phone should also carry a Debian Bookworm proot
named `catfood-debian`. The Termux pass installs only the small runtime/user
package set, feeds the existing ARMv7 Cat Food phone target when applicable,
purges stray development packages, and removes reproducible build caches.

The Termux pass also provisions Shizuku's `rish` pair. Its default source
is now the exact bundle owned and built by Crawl Space from the pinned Shizuku
source, not whichever Shizuku APK happens to be installed on the phone. Cat
Food pins the exact Crawl Space commit and the SHA-256 values of both `rish`
and `rish_shizuku.dex`; a hash mismatch fails closed. Device-local APK/shared
export fallback is disabled by default and requires the explicit
`CATFOOD_SHIZUKU_ALLOW_DEVICE_SOURCE=1` override. Removable SD storage is
never consulted.

The pair is installed in `~/opt`, upstream `PKG` is rewritten to
`com.termux`, `rish_shizuku.dex` is made read-only for Android 14, and a
stable `~/opt/bin/rish` command is installed. The pass then probes for shell
UID 2000. Pairing and starting the Shizuku manager remains the one Android
bootstrap prerequisite; if the service is stopped, the controlled files stay
installed and runtime status is reported as pending.

The Shizuku part can also be rerun by itself:

```sh
sh android/provision-shizuku-rish.sh --apply
```

Android package-manager and secure-setting mutation needs Android shell/root
authority, not the ordinary Termux app UID. For a stock phone, run the same
policy through ADB from a checkout:

```sh
adb shell 'sh -s -- --dry-run --scope android --level attention' < android/miro-phone-setup.sh
adb shell 'sh -s -- --apply --scope android --level attention' < android/miro-phone-setup.sh
```

The AArch64 MIRO C67 may use the common Termux/proot setup, but this script does
not mislabel it as Cat Food's AArch64 tablet target. Until Cat Food has a
separate AArch64 phone runtime target, that product feed is reported as skipped.
