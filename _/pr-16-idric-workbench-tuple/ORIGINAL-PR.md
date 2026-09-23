# Original pull request

- Repository: `isomorphisms/catfood`
- Pull request: #16 — Build and verify the Idriç workbench tuple
- Opened: 2026-08-26
- Historical base: `main` at `c45991431a3e67fda3018ae1777b117ed7ed5431`
- Historical head: `core-release-freshness` at `43922a89bca81d80b13fbe7b4043330000409edf`
- Historical size: 11 changed files, +476 / -17
- State immediately before archival: open, non-draft, non-mergeable

## Original description

### Summary

- build ICU and IB alongside the existing Idriç, Fieldmouse, and Ithon builds
- key downstream stamps to the exact Idriç commit and write an exact core-build receipt
- check checkout and GitHub release freshness for Idriç, ICU, Ithon, Fieldmouse, and IB on every provision/update
- treat absent releases explicitly as `unreleased`, while failing stale checkouts, stale releases, missing tags, and inconclusive queries
- correct IB's manifest entry to initialize its real PDF-harvester submodule
- expose stable `idris2`, `icu`, `fieldmouse`, `ib-arxiv-prepaint`, and `catfood-check-releases` commands with Idriç's pinned Chez runtime available

### Verification recorded by the PR

- POSIX syntax checks passed under `dash`
- manifest failure fixtures passed
- release fixtures covered current, stale checkout, release-behind, unreleased, and failed-query states
- live freshness checking resolved all five configured branch heads and recorded each repository as `unreleased`
- fresh Ubuntu provisioning passed at exact head `43922a89bca81d80b13fbe7b4043330000409edf`
- that run built Idriç, ICU, Fieldmouse, IB, Ithon, and IR; wrote the core-build receipt; and completed both the doctor and stable-command verification

### Diagnosed failure

The first full run reached ICU after a successful Idriç bootstrap, then its generated Chez launcher could not find `scheme`. The correction exported Idriç's checked/pinned `.tools/bin` runtime for every downstream build/run and embedded that path in stable wrappers.

### Boundary

Cat Food was not to promote a newer compiler or backend merely because it existed. It built the moving workbench tuple and recorded exact SHAs; ai-ci remained responsible for broader compatibility state.

## Discussion

No top-level comments or inline review threads were present when this archive was made.
