# Agent instructions

Apply the shared evidence and acceptance guardrails in `isomorphisms/ai-ci/AGENTS.md`.

Before changing this repository, read its README and repository-local documentation, inspect current nearby work, and preserve established architecture, terminology, source/build layout, and explicit current human corrections.

Keep this file repository-specific. Do not copy the shared `ai-ci` rulebook here.

## Local checkout locations

- Treat `tools.tsv` as inventory, not proof that a checkout exists on the current machine.
- Do not guess checkout paths from repository names, `$HOME`, `/opt`, or the canonical workbench location shown by `catfood help`.
- Use `./catfood where TOOL` when a task depends on a local repository path. Use the returned path only when the command succeeds; `./catfood where` lists all verified local Cat Food checkouts.
- Phone and tablet are runtime consumers, so a missing source checkout there is normally correct. Do not clone the source fleet merely to satisfy a local-path lookup.

## Device identity and storage paths

Cat Food is the canonical place to record device-local path and mount facts.
Before giving a phone or tablet command that depends on repository location,
executable location, shared storage, or removable storage:

- Never copy a storage assumption from phone to tablet or tablet to phone.
  Model, architecture, mount aliases, removable media, free space, and
  executable locations are independent facts.
- `~/storage/downloads` is Android shared Downloads, not a synonym for an SD
  card. Call storage "external SD" only after the exact device shows a distinct
  removable mount such as a verified `~/storage/external-1`.
- Verify mutable paths on the exact device with `readlink -f`, `df -h`,
  existence/mount checks, or an execution probe when execution capability
  matters. Android shared/removable storage may be `noexec`.
- **Phone convention:** `~/opt/bin` is the preferred executable location on
  the phone's internal Termux storage. The phone has previously exposed an
  external SD card as `~/storage/external-1` (historically resolving to
  `/storage/4A21-0000/Android/data/com.termux/files`), but removable media must
  still be verified before use. Do not project either fact onto the tablet.
- **Tablet observation, verified 2026-09-18:** physical `TAB_P10`,
  `sun65iw1p1`, `aarch64`; `~/storage/downloads` resolves to
  `/storage/emulated/0/Download`; `~/storage/external-1` is absent; no
  working external SD card has been established. Shared Downloads rejected
  direct ELF execution, while private Termux storage executed the same Mali-G57
  test binary. Do not call tablet Downloads an SD card.
- **Tablet ADB boundary, verified 2026-09-18 and explicitly deferred:** do
  not turn a physical tablet test that can run directly under Termux into an ADB
  prerequisite. The current Termux client reports `adb mdns services` as
  unsupported and same-device Android 15 wireless pairing failed with
  `protocol fault (couldn't read status message): Success`. ADB setup is a
  separate problem for another session. Do not ask the human to retry pairing,
  install ADB tooling, or route ordinary tablet acceptance through ADB unless
  the human explicitly reopens ADB work.
- **Tablet removable-storage boundary, verified 2026-09-18 and explicitly
  deferred:** `~/storage/external-1` is absent and no working external SD card
  has been established on `TAB_P10`. Do not prescribe SD-card paths, SD-card
  diagnostics, or moving work to removable storage on this tablet unless the
  human explicitly reopens the tablet SD-card problem and new direct evidence
  establishes a working mount.
- When these facts change, update this section rather than relying on chat
  history or another device's layout.

## Android delivery

Before changing phone/tablet delivery, read [`android/README.md`](android/README.md), `android/delivery.tsv`, and `android/packages.tsv`.

- Every `tools.tsv` row plus the separate Grease bootstrap entry must have exactly one Android delivery classification.
- Do not omit a difficult intended runtime to make the distribution look green. Leave it as `gap:<reason>` or unresolved `review` work.
- Phone and tablet are runtime consumers. Their normal path must not clone the source fleet, bootstrap compilers, install build toolchains, or fall back to source builds.
- Direct DEX/ART plus explicitly intended JNI/NDK code is the current Android path where needed. Do not substitute Java/Kotlin/Gradle/d8 or RefC/generated-C lowering.
- Unfinished ARM/Thumb or other experimental native backends are not prerequisites for unrelated Android delivery.
- Bind packages to exact source/package commits, ABI, URL, SHA-256, runtime dependencies, and package dependencies.
- Keep publication, digest verification, installation, launch, behavior, emulator evidence, and physical-device evidence separate.
- `gopeed`, `gdl`, and `go_down_load` on phone/tablet are Cat Food control-plane helpers installed after YSH is delivered; their presence does not claim that Cat Food delivered or accepted the Gopeed Android app. Ordinary unprivileged Termux must use Gopeed's TCP loopback API for cross-app control; do not assume an app-private Unix socket is reachable and do not rewrite Gopeed's private settings on the user's behalf.
- When a phone/tablet command block is meant to produce output the human will paste back, use ANSI-colored section/action/PASS/FAIL markers when supported so the requested result is easy to find. Keep receipt fields and other machine-readable evidence plain, and never make color the only signal.

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
