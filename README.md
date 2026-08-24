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

`provision.sh` installs the ordinary console/build dependencies used across the current projects, installs the released native YSH if a runnable one is not already present, feeds the repositories, exposes command wrappers, and runs `catfood-doctor` before returning success.

The native YSH release is downloaded from Oils, verified by SHA-256, built, and installed under `/usr/local` when provisioning as root. Override `CATFOOD_PREFIX` for another prefix. The source checkout under `grease/source` remains pinned separately for Grease development; the released YSH is the runnable stage-one shell.

After provisioning these commands are on `PATH`:

```text
az
abe
catfood-update
catfood-doctor
```

`az link` and `abe link` need no secret credentials. Amazon Creators search/price calls and AbeBooks search need their provider credentials under `~/.config/az`; Cat Food creates the configuration directory but never commits or invents secrets.

## Repository feed

The workbench feed currently includes the language/toolchain repositories plus the active cross-thread tools and projects: `az`, `ib`, `internetarchive`, `manimi`, `wegert`, and `yt-shorts`. Repositories marked `recursive` in `tools.tsv` have their submodules initialized automatically, so newly pinned project dependencies come across on the next feed.

New clones use shallow history, 12 commits by default. Set `CATFOOD_DEPTH` to change that. Existing checkouts are fetched without rewriting their history.

Updates are intentionally non-destructive: Cat Food fast-forwards clean checkouts, fetches but does not move dirty ones, refuses an unexpected `origin`, and refuses to rewrite diverged local history.

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
