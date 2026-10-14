# MIRO C67: Cat Food Grease used for a live GitHub ownership-transfer batch

On 2026-10-09 the Cat Food AArch64 Grease package on the physical MIRO C67 executed the maintained Kitchen/Flexible Pipes transfer batch that moved ten repositories from `isomorphisms` to `isomorphismes`.

The machine-readable observation is [`miro-c67-grease-github-transfer-2026-10-09.tsv`](miro-c67-grease-github-transfer-2026-10-09.tsv).

## Package and installation

The C67 consumed the `arm64-v8a` package lane through package ID `grease-tablet`; the physical target remained `c67` and was not relabeled as a tablet.

- source revision: `8052868773077602266d80bf39aad6998e2da749`
- packaging revision: `9b3dc89048911bd0e23ee992fe00dcb3cd427f63`
- archive SHA-256: `3ddb962ef313e528e525fa03518f494577e921c2201ecb49f7a11f2fbf4e82b2`
- installed command: `$HOME/opt/bin/grease`

The archive was downloaded and verified by Cat Food's declared Android installer. The complete `./catfood` provisioner did not finish: its pinned generic `linux-aarch64` jq asset failed its runtime probe on Termux before Android package delivery. The successful package installation therefore used `android/install.sh` directly. That workaround preserved Cat Food's target identity, manifest, package digest, and installation checks; it did not qualify the broken full-provisioner path.

## Physical runtime observation

The user ran a blob-pinned, ordinary plain-text command copied from ChatGPT Android into Termux. Native Grease fetched and executed the maintained batch. The user confirmed success. Exact final terminal-output bytes were not retained, so this record does not invent a process transcript or a byte-bound device receipt.

The external effect was independently verified after the user report: all ten requested repositories were canonical under `isomorphismes`, and every numeric repository ID matched its pre-transfer identity. This gives the observation two distinct evidence classes:

- physical execution: user-confirmed on the known C67;
- live postcondition: independently verified through GitHub state.

Neither class substitutes for the other. A package installation does not prove runtime behavior, and a GitHub state read does not by itself attest which device performed the mutation.

## Runtime lessons for Cat Food

1. A generic Linux architecture label is not sufficient evidence that a binary runs under Android/Termux. The jq bootstrap failure and the successful Android Grease package came through different acquisition lanes.
2. Physical runtime consumers should use declared Android packages, not build toolchains or source fallbacks.
3. Stable command installation and a verified archive are prerequisites, not application-level acceptance.
4. A useful physical runtime test can be a real operational program rather than a synthetic `echo`: this Grease runtime generated, parsed, and executed multiple scripts; handled network/API failures; and drove a verified external state transition.
5. Exact evidence classes must remain visible. This observation is stronger than a local smoke test but weaker than a byte-bound device transcript because final stdout was not retained.
6. The full Cat Food provisioner remains blocked by the jq runtime-probe defect even though the Grease package itself succeeded. Do not convert the successful direct installer into proof that the whole provisioner passed.

The generic transfer policy and live receipt belong to Kitchen and Flexible Pipes. Cat Food retains only the package, target, installation, and physical-runtime facts.
