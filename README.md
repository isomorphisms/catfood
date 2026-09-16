# Cat Food

Cat Food feeds the maintained tool inventory into development hosts and delivers verified runtime packages to the Android phone and tablet.

It is deliberately small. Cloud, container, Void Linux, and generic Termux targets are workbenches: their repositories live under `/opt` or another selected root. The ARMv7 phone and AArch64 tablet are different: they are runtime targets and do not receive the source fleet, compiler bootstraps, or a local build toolchain.

## Run Cat Food

```sh
./catfood
```

The entrypoint selects one of five concrete targets:

- `phone`: 32-bit ARMv7 Android/Termux runtime delivery;
- `tablet`: AArch64 Android/Termux runtime delivery;
- `container`: disposable Debian/Ubuntu workbench, selected explicitly;
- `cloud`: persistent Debian/Ubuntu workbench, including Hetzner;
- `void`: persistent Void Linux development workbench.

`termux` remains a compatibility source-workbench target for an unknown or explicitly forced Termux architecture. `hetzner` is a provisioning alias for `cloud`. On non-Termux hosts, `ID=void` in `/etc/os-release` selects `void`; other hosts select `cloud`. See [TARGETS.md](TARGETS.md).

## Android delivery

Phone and tablet use the same repository-side delivery architecture under [`android/`](android/README.md).

`tools.tsv` is the declared Cat Food inventory. `android/delivery.tsv` must account for every row plus the separately bootstrapped Grease entry. Each item is explicitly classified as a runtime product, host tool, reference source, or unresolved classification. Every intended Android runtime is either linked to a real package or left as an explicit gap; adding an inventory row without an Android disposition fails the structural check.

`android/packages.tsv` contains only published or immutable packages/files. Rows carry exact source and packaging commits, target ABI, URL, SHA-256, command entrypoints, and dependency declarations. A missing deliverable is not represented by a fake or `PENDING` package row; it remains a gap in `android/delivery.tsv`.

The device path is download → verify → install. It does not clone project repositories, install a compiler toolchain, bootstrap a compiler, or fall back to a local source build when a package is absent. The tablet's additional storage does not change this boundary.

For programs delivered through ART, the generic `dex-jni` package mode installs direct DEX plus the declared JNI/NDK library and invokes `/system/bin/app_process`. The package receipt must match the target, ABI, source commit, and packaging commit. Direct DEX generation and NDK/JNI compilation happen on build hosts. Unfinished ARM/Thumb or other experimental native compiler backends are not Android delivery prerequisites merely because they live nearby or may produce separate development evidence.

This path does not authorize Java, Kotlin, Gradle, d8, RefC, or generated-C substitution. A future native compiler path can replace it only after that transition is explicitly chosen.

Current gaps are inspectable without pretending the distribution is complete:

```sh
sh android/check.sh check
sh android/check.sh gaps phone
sh android/check.sh gaps tablet
sh android/check.sh ready phone   # fails while intended phone runtime gaps remain
sh android/check.sh ready tablet  # likewise for tablet
```

Build, package, publication, installation, launch, runtime behavior, emulator execution, and physical-device execution remain separate. The machine-checked evidence receipt names every stage explicitly; the installer records only the package, publication, and installation results it actually observed and leaves the others `NOT_VERIFIED`.

### Android bootstrap

The Cat Food checkout itself is the small control plane. On Termux, provide the basic download/checksum/archive commands, clone Cat Food outside the runtime tree, and run it:

```sh
pkg install -y git ca-certificates curl coreutils tar
mkdir -p "$HOME/.cache"
git clone --depth 1 https://github.com/isomorphisms/catfood.git "$HOME/.cache/catfood"
cd "$HOME/.cache/catfood"
./catfood
```

Runtime state stays directly under `~/opt` by default: stable commands in `~/opt/bin`, installed packages in `~/opt/packages`, receipts in `~/opt/receipts`, and downloads in `~/opt/downloads`.

For an exact physical delivery receipt, `followers/accept-device.sh phone|tablet` first verifies that automatic architecture detection matches the named target, installs the target packages, and executes the installed `google-drive-unzip --help` path through the delivered YSH/Grease runtime. This deliberately does not claim an authenticated Google Drive extraction.

## Fresh Hetzner / Ubuntu workbench

```sh
apt-get update
apt-get install -y git ca-certificates
mkdir -p /opt
git clone https://github.com/isomorphisms/catfood.git /opt/catfood
cd /opt/catfood
./catfood
```

The cloud path installs its declared console/build dependencies, installs released YSH when needed, feeds the repository inventory, builds the current core toolchain, exposes stable commands, and runs `catfood-doctor` before returning success.

## Fresh Void Linux development workbench

```sh
xbps-install -Sy git ca-certificates
mkdir -p /opt
git clone https://github.com/isomorphisms/catfood.git /opt/catfood
cd /opt/catfood
./catfood
```

`./catfood` detects `ID=void`, installs the corresponding `xbps` development dependencies, uses the same source workbench layout, and runs the same doctor. Void is a separate follower target: a GitHub Ubuntu or Hetzner x86-64 receipt does not satisfy it.

The core host build currently exercises the repositories that need a real build before they are useful:

- Grease builds its vendored Python 2 bootstrap outside the checkout and exposes the generated interpreter; released native YSH is the stage-one shell.
- Idriç runs its checked-in `./edric all` bootstrap and focused handoff tests.
- Fieldmouse builds with Idriç, runs an interpreter smoke test, and rebuilds when Fieldmouse or Idriç changes.
- ICU builds with Idriç and OpenSSL into its checked-in command path.
- IB initializes its PDF-harvester submodule and compiles its deterministic smoke program.
- Ithon builds out of tree and runs its syntax test.
- IR builds out of tree, installs under the workbench root, and smoke-tests its language syntax.

Those host builds are not prerequisites for unrelated Android packages. Android package production names only the host tools it actually needs.

Build stamps are keyed to repository commits. `catfood-update` fetches repositories, rebuilds only core host tools whose source changed or output is missing, refreshes aliases, and reruns the doctor.

## Cloud storage command

`cloud-storage-api` is part of the workbench feed. Its current command is `google-drive-unzip`, a Grease/YSH client that invokes a deployed Google Apps Script API executable so a ZIP already in Google Drive can be expanded on Google's side instead of being downloaded to the phone or tablet.

The command source itself is architecture-neutral. Android therefore installs the same exact checked source file on ARMv7 and AArch64, but each package row depends on the matching native Grease/YSH runtime. Host workbenches expose the same command through `$CATFOOD_ROOT/bin/google-drive-unzip` and the doctor executes its credential-free `--help` path.

OAuth credentials and Apps Script deployment identity remain user configuration, not Cat Food package data. A successful install/help receipt proves delivery and runtime entrypoint behavior only; a live authenticated Drive extraction requires separate evidence.

## Repository inventory

`tools.tsv` is both the authoritative current-workbench feed and the inventory from which Android coverage is checked. It contains the language/toolchain line, browser/publication/storage tools, applications, and mathematical experiments. Grease is fed separately by `bootstrap.sh` because it supplies stage one, but it is still explicitly represented in Android delivery coverage.

Repositories marked `recursive` have actual submodules and are initialized automatically. New workbench clones use shallow history, 12 commits by default; set `CATFOOD_DEPTH` to change that. Existing checkouts are fetched without rewriting their history.

`./check-manifest.sh --remote` validates workbench manifest structure and verifies that every named remote branch exists. `sh android/check.sh check` independently validates total Android inventory coverage and package metadata.

## Private provider config

Amazon and AbeBooks credentials stay outside Git. A private config directory can be handed to the provisioner with `CATFOOD_CONFIG_DIR=/private/catfood-config ./provision.sh`; the importer copies only the recognized files to the user configuration directory with restrictive permissions.

## Stable commands

Workbenches keep stable command names under `$CATFOOD_ROOT/bin`. Current host names include `R`, `Rscript`, `grease`, `edric`, `idris2`, `fieldmouse`, `icu`, `ib-smoke`, `ithon`, `osh`, `ysh`, `az`, `abe`, `google-drive-unzip`, `gopeed`, `gdl`, `go_down_load`, `fdroid-deploy`, and `fdroid-check-deployed` when their targets are present. `aa` is installed when the fed `az` checkout contains `bin/aa`. Management commands are `catfood-update`, `catfood-doctor`, and `catfood-import-config`.

`gdl` and `go_down_load` are aliases of the `gopeed` REST client. It accepts a direct URL or one URL on standard input, so `aa resolve MD5 | gdl` hands a resolved Anna's Archive member URL to Gopeed without making Gopeed part of AA's HTTP transport.

Android exposes only commands from successfully installed runtime packages. The checked-in package inventory includes the Grease/YSH phone and tablet artifacts and exact pinned `google-drive-unzip` files for both targets. Other intended runtime gaps stay explicit in `android/delivery.tsv` until actual packages exist.

## Follower evidence

The follower ledger keeps GitHub-hosted Ubuntu, disposable Ubuntu containers, Hetzner, Void Linux, physical ARMv7 phone, and physical AArch64 tablet as independent targets. Shared x86-64 architecture is not enough to reuse a receipt across operating systems or persistence environments.

`followers/accept-x86.sh` runs repository contracts first, then actually provisions the selected x86 workbench and executes the installed cloud-storage command. Contract checks alone are not labeled runtime acceptance. Android physical-device acceptance similarly installs and executes the target command without pretending that a credential-free help invocation is a live Google API receipt.

## Stage zero

For a repository-fed workbench that only needs source acquisition without the core builds:

```sh
./bootstrap.sh
```

The phone and tablet do not use `bootstrap.sh` during normal delivery.

`catfood`, `provision.sh`, `bootstrap.sh`, `android/check.sh`, `android/install.sh`, and the follower entry scripts stay POSIX `sh` because they may run before Grease can be assumed. The machine-readable shell boundary remains in `ci/shell-boundary.tsv`; ai-ci checks `.ysh` entrypoints and their interpreter boundary separately.
