# IB: checkout lookup and ordinary-file baseline

Cat Food owns checkout locations and runtime delivery. Kitchen owns the tested
human-facing procedure. Neither a source checkout nor a passing source fixture
is an Android delivery receipt.

Use Cat Food's existing `where ib` command through the verified Cat Food control
checkout. It returns `TOOL<TAB>ROLE<TAB>PATH` rows, not one implicitly preferred
path. An empty result means no verified checkout among its declared candidates;
it does not mean no IB checkout exists anywhere on the phone.

The 2026-10-04 MIRO A1 Termux session established an acceptance checkout at
`/data/data/com.termux/files/home/ib-e2-check`. This is a dated observation, not a
portable default. Reverify it before reuse. Do not clone again because it exists,
scan arbitrary HOME paths, switch its branch, or erase partial/unrecognized
contents. An explicitly chosen, origin-verified checkout may be recorded through
Cat Food's existing `register ib acceptance PATH` operation. Registration is
idempotent for the same repository/path. The session did not establish that this
registration has been performed on the phone.

## Evidence and next action

The reported ordinary-file baseline passed at IB source
`f1f22778fb66f7219c13ba864c13b03be10cfea8`, implementation blob
`bdabc03428d7e7d9b7f098b3dc61321798d9dc74`, and regression blob
`b7147483cea50e095193e7e59609091efe2a3aa4`.

The claimed E2 repair `5184f62fb9183f300cde615fa06ca0cfa561040c` was unavailable
in the fetched checkout and could not be resolved by the preceding GitHub read.
That observation does not prove the commit never existed in another local
workspace. E2 remains blocked on materializable repaired source; do not silently
substitute the passing older baseline.

The canonical Kitchen task is `tasks/ib-durable-store/README.md`, with versioned
runner `tasks/ib-durable-store/2.sh`, `baseline.lock`, and executable regression
`tests/ib-durable-store.sh` in `isomorphisms/kitchen`. Use only a materialized,
verified Kitchen revision containing all of them; a link or a moving branch name
alone does not establish availability. The runner accepts an explicit checkout,
extracts the exact committed blobs into temporary storage, preserves the user's
working tree, and reports `baseline=PASS` separately from `e2=NOT_RUN`.

Before issuing a downstream repair command, its producer must provide a remotely
retrievable exact source or a verified handoff artifact, pinned implementation
and test identities, and executed wrapper evidence. A chat-only SHA is not a
ready prerequisite. Missing path, missing source, and failed execution are
separate stages. Never use an unguarded pasted `exit` that logs out the human.

See `docs/observations/miro-a1-ib-baseline-2026-10-04.tsv` for the dated user
report. It is not an installer-generated receipt or new physical acceptance of
the Kitchen runner. Phone provisioning, Shizuku, installed apps, signing identity,
and runtime packages are unchanged by this documentation and diagnostic work.

Prepared Kitchen revision: `fcb517460c5484de513bc8ead8296b40b7a91677`.
The version-2 runner blob is `2236d6780b1f6257ac2411d35cf43d631d1c77c4`,
and its baseline lock blob is `eee8a98d3ecd2166f1ce898fa70a501135ec1feb`.
This identifies the reviewed handoff, not installation on the phone.
