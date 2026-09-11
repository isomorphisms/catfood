# Agent instructions

Apply the shared evidence and acceptance guardrails in `isomorphisms/ai-ci/AGENTS.md`.

Before changing this repository, read its README and repository-local documentation, inspect current nearby work, and preserve established architecture, terminology, source/build layout, and explicit current human corrections.

Keep this file repository-specific. Do not copy the shared `ai-ci` rulebook here.

## Android delivery

Before changing phone/tablet delivery, read [`android/README.md`](android/README.md), `android/delivery.tsv`, and `android/packages.tsv`.

- Every `tools.tsv` row plus the separate Grease bootstrap entry must have exactly one Android delivery classification.
- Do not omit a difficult intended runtime to make the distribution look green. Leave it as `gap:<reason>` or unresolved `review` work.
- Phone and tablet are runtime consumers. Their normal path must not clone the source fleet, bootstrap compilers, install build toolchains, or fall back to source builds.
- Direct DEX/ART plus explicitly intended JNI/NDK code is the current Android path where needed. Do not substitute Java/Kotlin/Gradle/d8 or RefC/generated-C lowering.
- Unfinished ARM/Thumb or other experimental native backends are not prerequisites for unrelated Android delivery.
- Bind packages to exact source/package commits, ABI, URL, SHA-256, runtime dependencies, and package dependencies.
- Keep publication, digest verification, installation, launch, behavior, emulator evidence, and physical-device evidence separate.

Run `sh tests/android-delivery.sh` for repository-side contract changes. `sh android/check.sh ready phone|tablet` is intentionally allowed to remain red while declared runtime gaps exist.

## Mobile leader and follower rule

Before finishing phone or tablet development, read [`docs/followers.md`](docs/followers.md) and inspect `followers/targets.tsv` and `followers/impact-rules.tsv`.

For the exact source commit being led from mobile:

- infer affected followers rather than relying on a human reminder to test x86;
- run follower checks available in the current environment;
- create durable follower jobs for every affected environment that cannot run here;
- bind jobs and artifacts to exact commits and SHA-256 identities;
- never claim GitHub, local/container x86-64, Hetzner, tablet, or phone acceptance from another target's receipt;
- preserve build, runtime, artifact, publication, and physical-device evidence as separate acceptance kinds;
- leave inaccessible or unsupported targets pending/blocked/unsupported rather than calling them green;
- record explicit supersession when later work replaces an unfinished follower obligation.

Before declaring follower work caught up, run AICI follower verification/reconciliation, `sh followers/stale.sh`, and inspect `sh followers/manage.sh pending <source-commit>`. A follower closes only after its required matching receipt exists.
