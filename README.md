# dogfood

Provisional bootstrap repository for using our own tools in fresh development environments.

The repository name is provisional. Its job is to get from a stock container to current copies of the toolchain without pretending the container itself is durable.

## Bootstrap

The unavoidable stage zero is deliberately small and uses POSIX `sh`, not Bash. It needs only `git` plus whatever the current Grease implementation itself needs.

```sh
sh bootstrap.sh
```

`bootstrap.sh` fetches or fast-forwards `tools/grease`, initializes Grease's pinned source submodule, and then immediately hands control to Grease/YSH for the rest of the updates.

`update-tools.ysh` reads `tools.tsv` and fetches or fast-forwards the remaining tool repositories under `tools/`.

Current manifest:

- ICK
- Icky
- Idriç (`Idric` on GitHub)
- Ithon

Grease is not listed in `tools.tsv` because it is the bootstrap interpreter and is updated first by `bootstrap.sh`.

The nested checkouts are ignored by this repository. The scripts use `git -C` rather than a directory stack, so stage zero does not require Bash-only `pushd`/`popd` behavior.

Updates are intentionally non-destructive: existing tool checkouts must fast-forward. A divergent local branch causes the update to stop instead of resetting or deleting local work.
