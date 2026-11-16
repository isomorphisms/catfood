# BC-P02-S01 source acquisition

## Contract and language boundary

Values: inventory tool identity, immutable repository commit/tree, workbench or producer operation, three-state submodule policy, committed gitlinks, producer source lock, working source bytes, canonical TSV and digest.

The central operation takes a tool, full commit, absolute destination and operation kind. It either returns a complete canonical source identity or fails with the first acquisition/identity/material error. Source reads and Git/network/filesystem acquisition are effects; canonical record construction is a deterministic projection. A source identity is not a compiler, package, deployment or device acceptance value.

Invariant: repository and commit match; ordinary ICK workbench leaves GCC unfetched; producer references match their gitlinks and source lock; tracked raw bytes match committed blobs; repeated or relocated equal material gives equal records. Missing objects, wrong origins/locks, partial/sparse/hidden-index source and unsupported declarations fail before a producer can be invoked. This operation never invokes a producer.

This is the existing pre-toolchain stage-zero shell boundary, declared in `ci/shell-boundary.tsv`. It must acquire source before an Idriç compiler or Grease closure can be assumed. The implementation is therefore a dependency-free extension to the existing Cat Food entrypoint, not an Idriç program or a claimed Idriç failure. No Python, Bash implementation, compiler substitution or runtime installation was introduced. Existing transition-language workbench code remains named debt.

## Executed evidence — 2026-11-13

Host: disposable x86-64 Debian 13 container, Linux 6.18.57. Cat Food base: `be3a622cc646460af192eea93af14763e69d756f`.

The committed `ci/source-closure.sh` is loaded by `catfood acquire`; the new real-Git corpus runs with its declared stage-zero interpreter: `sh tests/source-closure.sh`. It passes skip/repeat/relocation, nested reference acquisition, custom-update suppression and targeted refusal controls, including a clean-index CRLF counterexample that initially exposed Git normalization masking different raw bytes. Source/origin and lock checks use actual Git operations; fixture network transport alone is mapped to local repositories.

Nearby declared checks also pass: `sh tests/check-manifest.sh`, `sh tests/repository-identities.sh`, `sh tests/entrypoint.sh`, `sh tests/ib-handoff.sh` (14 cases), and `sh tests/android-delivery.sh`. Changed shell syntax and diff whitespace checks pass. These are source/host fixture observations, not qualified Grease execution.

Actual public acquisition used ICK `8a7aac0e42bc8af4550577bbc87e2a5a15eb9db7`, tree `3934d1cd578a8b4b87d588b8bdb63a9a826a517f`. The workbench operation left `gcc/.git` absent. Producer acquisition obtained GCC `6294f1d9e7536e5ffcde09d1528c918d63abfef5`; raw verification covered its 161,666 tracked entries. The two canonical output records are retained in `evidence/`. They contain no host paths or times. GitHub repository metadata independently resolved ICK repository ID `1335084720` to `isomorphisms/ick`; the former address is retained in the shared alias table.

An initial network attempt with a fully cleared environment could not resolve GitHub through this host's required proxy. The source-only Git environment now preserves explicit standard proxy variables while clearing inherited Git configuration. No failed attempt is counted as successful acquisition.

## Remaining boundaries

The stage-zero workflow invokes the focused corpus on the exact PR head. Hosted execution, independent AICI closure acceptance and downstream use in BC-P02-S04/S05 and BC-A06 need their own matching receipts. Qualified compiler witnessing and eligible C++-free Grease remain separate gates. No materializer, compiler build, installation, service activation or physical device operation was run by this source-acquisition change.

For a future Idriç implementation, the first necessary boundary is the same pre-toolchain acquisition interface: an already obtainable qualified runtime with Git process execution, exact raw-file/symlink reads and atomic failure reporting. This note does not claim that boundary exists or that replacing stage zero is part of this job.
