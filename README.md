# Cat Food

Cat Food feeds the maintained tool inventory into development hosts and delivers verified runtime packages to the Android phone and tablet.

It is deliberately small. Cloud, container, and generic Termux targets are workbenches: their repositories live under `/opt` or another selected root. The ARMv7 phone and AArch64 tablet are different: they are runtime targets and do not receive the source fleet, compiler bootstraps, or a local build toolchain.

## Run Cat Food

```sh
./catfood
```

The entrypoint selects one of four concrete targets:

- `phone`: 32-bit ARMv7 Android/Termux runtime delivery;
- `tablet`: AArch64 Android/Termux runtime delivery;
- `container`: disposable Debian/Ubuntu workbench, selected explicitly;
- `cloud`: persistent Debian/Ubuntu workbench, including Hetzner.

`termux` remains a compatibility source-workbench target for an unknown or explicitly forced Termux architecture. `hetzner` is an alias for `cloud`. See [TARGETS.md](TARGETS.md).

## Android delivery

Phone and tablet use the same repository-side delivery architecture under [`android/`](android/README.md).

`tools.tsv` is the declared Cat Food inventory. `android/delivery.tsv` must account for every row plus the separately bootstrapped Grease entry. Each item is explicitly classified as a runtime product, host tool, reference source, or unresolved classification. Every intended Android runtime is either linked to a real package or left as an explicit gap; adding an inventory row without an Android disposition fails the structural check.

`android/packages.tsv` contains only published packages. Rows carry exact source and packaging commits, target ABI, URL, SHA-256, command entrypoints, and dependency declarations. A missing deliverable is not represented by a fake or `PENDING` package row; it remains a gap in `android/delivery.tsv`.

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

Installation, publication, launch, behavior, emulator evidence, and physical-device evidence remain separate. An install receipt records exact package identity and leaves physical execution `PENDING` until the real device is exercised.

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

## Repository inventory

`tools.tsv` is both the authoritative current-workbench feed and the inventory from which Android coverage is checked. It contains the language/toolchain line, browser/publication tools, applications, and mathematical experiments. Grease is fed separately by `bootstrap.sh` because it supplies stage one, but it is still explicitly represented in Android delivery coverage.

Repositories marked `recursive` have actual submodules and are initialized automatically. New workbench clones use shallow history, 12 commits by default; set `CATFOOD_DEPTH` to change that. Existing checkouts are fetched without rewriting their history.

`./check-manifest.sh --remote` validates workbench manifest structure and verifies that every named remote branch exists. `sh android/check.sh check` independently validates total Android inventory coverage and package metadata.

## Private provider config

Amazon and AbeBooks credentials stay outside Git. A private config directory can be handed to the provisioner with `CATFOOD_CONFIG_DIR=/private/catfood-config ./provision.sh`; the importer copies only the recognized files to the user configuration directory with restrictive permissions.

## Stable commands

Workbenches keep stable command names under `$CATFOOD_ROOT/bin`. Current host names include `R`, `Rscript`, `grease`, `edric`, `idris2`, `fieldmouse`, `icu`, `ib-smoke`, `ithon`, `osh`, `ysh`, `az`, `abe`, `fdroid-deploy`, and `fdroid-check-deployed` when their targets are present. Management commands are `catfood-update`, `catfood-doctor`, and `catfood-import-config`.

Android exposes only commands from successfully installed runtime packages. The checked-in package inventory currently includes the existing Grease/YSH phone and tablet artifacts; all other intended runtime gaps stay explicit in `android/delivery.tsv` until actual packages exist.

## Stage zero

For a repository-fed workbench that only needs source acquisition without the core builds:

```sh
./bootstrap.sh
```

The phone and tablet do not use `bootstrap.sh` during normal delivery.

`catfood`, `provision.sh`, `bootstrap.sh`, `android/check.sh`, and `android/install.sh` stay POSIX `sh` because they run before Grease can be assumed. The machine-readable shell boundary remains in `ci/shell-boundary.tsv`; ai-ci checks `.ysh` entrypoints and their interpreter boundary separately.
