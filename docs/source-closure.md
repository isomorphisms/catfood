# Exact source acquisition

BC-P02-S01 belongs to [Cat Food issue 95](https://github.com/isomorphisms/catfood/issues/95), with independent closure acceptance in [ai-ci issue 149](https://github.com/isomorphisms/ai-ci/issues/149).

`catfood acquire TOOL COMMIT ABSOLUTE_DESTINATION workbench|producer` uses the current inventory to resolve the repository and submodule policy. It requires explicit `CATFOOD_TARGET=container`, `cloud` or `hetzner`, and verifies the host workbench boundary before filesystem effects. Phone, C67 and tablet source acquisition is rejected. There is no implicit fleet bootstrap, runtime installation or producer invocation.

The commit must be a full lowercase SHA-1. A fresh destination fetches that exact object and checks it out detached. An existing destination must already have the same origin and commit and complete unchanged source; acquisition never moves or deletes unrelated work. Failed first acquisition can leave a partial checkout, which remains failed rather than being silently repaired or accepted.

| Policy | Meaning |
| --- | --- |
| `none` | No submodule declarations or gitlinks are allowed. |
| `skip` | Declarations and gitlinks must agree; references are not fetched. |
| `recursive` | Every declared reference and nested reference must exist at its exact committed gitlink with the declared origin. |

Ordinary ICK workbench acquisition uses `skip`. The `producer` operation changes a declared `skip` into `recursive`; other policies are unchanged. ICK's GCC repository and commit must also agree with `ick/SOURCE.lock` before reference acquisition. The record includes digests of that lock, overlay manifest, prune list and materializer. The producer retains ownership of overlay validation and materialization.

The stage-zero implementation extends the existing dependency-free Cat Food shell boundary. Source acquisition cannot depend on compiling Idriç or obtaining Grease before the source/tool closure exists. This is explicitly declared in `ci/shell-boundary.tsv`; it grants no general shell-language or compiler fallback. The inherited workbench feed and doctor remain transition-language debt.

Git uses a cleared configuration environment, disables hooks and filesystem-monitor commands, and preserves the host's explicit network proxy transport settings. Existing custom submodule update commands are overridden by checkout. Reference URLs are validated one level at a time before each acquisition; this version supports explicit GitHub HTTPS `.git` URLs. Relative and other transports fail with a diagnostic rather than guessing their identity. Initialized child origins are checked before sync changes their configuration. Sparse checkouts and index flags that hide tracked changes are refused. Raw tracked-file and symlink bytes are checked against committed blobs, so clean filters and line-ending normalization cannot hide changed producer input.

A child with no declared submodules or gitlinks is a leaf even when it commits an empty or comment-only `.gitmodules`. Malformed syntax and incomplete declarations remain rejecting; the filename alone does not select recursion.

The stdout record is `catfood-source-v1`: canonical repository, commit, tree, policy, declared/verified recursive gitlinks, ICK material digests where applicable, then SHA-256 of the sorted preceding rows. Destination paths, times, attempt IDs and branch-discovery state are excluded. Every invocation rechecks the source bytes; no saved record grants acceptance. Source and reference changes alter the material identity, which consumers must use to invalidate affected evidence. Equal material under repeat or relocation produces equal record bytes.

`sh tests/source-closure.sh` uses real local Git repositories behind an explicit test-only transport adapter. It covers skip without reference acquisition, nested exact acquisition, empty/comment-only leaf declarations and malformed/incomplete declaration refusals, stable repeats and relocation, custom-update suppression, wrong origins/commits, incomplete and sparse source, hidden index changes, unavailable objects, lock disagreements, duplicate URL values and unsupported nested transport. These are host source-acquisition fixtures, not live producer, compiler, package, deployment or physical-device qualification. The existing stage-zero workflow runs this corpus at the exact PR head.

Independent AICI admission and qualified Grease/ICK execution remain separate. This source record does not authenticate a compiler witness, approve a producer role, qualify a delivered package or make a managed runtime eligible.
