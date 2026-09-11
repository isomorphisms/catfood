# Cat Food follower architecture

Cat Food lets phone or tablet work lead, but every affected maintained target must either produce independent acceptance evidence or remain durable unfinished work.

The target meanings remain defined in [`TARGETS.md`](../TARGETS.md). Physical phone, physical tablet, disposable/container Linux, GitHub-hosted Linux, and persistent Hetzner/cloud acceptance are not interchangeable.

## Source state and bookkeeping

Follower jobs bind to an exact source commit. Later commits that add jobs, receipts, or policy do not change the source state being followed. Version 1 therefore uses `follow_policy=exact`: moving a follower to a descendant requires an explicit new job or recorded supersession.

`followers/targets.tsv` is the concrete maintained target registry. `termux-generic` remains a compatibility selector rather than a concrete independently accepted machine. If it becomes a maintained concrete environment, give it a real acceptance action and promote it in the registry rather than treating generic Termux selection as proof.

`followers/impact-rules.tsv` maps changed paths to affected targets. Rules are first-match and conservative:

- follower-control and policy files do not create product follower debt;
- `android/` changes affect the physical phone, physical tablet, and GitHub artifact-contract follower;
- Android contract tests affect the GitHub artifact-contract follower;
- ordinary GitHub workflow changes affect GitHub-hosted x86-64;
- everything else defaults to the concrete phone, tablet, GitHub x86-64, independent container/local x86-64, and Hetzner x86-64 targets.

That default is intentional for shared source, command-line tools, parsers, host build/install code, native boundaries, packaging, tests, and other portable mechanics. Add a narrower rule only when the design really is platform-specific.

## Jobs and receipts

Jobs live under `followers/jobs/`; receipts live under `followers/receipts/`. Their schemas and exact acceptance invariants are owned by AICI's `aici-followers` verifier rather than duplicated here.

A job carries the exact trigger commit, leader, follower, architecture, required action, acceptance kind, artifact identity/hash where applicable, state, blocker, evidence, dependencies, and supersession. A passing receipt must match the exact source/follower/acceptance/artifact identity before a job can become `accepted`.

Build, runtime, artifact, physical-device, and publication acceptance are separate evidence kinds. `unsupported`, `blocked`, and `not run` are not green. Conditional `n/a` requires an explicit reason.

For architecture-specific Cat Food artifacts, record the artifact name and SHA-256 in the follower job. A receipt for a different artifact cannot satisfy it. Both Android targets are runtime-only consumers in the normal Cat Food path: missing ARMv7 or AArch64 output stays explicit rather than turning either device into a source build farm. Android delivery gaps do not authorize unrelated experimental compiler/backend gates, and Android capacity does not substitute for x86, Hetzner, or GitHub acceptance.

## Operations

With `AICI_FOLLOWERS` pointing to the compiled AICI verifier:

```sh
sh followers/manage.sh affected <source-commit>
AICI_FOLLOWERS=/path/to/aici-followers sh followers/manage.sh \
  prepare <source-commit> phone armv7 <leader-receipt-or-> <branch> <pr>
AICI_FOLLOWERS=/path/to/aici-followers sh followers/manage.sh reconcile <source-commit>
AICI_FOLLOWERS=/path/to/aici-followers sh followers/manage.sh pending <source-commit>
AICI_FOLLOWERS=/path/to/aici-followers sh followers/manage.sh matrix <source-commit>
AICI_FOLLOWERS=/path/to/aici-followers sh followers/manage.sh record <job-id> <receipt-file>
sh followers/manage.sh block <job-id> '<reason>' [last-attempt-commit]
sh followers/stale.sh
```

`pending` is the direct answer to “what is still behind this phone/tablet work?” It is also available without the verifier as a read-only fallback; mutation and reconciliation require the verifier.

`reconcile` re-infers the affected target set and fails if a required follower job disappeared or references a removed target. `stale.sh` fails when unresolved work remains on an ancestor of the latest source trigger. Finish it or record explicit supersession; moving the branch does not erase the dependency.

## GitHub x86-64

The follower workflow checks out the exact trigger into a detached worktree and runs `followers/accept-x86.sh` against that tree. This is runtime-oriented acceptance, not syntax-only CI. Its receipt is published as a workflow artifact and records the exact trigger, runner runtime, command, and evidence URL.

A workflow artifact is evidence available for recording; it does not mutate the repository ledger by itself. The checked-in job becomes accepted only after a matching receipt is recorded. Thus GitHub cannot silently promote itself merely because some unrelated check is green.

The x86 path is also an independent portability check. Shared code should expose accidental ARM width/alignment assumptions, Android/Bionic-only filesystem or libc assumptions, shell/tool assumptions, JNI/DEX leakage into portable layers, backend coupling, and unsupported assembly rather than concealing them. Platform-specific implementation remains platform-specific when the rules say so.

## Hetzner

Hetzner is the persistent `cloud` acceptance environment, not an alias for a GitHub runner or disposable container receipt. A Hetzner job contains enough source and command information for an agent on that host to execute it cold. If the host or credentials are unavailable, the job stays blocked; no surrogate receipt is manufactured.

## Current bootstrap

The initial ledger concentrates on current `main` rather than manufacturing historical chores. Existing exact GitHub-hosted evidence can be recorded independently; physical phone/tablet, independent container/local x86-64, and Hetzner remain pending or blocked until actually exercised.
