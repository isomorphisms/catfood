# Cat Food for the physical Android phone

The phone is a small runtime target, not a source workbench.

The ordinary `./catfood` entrypoint detects the 32-bit ARMv7 Termux phone and hands directly to `phone/build.sh`. The phone path does not feed the repository manifest, clone project source trees, build compilers, or install a compiler toolchain.

The intended phone set is deliberately small:

- existing Termux system commands needed to fetch and verify artifacts;
- exact prebuilt ARM binaries listed in `phone/tools.tsv`;
- stable command wrappers under `~/opt/bin`.

An unavailable artifact is `PENDING` and skipped. Missing prebuilt output never causes a source build on the phone.

The first phone target is the current 32-bit `armeabi-v7a` device. Direct DEX plus JNI remains the selected Android application path. Experimental ARM/Thumb compiler work may still be exercised deliberately as compiler research, but it is not a Cat Food phone dependency.

## Run

From the Cat Food checkout:

```sh
./catfood
```

The defaults are:

```text
workspace       ~/opt
artifact prefix ~/opt/phone
stable commands ~/opt/bin
```

Override them with `CATFOOD_PHONE_ROOT`, `CATFOOD_PHONE_PREFIX`, or `CATFOOD_PHONE_BIN`.

## Receipts

Each installed artifact records source, ref, ABI, URL, and SHA-256 under `~/opt/phone/receipts`. `phone/doctor.sh` reports the Android ABI, build fingerprint, emulator flag, storage, system prerequisites, installed artifacts, and still-pending artifacts.
