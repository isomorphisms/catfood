# Cat Food

Cat Food feeds the maintained tool inventory into development hosts and delivers verified runtime packages to the Android phone and tablet.

It is deliberately small. Cloud and container targets are workbenches: their repositories live under `/opt` or another selected root. MIRO A1, MIRO C67 and TAB_P10: they are runtime targets and do not receive the source fleet, compiler bootstraps, or a local build toolchain.

## Run Cat Food

Start with `./catfood --help` or `./catfood where` to inspect the commands and verified local checkouts. Running with no subcommand provisions the selected target:

```sh
./catfood
```

The entrypoint selects a device profile or workbench role:

- `phone`: observed MIRO A1 phone, ARMv7 Android runtime delivery;
- `c67`: observed MIRO C67 phone, ARM64 Android runtime delivery;
- `tablet`: observed TAB_P10 tablet, ARM64 Android runtime delivery;
- `container`: disposable Debian/Ubuntu workbench, selected explicitly;
- `cloud`: persistent Debian/Ubuntu workbench, including Hetzner.

`termux` is generic/unknown Android identity; provisioning stops until a known profile is established. `hetzner` is an alias for `cloud`. See [TARGETS.md](TARGETS.md).

## Android delivery

A1, C67 and TAB_P10 use the same repository-side delivery architecture under [`android/`](android/README.md).

`tools.tsv` is the declared Cat Food inventory. `android/delivery.tsv` must account for every row plus the separately bootstrapped Grease entry. Each item is explicitly classified as a runtime product, host tool, reference source, or unresolved classification. Every intended Android runtime is either linked to a real package or left as an explicit gap; adding an inventory row without an Android disposition fails the structural check.

`android/packages.tsv` contains only published packages. Rows carry exact source and packaging commits, target ABI, URL, SHA-256, command entrypoints, and dependency declarations. A missing deliverable is not represented by a fake or `PENDING` package row; it remains a gap in `android/delivery.tsv`.

Release packages must contain stripped native runtime payloads. Strip releasable ELF executables and shared objects of debug and non-runtime symbol data before APK/archive assembly; keep unstripped binaries or symbol files only as separate debugging artifacts when needed. Release evidence should record the native payload size before and after stripping and the final package size so an accidentally unstripped artifact cannot silently become the shipped package.

The device path is download → verify → install. It does not clone project repositories, install a compiler toolchain, bootstrap a compiler, or fall back to a local source build when a package is absent. The tablet's additional storage does not change this boundary.

For programs delivered through ART, the generic `dex-jni` package mode installs direct DEX plus the declared JNI/NDK library and invokes `/system/bin/app_process`. The immutable embedded receipt must match its historical wire lane, ABI, source commit, and packaging commit; it does not identify the consuming device. That mode describes packaging and runtime representation, not a separate build-toolchain exemption.

Producer compile/link stages follow AICI's ICK-or-NDK contract. Use ICK when the exact target and required surface are qualified. Use Android NDK only for a stage whose exact ICK revision has a recorded capability gap and evidence. If ICK compiles an object and NDK performs the final Android platform link, record those as separate build stages. Existing reviewed DEX payloads or a common trampoline may still be delivered, but new application code must not be generated through Java, Kotlin, Gradle, d8, RefC, generated-C lowering, or another undeclared compiler path. An unfinished ICK capability becomes an explicit gap, not a reason to pretend a different build path is ICK.

Current gaps are inspectable without pretending the distribution is complete:

```sh
sh android/check.sh check
sh android/check.sh gaps phone
sh android/check.sh gaps tablet
sh android/check.sh ready phone   # fails while intended phone runtime gaps remain
sh android/check.sh ready tablet  # likewise for tablet
```

Build, package, publication, installation, launch, runtime behavior, emulator execution, and physical-device execution remain separate. The version 2 receipt binds the device profile and instance separately from the ABI/package lane and names every stage explicitly; the installer records only the package, publication, and installation results it actually observed and leaves the others `NOT_VERIFIED`.

### Android bootstrap

The Cat Food checkout itself is the small control plane. On Termux, install only what is needed to fetch that checkout, then let Android delivery install a declared runtime dependency only when its command is actually missing:

```sh
pkg install -y git ca-certificates
mkdir -p "$HOME/.cache"
git clone --depth 1 https://github.com/isomorphisms/catfood.git "$HOME/.cache/catfood"
cd "$HOME/.cache/catfood"
./catfood
```

Package verification uses an existing `sha256sum` when present and otherwise Android's `/system/bin/toybox sha256sum`; GNU coreutils is not a bootstrap requirement. Likewise, an existing Android/Termux `tar`, `grep`, `sed`, `awk`, `iconv`, or other declared command is reused instead of installing a duplicate Termux package.

Runtime state stays directly under `~/opt` by default: stable commands in `~/opt/bin`, installed packages in `~/opt/packages`, receipts in `~/opt/receipts`, and downloads in `~/opt/downloads`.

Crawl Space is delivered as a pinned Android runtime. The current package is exact source/build `94f475dcad4f1661c5a638e9d24fe8fb22b3a279`; the phone bootstrap accepts a live daemon only when `crawlspace identify` reports shell authority, the native-command-bridge role, and that exact build ID. A correct live daemon needs no ADB call. After reboot or when a stale build is detected, the phone may use an already-connected Wireless debugging session once to replace/start the daemon. The device never compiles Crawl Space.

Cat Food also owns a small platform-binary feed in [`runtime-binaries.tsv`](runtime-binaries.tsv). It currently pins jq 1.8.2 and Miller 6.21.0 (`mlr`) from their upstream release assets for Linux ARMv7, AArch64, x86-64, and RISC-V 64. Each asset is bound to an exact SHA-256 and must pass its version probe after installation. The ARMv7 phone, AArch64 tablet, and x86-64 Linux targets therefore consume prebuilt binaries rather than compiling these utilities locally or relying on a target package-manager version. The RISC-V row is binary availability only; it does not create or imply a maintained RISC-V acceptance target.

Lua is a Cat Food support runtime rather than an Android product row. Known Android runtime targets acquire the packaged `lua55` runtime and expose stable `lua` and `luac` commands under the Cat Food bin directory; they do not compile Lua on the device. Debian/Ubuntu workbenches acquire `lua5.4` plus `liblua5.4-dev` from the host package manager, then expose the same stable command names. `install-lua.sh` runs an interpreter smoke, a `luac` parse smoke, and writes `receipts/lua.tsv`.

## Fresh Hetzner / Ubuntu workbench

```sh
apt-get update
apt-get install -y git ca-certificates
mkdir -p /opt
git clone https://github.com/isomorphisms/catfood.git /opt/catfood
cd /opt/catfood
./catfood
```

The cloud path installs its declared console/build dependencies, installs released native YSH when needed, feeds the repository inventory, builds the current host tools **without defaulting to the legacy Grease Python 2 interpreter**, exposes available commands, and runs `catfood-doctor` before returning success. If no native Grease from the pinned fork is available, the doctor remains red; a Python-2-free native Grease host producer is separate pending work, not a silent upstream-YSH substitution.

A separately produced host Grease ELF may be adopted by setting these values from its producer evidence before `./catfood`: `CATFOOD_GREASE_NATIVE` (absolute ELF path), `CATFOOD_GREASE_NATIVE_SHA256` (64-character engine hash), `CATFOOD_GREASE_NATIVE_GREASE_SHA` (Grease Git commit), and `CATFOOD_GREASE_NATIVE_SOURCE_SHA` (pinned Oils-derived source Gitlink). The adopter checks host ELF architecture, both revisions, hash, native arithmetic and the existing alias/unalias semantics. A caller-supplied hash is **not** independent producer acceptance; the generated receipt marks that step `NOT_VERIFIED`. Python 2 developer launcher and old full test suite remain separate.

Packaged support runtimes are established before the core source builds. Lua is deliberately acquired from the target package manager rather than becoming another Cat Food-maintained compiler stage.

The core host build currently exercises the repositories that need a real build before they are useful:

- Grease's Oils-derived **source-development interpreter** still uses vendored Python 2. It is **disabled in ordinary Cat Food builds**. An explicitly requested legacy developer build uses `CATFOOD_GREASE_LEGACY_PYTHON2=1`; this does not qualify a Python-2-free native Grease. The stage-one shell is the independently installed native YSH. Cat Food links only a compiled Grease engine installed through the checked source/digest verifier. An unqualified executable found in a checkout is not automatically adopted. If no qualified producer artifact is available, the workbench doctor reports the gap.
- Idriç runs its checked-in `./edric all` bootstrap and focused handoff tests.
- Idric-Net builds and installs its `idric_net` package into the current Idriç prefix before dependent host clients such as ICU are built.
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

Local checkout presence is a separate fact from inventory membership. `./catfood where [TOOL]` emits verified tab-separated `TOOL<TAB>ROLE<TAB>PATH` rows. It considers the running Cat Food control checkout, verified checkouts under the selected Cat Food workbench root, and additional machine-local paths explicitly recorded with `./catfood register TOOL ROLE PATH`. Registration and lookup both verify Git `origin` against Cat Food's repository inventory; stale paths or paths whose origin changes are not reported. Multiple locations for one repository are valid, with roles `workbench`, `acceptance`, `test`, `cache`, `control`, or `other`. The machine-local registry defaults to `${XDG_STATE_HOME:-$HOME/.local/state}/catfood/checkouts.tsv` and may be overridden with `CATFOOD_CHECKOUTS`. Cat Food does not scan arbitrary storage or infer repositories from directory names. On phone and tablet, source repositories are normally absent by design; registration and lookup never clone them or change the runtime-consumer boundary.

### Repository transfers

New clones use the current repository addresses in `tools.tsv`. The finite,
reviewed [repository alias list](repository-aliases.tsv) records former addresses,
current addresses, and GitHub repository IDs observed during the transfer check.
Lookup, registration, bootstrap, and updates share this identity check. Existing
origins and local history are preserved; an unrelated owner with the same
repository name is refused. This is a checked-in transfer record, not a live
GitHub ownership lookup. The offline [regression test](tests/repository-identities.sh)
exercises real Git fetches through both old and current addresses.

## Private provider config

Amazon and AbeBooks credentials stay outside Git. A private config directory can be handed to the provisioner with `CATFOOD_CONFIG_DIR=/private/catfood-config ./provision.sh`; the importer copies only the recognized files to the user configuration directory with restrictive permissions.

## Stable commands

Workbenches keep stable command names under `$CATFOOD_ROOT/bin`. Current host names include `lua`, `luac`, `R`, `Rscript`, `grease`, `edric`, `idris2`, `fieldmouse`, `icu`, `ib-smoke`, `ithon`, `osh`, `ysh`, `az`, `abe`, `gopeed`, `gdl`, `go_down_load`, `fdroid-deploy`, `fdroid-check-deployed`, `jq`, and `mlr` when their targets are present. `aa` is installed when the fed `az` checkout contains `bin/aa`. Management commands are `catfood-update`, `catfood-doctor`, and `catfood-import-config`.

`gdl` and `go_down_load` are aliases of the `gopeed` REST client. It accepts a direct URL or one URL on standard input, so `aa resolve MD5 | gdl` hands a resolved Anna's Archive member URL to Gopeed without making Gopeed part of AA's HTTP transport.

Android product commands come only from successfully installed runtime packages. After the delivered Grease package makes YSH available, the Cat Food control plane itself also installs its small `gopeed` REST client and the `gdl` / `go_down_load` aliases from the checked-out Cat Food version. With the explicit Android option `CATFOOD_INSTALL_CSVKIT=1`, it additionally installs pinned csvkit 2.2.0 into `~/opt/packages/csvkit` from binary Python wheels only and exposes the upstream `csv*`, `in2csv`, and `sql2csv` commands under `~/opt/bin`; that optional path requires Termux Python 3/pip without recommended compiler packages. Existing installed csvkit commands are not deleted when the option is absent. These helpers are convenience software, not Android product-delivery evidence. `android/delivery.tsv` therefore continues to describe only the maintained product inventory and its explicit gaps.

## Stage zero

For a repository-fed workbench that only needs source acquisition without the core builds:

```sh
./bootstrap.sh
```

The phone and tablet do not use `bootstrap.sh` during normal delivery.

`catfood`, `provision.sh`, `bootstrap.sh`, `android/check.sh`, and `android/install.sh` stay POSIX `sh` because they run before Grease can be assumed. The machine-readable shell boundary remains in `ci/shell-boundary.tsv`; ai-ci checks `.ysh` entrypoints and their interpreter boundary separately.
