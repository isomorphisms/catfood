# CF-T1 target/device/package audit

Base: `62ac940588f5ee4c5be468d48e38d74514da3757`.
Reuses isomorphisms/catfood PR #115, “Reconcile current Android delivery and
retire old generations” (https://github.com/isomorphisms/catfood/pull/115),
original head `fe7d665cb98ce28f2267859e081ac2eeeb7a9d7b`.
Reconciles isomorphisms/catfood PR #125, “Record A1 and C67 conversation runtime
build targets” (https://github.com/isomorphisms/catfood/pull/125), original head
`7427a776a1fa689a6764478b572e270496768711`.

The implementation adopts the mapping in [TARGETS.md](../TARGETS.md). It keeps
existing published artifact IDs/digests and the valid generation-consolidation
work. Only immutable package wire metadata retains historical lane labels.

| Actual finding | Source / regression | Disposition |
| --- | --- | --- |
| Architecture identified every ARMv7 machine as A1 and every non-C67 ARM64 machine as tablet. | `android/target.sh`, `catfood`, `provision.sh`; `tests/targets.sh` | Product/model identify profiles; unknown devices remain generic; conflicts fail. |
| C67 product OR model allowed conflicting fields; other overrides were unchecked. | `android/target.sh`; `tests/targets.sh` | Shared consistency oracle validates all known profiles and overrides. Installation needs observed ABI and identity. |
| Package columns and receipt target meant a form factor in one place and ABI elsewhere. | `android/packages.tsv`, `delivery.tsv`, `install.sh`, `check.sh` | ABI-named lanes; v2 receipts require target, class, instance, observed properties and artifact identity separately. |
| Sharing ARM64 admitted a Mali-G57-specific test onto C67 PowerVR. | `powervr-runner-tablet`; exact producer `f3ed48fc.../tools/accept_powervr_android.sh` | Evidenced restriction in `android/package-restrictions.tsv`; C67 gets a visible gap, not the wrong runner. |
| Optional device identity and no expected target/instance check allowed cross-device receipt reuse. | `android/check.sh`, `install.sh`; `tests/c67-delivery.sh` | Required v2 identity; installer validates target+instance for reuse/dependencies. Identical archive tests retain separate C67/TAB_P10 records; copied and relabeled records fail. |
| Inventory treated unvalidated `installation_result=PASS` as current; its C67 test copied an A1 receipt. | `device-state.sh`, `tests/device-state.sh` | Malformed/wrong-target receipts remain unconfirmed observations. The copied receipt is retained as a negative fixture. |
| Old physical bundles and installed Reddit acceptance checked only ABI. | `android/acceptance/run.sh`, `run-v2.sh`, `reddit-installed.sh`, `build-bundles.sh` | Shared identity preflight before execution, per-instance binding, helper and policy files included in bundles. |
| Non-Termux meant cloud; unknown Termux meant a source workbench. | `android/target.sh`, `provision.sh`, `tests/entrypoint.sh` | Positive Debian/Ubuntu Linux host evidence; Android cannot be forced into host provisioning; generic Termux refuses mutation. |
| C67 native probe trusted a version string plus a platform receipt without rehashing the command. | `android/record-c67-runtime.sh`; `tests/targets.sh` | Rehash the exact declared jq file before execution and record its digest. Changed executable negative control fails. |
| A1+C67 producer matrix lacked a shared application policy check. | `android/conversation-targets.tsv`, `application-targets.tsv`, `check.sh` | Preserve conversation-specific API/NDK fields; enforce shared A1 primary / C67 paired identities and ABIs. No new producer acceptance claimed. |

Other audited distinctions are already sound:

- `catfood where/register`, `ci/repositories.sh` and the repository identity
  fixtures verify Git origin and current path; `tools.tsv` is inventory, not
  proof of a local checkout.
- `android/check.sh` requires separate package, publication, installation,
  launch, runtime, emulator and physical-device result/evidence pairs. The
  installer leaves unexecuted stages `NOT_VERIFIED`; stage-promotion negatives
  remain in `tests/android-delivery.sh`.
- C67 profile records GLES 3.2 and API 34 as capability observations, not
  application minimum requirements. The conversation program's API 21 floor
  remains program-specific.
- Device notes separate A1 storage/Shizuku, C67 private rish placement and
  TAB_P10's deferred ADB/removable-storage state. `preserve-shizuku.sh` probes
  actual local bundles rather than asserting the A1 path exists elsewhere;
  preservation is not Shizuku runtime acceptance.

Active work inspected: the RHS host profile and compact-runtime inventory stay
on their existing branches. The positive host-detection rule from
isomorphisms/catfood PR #116, “Refuse NetBSD cloud assumptions and record mailbox
host evidence” (https://github.com/isomorphisms/catfood/pull/116) is incorporated
in the shared detector; its mailbox implementation is not merged. Its branch
will need reconciliation around the shared detector before integration.

Verification is synthetic host execution except for downloading, rehashing and
installing the exact published Reddit archives under a launch sentinel. It
does not establish fresh Android, Shizuku, GPU or application acceptance.
Negative controls include conflicting identities, unknown ARM32/ARM64 devices,
wrong explicit profiles, cross-device and cross-instance receipts, omitted
identity, relabeling, changed executable bytes and package restrictions.
`tests/target-mutations.sh` deliberately restores unknown-as-tablet selection
and removes the expected-target receipt guard; both are killed for their
intended diagnostics.

Historical v1 receipts are retained, not rewritten or promoted. Fresh v2
installation receipts invalidate old runtime/physical success. Device IDs are
local installation aliases, not hardware attestation; copying state across
handsets is outside their evidence contract. Rechecking physical behavior on
A1, C67 and TAB_P10 and producing a compatible C67 GPU acceptance package remain
real unexecuted obligations.
