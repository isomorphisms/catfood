# Cat Food — phone branch

This branch is the storage-bounded Cat Food profile for the physical Android phone.

It is intentionally different from `main`: the phone is an acceptance machine, not a general compiler host. This branch does not run the Debian/Ubuntu provisioner and does not install Clang, a JDK, Android SDK/NDK, Gradle, GNU Make, or an unfinished Idriç native backend merely because a command is absent.

The intended small phone set is existing Termux basics plus prebuilt Ike, Grease, and ICU artifacts. Direct DEX plus JNI is the selected Android application path. Experimental ARM/Thumb work remains separate compiler research.

## First checkout

```sh
mkdir -p ~/opt
cd ~/opt
git clone --depth 1 --branch phone https://github.com/isomorphisms/catfood.git catfood
cd catfood
sh phone/build.sh
```

The build script never invokes a package manager. It installs only exact artifacts whose URL and SHA-256 are present in `phone/tools.tsv`; `PENDING` artifacts are skipped rather than causing a source toolchain to be installed.

For the manifest, update path, device doctor, receipt layout, and environment overrides, see [`phone/README.md`](phone/README.md).
