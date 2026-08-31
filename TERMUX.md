# Cat Food on Termux

The phone workbench lives under `~/opt`, not `/opt`.

`termux-bootstrap.sh` is the stage-zero exception to the Grease-first rule: a fresh phone may not have Grease yet, so this one entry point is portable `sh`. It installs only missing Termux prerequisites needed for the feed (`git`, `curl`, `jq`, and, when Grease must be built, `clang` and `make`). It then hands the final environment checks to `termux-setup.grease`.

The phone feed uses depth 1 by default. Existing Git checkouts immediately under `~/opt` are inspected before cloning. If an existing checkout's `origin` matches a repository in `tools.tsv`, Cat Food fetches it in place, fast-forwards it only when clean, initializes declared submodules, and removes that entry from the temporary clone feed. A noncanonical existing checkout gets a canonical symlink under `~/opt` when that path is free. Dirty or diverged work is not rewritten.

Run from a Cat Food checkout:

```text
CATFOOD_ROOT="$HOME/opt" ./termux-bootstrap.sh
```

The script ensures `~/opt/bin` is in its own `PATH` immediately and appends a guarded `~/opt/bin` block to `~/.bashrc` for future Termux shells.

## OpenAI API key

Cat Food never contains an OpenAI API key. The phone bootstrap looks first at `OPENAI_API_KEY`, then at the private file `~/.openai_api_key`. If neither exists it prints `SKIP openai-api-key` and continues the non-secret setup.

A private key file should contain only the key and should have mode `0600`. The bootstrap adds this loader to `~/.bashrc` without putting the secret itself there:

```text
if [ -z "${OPENAI_API_KEY:-}" ] && [ -s "$HOME/.openai_api_key" ]; then
    OPENAI_API_KEY=$(cat "$HOME/.openai_api_key")
    export OPENAI_API_KEY
fi
```

`termux-setup.grease` reports the key only as `PASS` or `SKIP`; it never prints the value. If the `ai-ci` checkout contains the Blackball live smoke/client pair, the Grease check reports the exact command as `READY`. It does not claim a live API pass merely because the credential exists.

## Receipts

The intended distinctions are:

- `PASS` — the local prerequisite or runtime check actually succeeded;
- `SKIP` — an optional secret or not-yet-landed live test is absent;
- `BLOCKED` — stage zero cannot produce a runnable Grease interpreter;
- no silent fallback from Grease to Bash after Grease is expected to exist.
