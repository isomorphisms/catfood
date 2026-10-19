# Approved Android obligation and package-graph boundary

Cat Food can construct a canonical candidate projection with
`android/obligations.sh build`, but candidate self-consistency is not approval.
Installation requires an externally supplied approved projection and its exact
SHA-256. The projection binds current inventory dispositions, package records,
runtime and package dependencies, device restrictions, and target policy.
Canonical sorting makes equal material stable across attempt time and source-row
ordering.

Each package also receives a binding over its record, transitive package
dependencies, directly exposing delivery rows, applicable restrictions, and
target policy. A receipt records that package binding. Reapproval of unrelated
package material therefore does not invalidate an unaffected package receipt;
changes in a package's own closure do. The full approved file remains available
in the receipt as historical identity, while the exact externally supplied
digest—not a digest computed by the installer—authorizes the current attempt.

Before package management or acquisition, `check.sh` validates duplicate and
conflicting identities, delivery reachability, missing dependencies, cross-lane
edges, and self, two-node, and longer cycles. `install.sh` verifies exact
approved material and revalidates every current installed generation. Missing
approval, changed restrictions or required runtime material, a graph failure,
or changed installed bytes stops the attempt before effects.

The version 4 receipt continues the retained version 3 content seal: it
reconstructs the complete installed tree from the pinned archive, reconstructs
launchers, hashes runtime and package dependencies, binds observed device facts
and firmware, and binds the installation procedure. Old receipts and failed
candidates are retained. Runtime observations remain separate from the
installation receipt and do not authorize physical execution.

## Executed host controls

`tests/android-obligations.sh` exercises the current manifests, including the
real `powervr-runner-tablet` Mali-G57 restriction and the real `az-phone`
runtime requirement. It covers stable row reordering, restriction and runtime
deletion, missing and cross-lane dependencies, self/two/long cycles, shared
ARM64 restrictions, and affected-only package binding changes.

`tests/android-delivery.sh` mutates an installed non-entry archive member and
checks that retry fails before package-manager or acquisition effects while the
changed bytes and installation receipt remain untouched. The fixture is
synthetic; it establishes host-side control behavior, not Android physical
runtime. Positive authorization still requires approved material from its AICI
owner. No release, deployment, activation, merge, or physical-device acceptance
is claimed here.
