# cat food

Feed the current versions of our own tools into a fresh workspace, then use those tools to build one another.

Cat food is deliberately not a monorepo. This checkout stays small; working repositories live under `/opt` by default.

## First feed

```sh
./bootstrap.sh
```

To use a different workspace:

```sh
CATFOOD_ROOT="$HOME/opt" ./bootstrap.sh
```

`bootstrap.sh` is POSIX shell on purpose: a stock environment has to be able to run it before Grease exists. Once Grease/Oils are available, richer shell work belongs there rather than growing the bootstrap shell.

The manifest is `repositories.tsv`. The initial set is Grease, the Oils `grease/main` line, IR, IRK, Ithon, Icky, ICK, Idriç, and the programmer's keyboard. Names that do not currently resolve as repositories are not guessed into the manifest.

## What feeding does

- clone missing repositories with shallow history (12 commits by default)
- fetch and fast-forward an existing clean checkout
- fetch but do not move a dirty checkout
- refuse to rewrite diverged local history
- leave an unexpected non-git path or unexpected `origin` alone
- keep Grease's source submodule at the commit pinned by the Grease repository

Set `CATFOOD_DEPTH` to change the shallow-history depth.

## See what is installed

```sh
./status.sh
```
