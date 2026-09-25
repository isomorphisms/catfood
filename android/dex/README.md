# Android DEX shelf

This directory contains actual DEX bytecode files.

It is deliberately separate from `android/apks/`: an APK is a ZIP-packaged Android application even when it contains no native libraries, while a file in this directory must itself have DEX magic (`dex\n`).

The reusable `isomorphisms/ai-ci/release-shelf` collector accepts two DEX sources:

- standalone `.dex` GitHub release assets;
- `.dex` members extracted from release ZIP/TAR archives of repositories explicitly listed in `android/dex-archive-repositories.txt`.

The collector verifies the four-byte DEX magic before retaining a file. `manifest.tsv` records the source repository, source kind/ref, release asset, archive member when applicable, checked-in filename, SHA-256, byte count, and source URL.

Cat Food currently names the direct Android DEX producer explicitly because it is a packaging producer rather than a normal workbench entry.

As with the APK shelves, presence here proves retained artifact identity only. It does not prove ART loading, JNI linkage, execution, emulator behavior, or physical-device behavior.
