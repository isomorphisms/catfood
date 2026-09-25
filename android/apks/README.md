# Android APK shelves

This directory is the installable-app shelf for a fresh Android device.

- `general-dex/`: architecture-neutral APKs with no native `lib/` payload; these are ordinary DEX/ART APKs and belong on either device.
- `miro-a1/`: APKs containing `armeabi-v7a` native code for the MIRO A1 / 32-bit ARM phone.
- `tab-p10-row/`: APKs containing `arm64-v8a` native code for the SVITOO TAB_P10_ROW / AArch64 tablet.

The point is that a new device should not require remembering where each app came from. Cat Food's normal `./catfood` path delivers command-line/runtime packages; `./catfood apks` stages every installable APK for the detected Android target into one folder. Thus the fresh-device pair is:

```sh
./catfood
./catfood apks
```

On Android, `./catfood apks` uses shared Downloads when that path already exists and is writable; otherwise it stages under the Cat Food checkout. An explicit target and destination are also accepted:

```sh
./catfood apks phone /path/to/folder
./catfood apks tablet /path/to/folder
```

`collect.sh` scans repositories classified as Android `runtime` entries in `android/delivery.tsv`, resolves their GitHub URLs from `tools.tsv`, and inspects the newest GitHub release in each repository that contains APK assets. The separately bootstrapped Grease repository is included too.

For every release APK, the collector downloads the upstream asset unchanged and inspects ZIP members under `lib/`:

- no native libraries: keep it once in `general-dex/`;
- `lib/armeabi-v7a/`: keep it in `miro-a1/`;
- `lib/arm64-v8a/`: keep it in `tab-p10-row/`;
- an APK containing both ABIs is present in both device shelves;
- APKs containing only other native ABIs are not retained.

Some useful APKs exist only as CI artifacts rather than durable GitHub releases. Those are pinned explicitly in `pinned-general.tsv`; the checked-in APK remains durable even after the original CI artifact expires. The collector verifies and preserves every pinned entry rather than silently dropping it.

Files are named `OWNER-REPOSITORY--UPSTREAM-ASSET.apk` so generic upstream names do not collide. Each shelf has a `manifest.tsv` with source kind/ref, upstream asset, checked-in filename, SHA-256, byte size, observed native ABIs, and source URL.

This is an artifact shelf, not Android acceptance evidence. Presence here does not change `android/packages.tsv`, does not close a `gap:android-package-missing` row, and does not claim installation, launch, runtime behavior, emulator execution, or physical-device acceptance.

Refresh release-backed entries from a host with `curl`, `jq`, `unzip`, and `sha256sum`:

```sh
sh android/apks/collect.sh
```

The collector fails instead of replacing the shelves with a partial result when a runtime repository cannot be queried, an APK cannot be downloaded/opened, or a pinned APK no longer matches its recorded digest.
