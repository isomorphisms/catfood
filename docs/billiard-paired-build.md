# Billiard: paired A1 + C67 application

[isomorphisms/billiard](https://github.com/isomorphisms/billiard) is a
DEX-free native interactive mathematical experiment. Its paired ABI requirements
are declared by `ci/android-application.tsv` on its current implementation
branch. The native screen code and verified signed APKs are **not yet built**.

The user's current physical acceptance device is **MIRO C67**, while Cat Food's
maintained A1-primary/C67-paired build policy remains unchanged:

| Target | ABI | Role |
| --- | --- | --- |
| MIRO A1 | `armeabi-v7a` | Primary producer artifact |
| MIRO C67 | `arm64-v8a` | Companion producer + current physical test |

## Producer contract

On a verified Cat Food **host** checkout, after the billiard implementation is
admitted and pinned to an exact commit:

```sh
./catfood plan-android-build /verified/billiard/ci/android-application.tsv phone FULL_BILLIARD_SOURCE_SHA
```

The `/verified/billiard` path is illustrative. Resolve the actual source
workbench location with `./catfood where billiard`; do not assume a phone
checkout or build there. The output plan enumerates the two ABI obligations and
is bound to the Cat Food manifest and source hash. FP/AI-CI separately qualify
producer compilation, package identity, stripped native libraries, stable signer,
package digest, and independently verified screenshots/receipts.

The current inventory records `gap:apk-not-produced` on both ABI lanes. Do not
add package rows until they identify real published artifacts with exact hashes.
Delivery to a phone is **download → verify → install**, not compilation.

## Acceptance sequence

1. Compile/test shared billiard collision core including exact-corner
   reversal and unfolded equivalence (host evidence is not Android evidence).
2. Qualify target-specific ICK stages or record exact ICK capability gaps for
   any NDK stage. Build `armeabi-v7a` and `arm64-v8a` native libraries.
3. Use the registered NativeActivity APK producer, approved signer, and
   artifact verification for **both** ABIs.
4. Emulator/touch/render proof, then C67 physical drag/start/angle/speed
   acceptance. A1 remains a separate physical acceptance obligation.
5. Only then promote the matching Cat Food `packages.tsv` entries and delivery
   references. No package, signer, or physical PASS is inferred here.

Related graphics work: rough.framebuffer PR #1 (alpha/coverage) and its stacked
continuous-dots PR #14. Billiard's mathematical kernel must never depend on
rough stroke perturbations.
