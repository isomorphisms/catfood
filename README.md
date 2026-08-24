# Cat Food

Feed current copies of our own tools into a fresh development environment, then let those tools build and update one another.

Cat Food is deliberately small. It is not a monorepo: working repositories live under `/opt` by default, not inside this checkout.

## First feed

```sh
./bootstrap.sh
```

If `/opt` is not writable or you want a different workspace:

```sh
CATFOOD_ROOT="$HOME/opt" ./bootstrap.sh
```

`bootstrap.sh` is POSIX `sh` because a stock environment has to be able to run stage zero before Grease exists. It fetches Grease first and preserves Grease's pinned Oils source submodule. If a runnable YSH is already available, Cat Food uses it for the rest of the feed. Otherwise the same updater is deliberately valid POSIX shell and completes the first feed with `sh`; later runs can use Grease/YSH once one is runnable.

New clones use shallow history, 12 commits by default. Set `CATFOOD_DEPTH` to change that. Existing checkouts are fetched without rewriting their history.

`tools.tsv` currently tracks Oils (`grease/main`), IR, IRK, Ithon, Icky, ICK, Idriç, the programmer's keyboard, and `az`. Grease itself is handled first by `bootstrap.sh`. Project names that do not currently resolve to repositories are not guessed into URLs.

## Stable commands

After feeding, Cat Food keeps short command names under `$CATFOOD_ROOT/bin` (`/opt/bin` by default). Put that directory on `PATH`:

```sh
export PATH="${CATFOOD_ROOT:-/opt}/bin:$PATH"
```

It restores the existing stable names when their targets are present: `R`, `Rscript`, `idris2`, `ick`, `ithon`, `osh`, `ysh`, and `grease`. It also installs `az` and `abe` wrappers from the `az` checkout. Those wrappers prefer a runnable YSH and fall back to Bash, so the current Grease/Oils Python-2 bootstrap gap does not prevent the price tools from running on a stock modern machine.

For example:

```sh
az search 'K&R C programming'
abe find 'Sven Nordqvist'
```

`az search` still needs the Amazon Creators credentials described by the `az` repository. AbeBooks/Impact configuration stays in the `az` user config rather than Cat Food.

Updates are intentionally non-destructive: Cat Food fast-forwards clean checkouts, fetches but does not move dirty ones, refuses an unexpected `origin`, refuses to rewrite diverged local history, and will not replace an unrelated regular file in the stable command directory.
