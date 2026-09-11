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

Keep the Cat Food checkout outside the runtime tree. For example:

```sh
mkdir -p "$HOME/.cache"
git clone --depth 1 https://github.com/isomorphisms/catfood.git "$HOME/.cache/catfood"
cd "$HOME/.cache/catfood"
./catfood
```

The phone runtime defaults to one flat `~/opt` tree:

```text
~/opt/
├── bin/
├── downloads/
├── receipts/
└── tools/
```

There is deliberately no `~/opt/phone` directory. Installed artifacts live under `~/opt/tools/<name>`, their receipts under `~/opt/receipts`, temporary downloads under `~/opt/downloads`, and stable commands under `~/opt/bin`.

Override the runtime root with `CATFOOD_PHONE_ROOT` or `CATFOOD_ROOT`. `CATFOOD_PHONE_PREFIX` remains available only when an explicitly separate artifact-state root is wanted; it is not used by default. `CATFOOD_PHONE_BIN` can override the stable-command directory.

## Receipts

Each installed artifact records its command, source, ref, ABI, URL, and SHA-256 under `~/opt/receipts`. `phone/doctor.sh` checks those fields against the current manifest before accepting the command, then runs the artifact-specific executable smoke where one exists.
