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

Direct DEX generation and NDK/JNI compilation happen on build hosts. An experimental ARM/Thumb or other compiler backend may produce useful development evidence, but its generic health is not a Cat Food package dependency. If a host tool is genuinely needed to produce a package, that dependency belongs in the producer/build recipe; it does not become a device prerequisite or an unrelated backend acceptance gate.

This does not authorize Java, Kotlin, Gradle, d8, RefC, or generated-C substitution. A future native backend can replace this delivery path only after that transition is explicitly chosen.

Cat Food may expose a control-plane helper from its own checked-out version after that helper's interpreter has been delivered. The current example is `gopeed` with aliases `gdl` and `go_down_load`, installed only after YSH is available. This does not turn the separately installed Gopeed Android app into a Cat Food package and does not satisfy the `gopeed` runtime gap in `delivery.tsv`.

## Evidence boundaries

A package receipt records exact package identity and one result/evidence pair for each of `build`, `package`, `publication`, `installation`, `launch`, `runtime`, `emulator`, and `physical_device`. Results use the shared `PASS`, `FAIL`, `SKIP`, and `NOT_VERIFIED` vocabulary. Every stage is mandatory, `NOT_VERIFIED` carries no invented evidence, and a later stage cannot pass merely because an earlier stage passed. Validate a receipt with `sh android/check.sh receipt RECEIPT`.

The installer can prove a matching package digest and its own completed installation. A fresh successful download also proves that exact package URL was published at install time. It cannot prove the producer build, application launch, runtime behavior, emulator execution, or physical-device execution, so those remain `NOT_VERIFIED` until their own actions produce evidence. A package installed on one Android target does not accept the other target.

Known gaps remain visible. Installing all currently published packages is not a whole-distribution readiness claim while `check.sh ready <target>` still fails.
