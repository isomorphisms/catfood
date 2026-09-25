# Android APK shelves

This directory collects installable APKs for the two maintained physical Android targets:

- `miro-a1/`: MIRO A1, 32-bit ARMv7 / `armeabi-v7a`;
- `tab-p10-row/`: SVITOO TAB_P10_ROW, AArch64 / `arm64-v8a`.

`collect.sh` scans the repositories classified as Android `runtime` entries in `android/delivery.tsv`, resolves their GitHub repository URLs from `tools.tsv`, and inspects the newest GitHub release in each repository that contains APK assets. The separately bootstrapped Grease repository is included too.

For every APK in that release, the collector downloads the upstream asset unchanged and inspects the ZIP members under `lib/`:

- no native libraries: copy to both shelves;
- `lib/armeabi-v7a/`: copy to the MIRO A1 shelf;
- `lib/arm64-v8a/`: copy to the TAB_P10_ROW shelf;
- an APK containing both ABIs is copied to both;
- APKs containing only other native ABIs are not copied.

Files are named `OWNER-REPOSITORY--UPSTREAM-ASSET.apk` so identical generic asset names from different repositories do not collide. Each shelf contains a `manifest.tsv` with the source repository, release tag, upstream asset name, SHA-256, byte size, observed native ABIs, and original release URL.

This is an artifact shelf, not Android delivery or acceptance evidence. Presence here does not change `android/packages.tsv`, does not close a `gap:android-package-missing` row, and does not claim installation, launch, runtime behavior, emulator execution, or physical-device acceptance.

Refresh from a host with `curl`, `jq`, `unzip`, and `sha256sum`:

```sh
sh android/apks/collect.sh
```

The collector fails instead of replacing the shelves with a partial result when a runtime repository cannot be queried or an APK cannot be downloaded or opened.
