# Follower reconciliation for repository-transfer cleanup

The exact source trigger is `1b8d4a1aedf27f5743ae528b269b342b40cc2fdf` in PR #81.
Six current jobs cover container, GitHub, Hetzner, phone, tablet, and published
artifacts. All remain pending until matching evidence is recorded. Container
identifies the environment doing this repair; it is not an acceptance claim.

## Integrated inventory work

The source state of `e7bb4bf635c63e28607b8473f86d5bccb0d16da4` equals
the squash integration `86ee203a83f3ea4bf056c011676df6bb2eaf33ce` after
excluding follower control files. The integration is an ancestor of this
trigger. Its six pending inventory jobs are superseded by the six current
jobs with the same target and acceptance kind. The artifact job is explicitly
carried forward even though the last source commit alone infers five targets.

The comparison excludes `followers/**`, `AGENTS.md`, `docs/followers.md`,
`tests/followers.sh`, and `.github/workflows/followers.yml`, matching the
source-state boundary used by the follower controller. No old receipt is
reused for the new source.

## Specific earlier obligations retained

Six jobs at `06d1d4fda80e2801fefed36a1ea6148c31cd8fe7` remain pending.
Its non-control source equals integration
`704e7bf06127373f86bbf1e9c3d363fab429540c`, an ancestor of this trigger,
but each job explicitly binds the az-phone artifact and SHA-256
`11f824ae140b39d88493a5325d5776b410985cac851eb28fc3cbaa38385b9098`.
That artifact remains in the current inventory. These exact obligations are
retained separately rather than losing their artifact binding in the generic
current jobs. Their eventual acceptance or explicit scope-preserving
supersession still needs evidence.

The three unresolved Reddit-specific jobs at
`ed492ef799003a67d8ca824ba518151682c87a23` also remain unchanged:
phone and tablet are pending, and artifact acceptance is blocked. They require
the real Reddit backend/package evidence named in those records; generic
inventory checks cannot discharge them.

## Evidence boundary

This repair leaves 15 unresolved jobs: six current inventory jobs, six
az-phone-bound jobs, and three Reddit jobs. It does not accept any target or
modify historical receipts. The ancestry-based stale check alone cannot
discover unresolved work on squash-merged branch commits; the mappings above
were checked explicitly. The GitHub workflow must provision the exact source
and execute its installed doctor before publishing a runtime receipt.
