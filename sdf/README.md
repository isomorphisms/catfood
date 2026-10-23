# SDF / NetBSD Cat Food workbench

Target: an explicitly selected SDF login running **NetBSD on amd64**.
The SDF account's actual hostname and NetBSD release are observed on each
invocation; do not infer them from a login banner, or reuse Linux artifacts.

## Layout

- `~/code/catfood`: Cat Food's control checkout.
- `~/code/Idric` and `~/code/<inventory-name>`: Git sources, never inside `~/opt`.
- `~/opt/bin`: stable commands.
- `~/opt/packages`, `~/opt/downloads`, `~/opt/receipts`: runtime
  packages, downloads and plaintext receipts, respectively.

Existing personal directories, including `Mail`, `mail` and `~/opt/mbox`,
are not moved, deleted or overwritten. Previous Grease command launchers in
`~/opt/bin` and `~/bin` are backed up in their original directories **only
after the new native package passes its tests**. Other conflicting paths
fail closed. Shell startup files are not edited. SDF is a shared
system: one build job by default, at reduced scheduling priority.

## First SDF run: Grease first (inside an already-connected SDF shell)

This branch is a qualification candidate, not a proven installation. Check
`~/code/catfood` before cloning; never replace a preexisting checkout.

```sh
uname -s
uname -r
uname -m
if [ ! -e "$HOME/code/catfood" ]; then
    mkdir -p "$HOME/code"
    git clone --depth 1 --single-branch \
        --branch platform/sdf-netbsd-idric-toolchain \
        https://github.com/isomorphisms/catfood.git \
        "$HOME/code/catfood"
fi
CATFOOD_TARGET=sdf CATFOOD_SDF_FEED=grease sh "$HOME/code/catfood/catfood"
```

This defaults to the native NetBSD 9.3 Grease C++ package; it verifies the
pinned archive checksum, checks source and release identity, executes aliases,
unalias and arithmetic with the unpacked binary, and then activates
`~/opt/bin/grease` and the existing `~/bin/grease` launcher if present.
Its installed executable can be rechecked independently:

```sh
CATFOOD_TARGET=sdf sh "$HOME/code/catfood/sdf/check-grease.sh"
```

When proceeding to the compiler later, run the stronger read-only preflight:

```sh
CATFOOD_TARGET=sdf sh "$HOME/code/catfood/sdf/preflight.sh"
```

Review the preflight output before starting a compiler build. It observes
commands and paths, including the unknown version of `python`, but does not
modify anything. The compiler preflight requires `git`, `cc`, GNU `gmake`, `tar`, SHA-256
verification and `curl` or `wget`. Grease's binary release installer does
not require a compiler. No `gh`, Python, sudo, root, apt or Linux binary is assumed.

The pinned Idriç NetBSD portability work is currently on the draft
[Idriç PR #145](https://github.com/isomorphisms/Idric/pull/145).
Until merged, **explicitly** qualify that branch rather than pretending it
is on the default `Idriç` branch:

```sh
CATFOOD_TARGET=sdf \
CATFOOD_SDF_FEED=core \
CATFOOD_SDF_IDRIC_BRANCH=platform/netbsd-chez-bootstrap \
CATFOOD_JOBS=1 \
sh "$HOME/code/catfood/catfood"
```

This fetches the Idriç source under `~/code/Idric`, builds the pinned
threaded Chez 10.4.1 for `ta6nb`, bootstraps Idriç, runs its existing
focused tests, and adds `edric`, `idris2`, `catfood-update` and
`catfood-doctor` under `~/opt/bin` **only after successful execution**.
It runs the verified Grease phase first and never substitutes an older
Grease or unqualified D binary. A checksum-bearing compiler receipt is written to `~/opt/receipts/idric-netbsd-amd64.tsv` only
after native compilation and test completion.

To feed **all** Cat Food inventory sources rather than only Idriç, explicitly
request the larger clone set:

```sh
CATFOOD_TARGET=sdf \
CATFOOD_SDF_FEED=all \
CATFOOD_SDF_IDRIC_BRANCH=platform/netbsd-chez-bootstrap \
CATFOOD_JOBS=1 \
sh "$HOME/code/catfood/catfood"
```

This is potentially large on a shared host. It feeds the manifest; it does
**not** mean every source project has a working NetBSD executable.

The installed command inventory is checked without changing the machine:

```sh
sh "$HOME/code/catfood/sdf/doctor.sh" grease
sh "$HOME/code/catfood/sdf/doctor.sh" core
sh "$HOME/code/catfood/sdf/doctor.sh" full
```

The full doctor reports missing, host-only and unverified commands rather
than treating a source clone or similarly named system executable as a
success. Full mode fails closed until every runtime is independently qualified. Missing `jq`, `mlr`, `lua`, `R`, `ithon`, `icu`, `ick`
and others still require target-specific build/acquisition contracts.

## Evidence and limitations

- NetBSD/amd64 platform, Chez machine type `ta6nb`, source revision,
  compiler digest, bootstrap and focused tests are distinct receipt fields.
- A complete toolset requires actual runtime checks for every intended
  command; the current SDF work is a **Grease-first implementation** with
  separately qualified Idriç work, not that acceptance.
- The synthetic Linux CI test exercises refusal behavior, while a distinct
  NetBSD 9.3 VM workflow tests native package installation. Neither is a
  live SDF account run. Submit actual SDF output/receipt before promotion.
- No live mailbox writes. The preflight never inspects mailbox messages or
  alters case-distinct `Mail` and `mail`.
- `CATFOOD_SDF_IDRIC_BRANCH` is a temporary, explicit qualification
  override. Once the compiler PR is integrated, change branches only after
  checking the SDF worktree is clean; provisioning will never silently
  switch an existing checkout.

## Grease login configuration

The new native Grease executable is **not** a guarantee that an already
running interactive `ysh` has switched to it. Check `command -v grease`,
`command -v ysh`, `$SHELL`, `~/bin/grease` and `~/opt/bin/grease`
separately. In a YSH config that uses `alias`, the alias must appear
after `shopt -s ysh:all`. The installer does not modify personal rc
files or use `chsh`. Existing YSH login configuration may still invoke
a different Oils executable.

The NetBSD 9.3 Grease package is built from Grease revision
`c9caca81a549b24568799233f9bc33c5da713ba4` with pinned Oils
revision `5651cf97a1b5042f24f14112a7ade9a1518eb0bc`. Its archive
SHA-256 is declared in `sdf/grease-release.tsv`. NetBSD 11 or another
release must have a separate package; do not run this ABI's binary there.
`greased` (D) is explicitly NOT accepted as a replacement.
