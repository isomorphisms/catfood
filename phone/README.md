# Cat Food for the physical Android phone

This profile keeps the phone small and makes the physical device an acceptance target rather than a general-purpose compiler host.

It does not run the normal server/workstation `provision.sh`. It does not install Clang, a JDK, an Android SDK/NDK, Gradle, GNU Make, or an unfinished Idriç machine-code backend merely because a tool is missing.

The intended phone set is deliberately small:

- existing Termux system tools such as `git`, `curl`, `tar`, `sha256sum`, and `unzip`;
- Ike as the small dependency build tool;
- Grease as the working shell;
- ICU as the network acquisition command.

Ike, Grease, and ICU are installed from exact prebuilt Android/ARM artifacts only after their URL and SHA-256 are entered in `tools.tsv`. A `PENDING` artifact is reported and skipped. Absence of a prebuilt artifact never causes a source compiler toolchain to be installed on the phone.

The first phone target is the current 32-bit `armeabi-v7a` device. Direct DEX plus JNI is the selected Android application path. Experimental ARM/Thumb compiler work remains separate and may still be exercised deliberately on the phone as compiler research, but it is not an application or Cat Food dependency.

## First checkout

```sh
mkdir -p ~/opt
cd ~/opt
git clone --depth 1 --branch phone https://github.com/isomorphisms/catfood.git catfood
cd catfood
sh phone/build.sh
```

`phone/build.sh` never invokes `pkg`, `apt`, or another package manager. It verifies the small system-tool boundary, installs only exact manifest artifacts that are available for the phone ABI, exposes stable wrappers under `~/opt/bin`, and runs `phone/doctor.sh`.

## Update

```sh
cd ~/opt/catfood
sh phone/update.sh
```

The update is fast-forward only and then runs the same `phone/build.sh`.

## Environment

The defaults are:

```text
workspace       ~/opt
artifact prefix ~/opt/phone
stable commands ~/opt/bin
```

Override them with `CATFOOD_PHONE_ROOT`, `CATFOOD_PHONE_PREFIX`, or `CATFOOD_PHONE_BIN`.

## Receipts

Each installed artifact records source, ref, ABI, URL, and SHA-256 under `~/opt/phone/receipts`. `phone/doctor.sh` also reports the physical Android ABI, build fingerprint, emulator flag, storage, system prerequisites, installed artifacts, and still-pending artifacts.
