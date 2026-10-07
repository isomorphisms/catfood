# Cat Food targets

Cat Food keeps device profile, form factor, artifact ABI, physical instance,
acceptance evidence, and workbench role separate.

| Selector | Device profile | Class | Primary package lane | Role |
| --- | --- | --- | --- | --- |
| `phone` | MIRO A1 | phone | `armeabi-v7a` | Android runtime consumer; primary application target |
| `c67` | MIRO C67 | phone | `arm64-v8a` | Android runtime consumer; paired application target |
| `tablet` | TAB_P10 | tablet | `arm64-v8a` | Independent Android runtime consumer |
| `termux` | unknown | unknown | unassigned | Generic observation only; provisioning refuses |
| `container` | explicitly selected disposable Debian/Ubuntu environment | host | host-specific | Build/workbench |
| `cloud` | Debian/Ubuntu Linux; Hetzner is a concrete instance | host | host-specific | Build/workbench |

`hetzner` remains a selector alias for `cloud`; selecting it does not prove
which host was reached. Architecture alone never identifies an Android model.
The C67's retained native AArch32 compatibility does not accept an A1 artifact
or authorize using A1 storage/Shizuku facts.

## Selection and identity

`./catfood --target` reports the selected profile. `android/target.sh` shares
one identity oracle across selection, installation, inventory and receipt checks.
It reads product/model and primary ABI. Conflicting known fields and a known
model with the wrong ABI fail; unknown identity remains generic. A1 product
tokens are not yet retained, so its exact recognized model supplies positive
identity. C67's retained product and model are checked together when available.

Explicit `CATFOOD_TARGET` overrides remain available. Available observations
must agree. A host with no Android properties can select an Android profile for
planning, but installation requires observed identity and primary ABI. An ABI
override cannot contradict getprop. Known or generic Android consumers cannot
be forced into host provisioning. Automatic cloud selection requires positive
Debian/Ubuntu Linux evidence; container selection remains explicit.

Model identity is not physical-instance identity. Installer and inventory share
a local per-installation `device_id` (or an explicit user alias), scoped to the
device's state directory. Never copy it between handsets. Model properties and
local aliases are consistency checks, not cryptographic attestation.

## Packages and receipts

The two delivery columns and package lanes are named `armeabi-v7a` and
`arm64-v8a`. The package lane and ABI must agree. Published package IDs, URLs,
digests and bytes remain unchanged. Only the adapter for immutable embedded
DEX/JNI metadata retains historical `phone`/`tablet` wire labels.

ABI compatibility alone cannot establish every application's requirements.
`android/package-restrictions.tsv` records evidenced device restrictions.
The current ARM64 GPU acceptance archive explicitly requires Mali-G57 and is
therefore restricted to TAB_P10. C67 exposes a package gap rather than
installing that incompatible acceptance runner.

New `catfood-android-evidence-v2` receipts require the physical target,
device class, device instance, observed product/model/fingerprint, ABI lane,
exact artifact identity, and every separate evidence stage. Version 1 is
historical evidence and cannot be silently reused as current acceptance.
Installation regenerates its receipt without promoting launch/runtime/device
results. Validation can bind to an expected target and instance:

`sh android/check.sh receipt RECEIPT TARGET DEVICE_ID`

C67 and tablet may consume identical compatible ARM64 bytes, but retain separate
receipt names and identities. Installation, launch, runtime, emulator and
physical-device PASS remain separate claims. Receipt validation checks schema
and consistency; it does not attest that a claimed physical run happened.

## Producer policy

`android/application-targets.tsv` is the maintained application policy: normally
produce both A1 and C67 artifacts; when only one can be completed, A1 is primary.
`android/conversation-targets.tsv` retains the conversation runtime's API/NDK
details and is checked against that policy. Its API 21 floor is program-specific,
not a requirement inferred from either phone's observed Android release.
Flexible Pipes owns execution of paired producer jobs. This matrix is not a
publication receipt or physical acceptance.
