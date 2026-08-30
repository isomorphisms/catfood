# Cat Food

Feed current copies of our own tools into a fresh development environment, then let those tools build and update one another.

Cat Food is deliberately small. It is not a monorepo: working repositories live under `/opt` by default, not inside this checkout.

## Run Cat Food

After cloning the repository, the obvious entrypoint is the whole command:

```sh
./catfood
```

It detects either a Debian/Ubuntu cloud head or Termux. The same command always
feeds every repository in `tools.tsv`; the platform changes only the preparation
and build policy around that feed.

### Fresh Hetzner / Ubuntu workbench

On a stock Debian/Ubuntu server, get Git, clone Cat Food, and run it:

```sh
apt-get update
apt-get install -y git ca-certificates
mkdir -p /opt

git clone https://github.com/isomorphisms/catfood.git /opt/catfood
cd /opt/catfood
./catfood
```

The cloud path installs the ordinary console/build dependencies used across the current projects, installs a released native YSH when a runnable one is not already present, feeds the repositories, builds the current core toolchain, exposes stable commands, and runs `catfood-doctor` before returning success.

### Android phone / Termux

From Termux on the 32-bit ARMv7 Android Go phone:

```sh
pkg install -y git ca-certificates
git clone https://github.com/isomorphisms/catfood.git "$HOME/opt/catfood"
cd "$HOME/opt/catfood"
./catfood
```

The phone path installs only the small fetch-time command set and feeds every
manifest repository under `$HOME/opt`. It does not claim that the current native
Idriç, Ithon, IR, or YSH builds have passed on ARMv7; those builds remain a
separate real-device acceptance problem. Override `CATFOOD_BUILD_TOOLS=1` or
`CATFOOD_INSTALL_YSH=1` only when deliberately exercising those unfinished
lanes.

The native YSH release is downloaded from Oils, verified by SHA-256, built, and installed under `/usr/local` when provisioning as root. Override `CATFOOD_PREFIX` for another prefix. The source checkout under `grease/source` remains pinned separately for Grease development; the released YSH is the runnable stage-one shell.

The core build currently exercises the repositories that need a real build before they are useful:

- Grease builds its vendored Python 2 bootstrap outside the checkout, generates the pinned Grease source, and exposes that source interpreter as `grease`. The released native YSH remains stage one only.
- Idriç runs its checked-in `./edric all` bootstrap and focused handoff tests, including its pinned threaded Chez Scheme toolchain.
- Fieldmouse is built with that Idriç compiler, runs an interpreter smoke test, and rebuilds when either Fieldmouse or Idriç changes.
- ICU is built with Idriç and OpenSSL into its checked-in `build/exec/icu` command path.
- IB initializes its PDF-harvester submodule and compiles the deterministic `Smoke.idric` program as `ib-smoke`.
- Ithon is configured and built out of tree under `/opt/.build/ithon`, then runs `test_ithon_syntax`.
- IR is built out of tree and installed under `/opt/r`, then smoke-tests the arrow/division/equality syntax.

Build stamps are keyed to each repository commit. `catfood-update` fetches the repositories, rebuilds only core tools whose source commit changed or whose built output is missing, refreshes aliases, and reruns the doctor. Build output stays outside the IR and Ithon checkouts so routine builds do not make those repositories look locally modified.

## Private provider config

Amazon and AbeBooks credentials stay outside Git. Public `az link` and `abe link` work before secrets are configured; Amazon Creators search/price calls and AbeBooks search use provider configuration under `~/.config/az`.

A private config directory can be handed to the provisioner:

```text
/private/catfood-config/
└── az/
    ├── amazon-secret
    └── abebooks-impact
```

Then provision with:

```sh
CATFOOD_CONFIG_DIR=/private/catfood-config ./provision.sh
```

The two files are copied to `~/.config/az` with mode `0600`. The same import can be run later with:

```sh
catfood-import-config /private/catfood-config
```

The importer also accepts the two files directly at the root of the private directory. It never copies arbitrary config or puts secrets in the Cat Food checkout.

## Repository feed

`tools.tsv` is the authoritative current-workbench inventory. It includes:

- the language/toolchain line: Oils (`grease/main`), IR, IRK, Ithon, Icky, ICK, Idriç, Fieldmouse (`edric-rewrite`), the ARM and shader backends, `sent.idr`, the programmer's keyboard, and ICU;
- the browser/publication/workbench line: `az`, `ib`, Internet Archive, BookReader, PDF figure harvesting, DuckDuckGo, Chawan, Manimi, Wegert, `yt-shorts`, `ai-ci`, `computer-science`, and the Android phone utilities;
- the current application and mathematical work: the algebraic-variety explorer, toki pona, `game`, Hegel, geofence, analytic continuation, `non-poly`, coefficient/root dance, Cayley, tablature, ZoneEdit, Conway, `L`, Soap, Klein quartic and Kleinian-group sources, Hopf fibration, Ortho, theta, and Indra's Pearls.

Grease itself is handled first by `bootstrap.sh`. Repositories marked `recursive` in `tools.tsv` have actual submodules and are initialized automatically. Manimi is in the default feed; Manim/`3b1b-videos` is not.

New clones use shallow history, 12 commits by default. Set `CATFOOD_DEPTH` to change that. Existing checkouts are fetched without rewriting their history.

The bootstrap validates manifest structure before touching the workspace. CI also runs `./check-manifest.sh --remote`, which rejects duplicate or malformed entries and verifies that every named remote branch exists.

## Stable commands

After provisioning, Cat Food keeps short command names under `$CATFOOD_ROOT/bin` (`/opt/bin` by default). Provisioning adds both the installed native YSH prefix and that command directory to `PATH`.

Current stable names include `R`, `Rscript`, `grease`, `edric`, `idris2`, `fieldmouse`, `icu`, `ib-smoke`, `ithon`, `osh`, `ysh`, `az`, `abe`, `fdroid-deploy`, and `fdroid-check-deployed` when their targets are present. Management commands are `catfood-update`, `catfood-doctor`, and `catfood-import-config`. The `az` and `abe` wrappers use Bash, matching their checked-in test suite; the F-Droid `.ysh` entrypoints run through the installed YSH command. Grease, OSH, and YSH remain available as explicit stable commands.

For example:

```sh
ithon
idris2 --version
fieldmouse -e 'console.log(6 * 7);'
R --vanilla
az search 'K&R C programming'
abe find 'Sven Nordqvist'
fdroid-deploy path/to/org.example.app.yml
fdroid-check-deployed org.example.app
fdroid-check-deployed org.example.app --version 1.2.3
catfood-update
catfood-doctor
```

`fdroid-deploy` copies one metadata file onto a clean branch of the configured F-Droid GitLab fork, pushes it, and opens or reuses the merge request. It reads `GITLAB_TOKEN` or `~/.config/fdroid-gitlab/token`.

`fdroid-check-deployed` reports the merge-request state and ordinary comments, then checks the live F-Droid package API, public package page, and an expected published version when `--version` is supplied.

`az search` needs the Amazon Creators credentials described by the `az` repository. AbeBooks search needs its client key. Link generation does not require either secret.

Updates are intentionally non-destructive: Cat Food fast-forwards clean checkouts, fetches but does not move dirty ones, refuses an unexpected `origin`, refuses to rewrite diverged local history, and will not replace an unrelated regular file in the stable command directory.

## Stage zero only

If the machine already has what you need and you only want to fetch/update repositories without building the core tools:

```sh
./bootstrap.sh
```

If `/opt` is not writable or you want a different workspace:

```sh
CATFOOD_ROOT="$HOME/opt" ./bootstrap.sh
```

`catfood`, `provision.sh`, `bootstrap.sh`, and `check-manifest.sh` stay POSIX
`sh` because they must work before Grease exists. `bootstrap.sh` fetches Grease
first and preserves Grease's pinned Oils source submodule. If a runnable YSH is
available, Cat Food uses it for the remaining feed; otherwise the updater is
deliberately valid POSIX shell and can complete with `sh`. The complete,
machine-readable shell boundary is in `ci/shell-boundary.tsv`; ai-ci checks every
`.ysh` shebang and rejects a return to running the feed or F-Droid `.ysh`
entrypoints through plain `sh`.
