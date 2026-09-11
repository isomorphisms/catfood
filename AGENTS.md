# Agent instructions

Apply the shared evidence and acceptance guardrails in
`isomorphisms/ai-ci/AGENTS.md`.

Before changing this repository, read its README and repository-local
documentation, inspect the current branch/worktree and nearby active work, and
preserve established architecture, terminology, source/build layout, and
explicit current human corrections.

Keep this file repository-specific. Add local rules as the project develops; do
not copy the shared `ai-ci` rulebook here.

## Mobile leader and follower rule

Before finishing phone or tablet development, read [`docs/followers.md`](docs/followers.md)
and inspect `followers/targets.tsv` and `followers/impact-rules.tsv`.

For the exact source commit being led from mobile:

- infer the affected followers rather than relying on a human reminder to test x86;
- run follower checks available in the current environment;
- create durable follower jobs for every affected environment that cannot run here;
- bind jobs and artifacts to exact commits and SHA-256 identities;
- never claim GitHub, local/container x86-64, Hetzner, tablet, or phone acceptance from another target's receipt;
- preserve build, runtime, artifact, publication, and physical-device evidence as separate acceptance kinds;
- leave inaccessible or unsupported targets pending/blocked/unsupported rather than calling them green;
- record explicit supersession when later work replaces an unfinished follower obligation.

Before declaring the work caught up, run AICI follower verification/reconciliation,
`sh followers/stale.sh`, and inspect `sh followers/manage.sh pending <source-commit>`.
A follower closes only after its required matching receipt exists.
