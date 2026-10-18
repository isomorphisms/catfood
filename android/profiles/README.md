# Source-bound Android profiles

Cat Food exposes model facts separately from a physical instance, current
firmware, the ABI package lane, an application's graphics context, and mutable
service readiness. The canonical model IDs are `miro-a1`, `miro-c67`, and
`svitoo-tab-p10`. `aliases.tsv` is the finite alias map; an unknown ARM32 or
AArch64 device is not promoted to a maintained target by its ABI.

Profile definitions use `catfood-android-profile-v2`. Every fact records a
scope (`model`, `instance`, `firmware`, `application-context`, or `session`), a
state (`known`, `historical`, or `unknown`), its materiality, and exact source
bytes when a retained source exists. `required-fields.tsv` selects the facts
and minimum state for each operation. The reader preserves missing, historical,
conflicting, and branch-only outcomes instead of completing them by inference.

The public interface runs only with the qualified clean Ithon checkout and its
exact executable digest:

```text
CATFOOD_ITHON=/absolute/path/to/ithon \
CATFOOD_ITHON_SHA256=EXACT_LOWERCASE_SHA256 \
CATFOOD_ITHON_REVISION=d6e83969f82512e920fb17b44326cb54f31d015c \
./catfood android-profile \
  --model miro-a1 --instance LOCAL_INSTANCE \
  --operation stable-hardware --output PROFILE.tsv
```

The projection schema is `catfood-android-profile-projection-v2`. Its
`profile_material_sha256` covers only the selected canonical facts, their
scopes, state, explicit observation time, and scoped source evidence. Input row
order and an unrelated mutable fact do not change it. A material fact does.
Existing output paths are refused.

`diagnostic-base` requires a current firmware observation.
`diagnostic-app-graphics` additionally requires a current
`application-context` observation; a SurfaceFlinger renderer is deliberately
the wrong scope. `diagnostic-shizuku` requires current session readiness. A
timestamped current observation can be constrained with `--not-before`.
Stable hardware lookup does not require a device probe, and a stopped service
does not erase retained model facts.

Current inventory accepts the emitted `fingerprint` field. The historical
`build_fingerprint` spelling is normalized for old callers; simultaneous
different values are a conflict. Inventory and observation files are supplied
evidence, not physical acquisition or attestation.

## Pre-command diagnostic request

`./catfood android-profile-request prepare ...` is the Kitchen CF-A2-S5-facing
adapter. Before it emits `catfood-android-profile-request-v1`, it:

1. verifies exact AICI requirement projection bytes from PR #285 at
   `cdf6f09dda2828e4d463dab202d66175397dbbd4`;
2. verifies independently supplied approved Android obligations through the
   CF-A2-S2 interface from Cat Food PR #143 current candidate head
   `7f4a3707a63812af1039ad80aea8ad7e86983670`, whose
   `android/obligations.sh` SHA-256 is
   `b079f6326ef018e2dce46105f055cc3a237bbb4df42d85b0e550228adacf976d`;
3. calls the scoped profile reader before command preparation; and
4. retains the whole profile projection SHA-256, scoped material SHA-256,
   selected package obligation SHA-256, and Kitchen source-handoff contract
   revision `ba7f651e89ae25e831613c8c3fee2f15f73baa54` / `source-handoff-v1`.

The approved-obligation file and digest come from an independent approval
source. Candidate generation with `android/obligations.sh build` is only a
consistency check. `android-profile-request verify` requires the retained exact
profile bytes and catches deletion or substitution of that consumer binding.
The request stops at `next_phase=command-preparation`; it does not run a
diagnostic, install a package, or create device acceptance.

After a consumer has its own result, `android-profile-request receipt` emits
`catfood-android-profile-receipt-v1` and repeats both the exact projection and
scoped material digests. `verify-receipt` checks those digests against the
request and profile. The source regression uses `NOT_VERIFIED` with explicit
source-only evidence; it does not manufacture a diagnostic run.

The exact A1/Grease projection copied under `tests/fixtures/android-profile/`
is a regression specimen from the AICI candidate, not local policy authority.
Its SHA-256 is
`a0981c2268ed3ffd4d56d30a429cb1254803dcefb6326e088878355327f8cbe8`.
