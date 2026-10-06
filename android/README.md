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

- [MIRO A1 evidence profile](devices/miro-a1.md) — dated physical-runner and
  graphics/rish observations, original versus inspection-package identity, and
  explicit limits on using compositor capabilities as application evidence.
- [MIRO C67 target note](devices/miro-c67.md) — Helio G36/Cortex-A53/GE8320
  model facts are known; physical Android ABI mapping remains unverified.

## Evidence boundaries

A package receipt records exact package identity and one result/evidence pair for each of `build`, `package`, `publication`, `installation`, `launch`, `runtime`, `emulator`, and `physical_device`. Results use the shared `PASS`, `FAIL`, `SKIP`, and `NOT_VERIFIED` vocabulary. Every stage is mandatory, `NOT_VERIFIED` carries no invented evidence, and a later stage cannot pass merely because an earlier stage passed. Validate a receipt with `sh android/check.sh receipt RECEIPT`.

The installer can prove a matching package digest and its own completed installation. A fresh successful download also proves that exact package URL was published at install time. It cannot prove the producer build, application launch, runtime behavior, emulator execution, or physical-device execution, so those remain `NOT_VERIFIED` until their own actions produce evidence. A package installed on one Android target does not accept the other target.

Known gaps remain visible. Installing all currently published packages is not a whole-distribution readiness claim while `check.sh ready <target>` still fails.


## First-party APK producer handoff

`apks.tsv` gives all three canonical Crystal IDs first-class MIRO A1 /
armeabi-v7a / test-lane coverage, with promotion explicitly blocked. Coverage
does not invent download URLs or mark the Termux product fleet delivered.

`check-producer.ysh` takes DECISION, APK, SOURCE_COMMIT and TARGET. It rehashes
the APK, checks coverage and invokes the fixed independently deployed AICI v2
consumer. AICI authenticates the decision and mandatory witness under the active
release and independently inspects actual package/version/ABI/signer bytes.
Unsigned v1 receipts and caller policy/key overrides have no accepted route.

`./catfood check-apk` exposes validation. `./catfood deliver-apk` invokes
`deliver-apk.ysh`: validate before staging, revalidate the copied bytes and
publish a new sealed directory without replacing a prior attempt. Build/package
evidence remains separate from installation, launch, replacement, visual,
emulator and physical evidence. Delivery does not install.

Original Crystal private-key recoverability remains UNKNOWN. The registered
public test signer proves no compatibility with original differently signed
installs. No uninstall, package-ID workaround or migration is performed.
Negative public tests use real canonical APK bytes; positive authenticated
delivery is blocked by the unavailable independent producer deployment.
