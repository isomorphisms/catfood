# Cat Food

Feed current copies of our own tools into a fresh development environment, then let those tools build and update one another.

Cat Food is deliberately small. It is not a monorepo: working repositories live under `/opt` by default, not inside this checkout.

## Fresh Hetzner / Ubuntu workbench

On a stock Debian/Ubuntu server, get Git, clone Cat Food, and provision the machine:

```sh
apt-get update
apt-get install -y git ca-certificates
mkdir -p /opt

git clone https://github.com/isomorphisms/catfood.git /opt/catfood
cd /opt/catfood
./provision.sh
```

`provision.sh` installs the ordinary console/build dependencies used across the current projects, installs the released native YSH if a runnable one is not already present, feeds the repositories, exposes stable commands, and runs `catfood-doctor` before returning success.

The native YSH release is downloaded from Oils, verified by SHA-256, built, and installed under `/usr/local` when provisioning as root. Override `CATFOOD_PREFIX` for another prefix. The source checkout under `grease/source` remains pinned separately for Grease development; the released YSH is the runnable stage-one shell.

Amazon and AbeBooks credentials stay outside Git. Public `az link` and `abe link` work before secrets are configured; Amazon Creators search/price calls and AbeBooks search use the provider configuration under `~/.config/az`.

## Repository feed

The workbench feed currently includes Oils (`grease/main`), IR, IRK, Ithon, Icky, ICK, Idriç, the programmer's keyboard, `az`, `ib`, `internetarchive`, `manimi`, `wegert`, and `yt-shorts`. Grease itself is handled first by `bootstrap.sh`. Repositories marked `recursive` in `tools.tsv` have their submodules initialized automatically.

New clones use shallow history, 12 commits by default. Set `CATFOOD_DEPTH` to change that. Existing checkouts are fetched without rewriting their history.

## Stable commands

After feeding, Cat Food keeps short command names under `$CATFOOD_ROOT/bin` (`/opt/bin` by default). Provisioning adds both the installed native YSH prefix and that command directory to `PATH`.

The feed restores existing stable names when their targets are present: `R`, `Rscript`, `idris2`, `ick`, `ithon`, `osh`, `ysh`, and `grease`. It also installs `az` and `abe` wrappers from the `az` checkout. Those price wrappers prefer a runnable YSH and fall back to Bash, so stage zero remains usable even before native YSH has been installed.

For example:

```sh
az search 'K&R C programming'
abe find 'Sven Nordqvist'
catfood-update
catfood-doctor
```

`az search` needs the Amazon Creators credentials described by the `az` repository. AbeBooks search needs its client key. Link generation does not require either secret.

Updates are intentionally non-destructive: Cat Food fast-forwards clean checkouts, fetches but does not move dirty ones, refuses an unexpected `origin`, refuses to rewrite diverged local history, and will not replace an unrelated regular file in the stable command directory.

## Stage zero only

If the machine already has what you need and you only want to fetch/update repositories:

```sh
./bootstrap.sh
```

If `/opt` is not writable or you want a different workspace:

```sh
CATFOOD_ROOT="$HOME/opt" ./bootstrap.sh
```

`bootstrap.sh` stays POSIX `sh` so a stock environment can run stage zero before Grease exists. It fetches Grease first and preserves Grease's pinned Oils source submodule. If a runnable YSH is available, Cat Food uses it for the remaining feed; otherwise the updater is deliberately valid POSIX shell and can complete with `sh`.
