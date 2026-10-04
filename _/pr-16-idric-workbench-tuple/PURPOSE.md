# Purpose

PR #16 tried to turn Cat Food's host-side source environment into an explicitly verified **Idriç workbench tuple** rather than a loose collection of repositories.

Its goals were:

1. Build ICU and IB alongside Idriç, Fieldmouse, Ithon, and IR.
2. Bind downstream builds to the exact Idriç revision that produced or ran them.
3. Emit a machine-readable `core-build.tsv` receipt naming project revisions, compiler revision, backend, tree state, and result.
4. Check whether selected source checkouts were exactly at their configured remote branch heads.
5. Compare those heads with GitHub release tags, distinguishing a genuinely unreleased project from a stale or inconclusive release state.
6. Emit a `release-status.tsv` receipt rather than leaving freshness as an implicit assumption.
7. Initialize IB recursively so its PDF-harvester dependency was actually present.
8. Expose stable commands for the built programs.
9. Make the Idriç-pinned Chez runtime available when invoking Idriç-generated programs, rather than accidentally succeeding only on machines with an unrelated system `scheme`.
10. Keep Cat Food responsible for constructing and recording the moving source/build environment while leaving broader fleet compatibility judgments to ai-ci.

The implementation was deliberately fail-closed for stale checkouts, stale releases, missing tags, and failed or inconclusive release queries, while treating a repository with no GitHub release as explicitly `unreleased`.
