# Android APK shelves

These are complete installable-APK shelves for the two maintained physical Android targets.

- `miro-a1/`: every current APK usable on the MIRO A1 phone. APKs with no native `lib/` payload are included here too.
- `tab-p10-row/`: every current APK usable on the SVITOO TAB_P10_ROW tablet. Architecture-neutral APKs are included here too.
- `pinned/`: exact non-release APKs retained by Cat Food, with identities declared in `pinned-apks.tsv`.

Actual standalone DEX bytecode is separate under [`../dex/`](../dex/README.md). An APK that happens to contain only DEX/ART bytecode is still an APK and therefore belongs in both compatible device APK shelves, not in the DEX directory.

The point is that a fresh device should not require remembering where each app came from. Cat Food's normal `./catfood` path delivers command-line/runtime packages; `./catfood apks` stages every checked-in APK for the detected Android target into one folder:

```sh
./catfood
./catfood apks
```

An explicit target and destination are also accepted:

```sh
./catfood apks phone /path/to/folder
./catfood apks tablet /path/to/folder
```

Release-backed APKs are refreshed by the reusable `isomorphisms/ai-ci/release-shelf` action. Cat Food generates the scan population from the complete GitHub repository inventory in `tools.tsv`, adds the separately bootstrapped Grease repository, and asks the shared action to inspect current GitHub releases. The shared collector verifies APK ZIP structure and classifies each APK from its actual `lib/<abi>/` members:

- no native libraries: include it in both device shelves;
- `lib/armeabi-v7a/`: include it in the MIRO A1 shelf;
- `lib/arm64-v8a/`: include it in the TAB_P10_ROW shelf;
- both ABIs: include it in both.

Some useful APKs exist only as CI artifacts rather than durable GitHub releases. Cat Food retains those exact bytes in `pinned/`; `pinned-apks.tsv` records their source revision, SHA-256, byte count, observed ABI set, and evidence URL. The shared collector re-verifies them on every refresh.

The refresh workflow can also be run manually. Its hourly schedule becomes active only when the workflow is on Cat Food's default branch; a schedule present only on this development branch is not operating surveillance.

Each device shelf has a `manifest.tsv` recording repository, source kind/ref, upstream asset name, checked-in filename, SHA-256, byte count, observed native ABIs, and source URL.

This is an artifact shelf, not Android acceptance evidence. Presence here does not change `android/packages.tsv`, does not close a `gap:android-package-missing` row, and does not claim installation, replacement-update signing, launch, runtime behavior, emulator execution, or physical-device acceptance.
