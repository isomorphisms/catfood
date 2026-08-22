# cat food

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

`tools.tsv` currently tracks Oils (`grease/main`), IR, IRK, Ithon, Icky, ICK, Idriç, and the programmer's keyboard. Grease itself is handled first by `bootstrap.sh`. Project names that do not currently resolve to repositories are not guessed into URLs.

Updates are intentionally non-destructive: Cat Food fast-forwards clean checkouts, fetches but does not move dirty ones, refuses an unexpected `origin`, and refuses to rewrite diverged local history.
