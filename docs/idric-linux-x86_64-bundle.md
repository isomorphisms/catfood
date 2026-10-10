# Pinned Idriç compiler bundle for Linux x86_64 — Earth 4A

Producer: [`.github/workflows/idric-linux-x86_64-bundle.yml`](../.github/workflows/idric-linux-x86_64-bundle.yml).

- **Compiler**: `isomorphisms/Idric@94dfd99bd3e376507fedc8611053b7173b2519f0`, not stock Idris 2 or a moving branch.
- **Host ABI**: Linux x86_64, produced on Ubuntu 24.04. No ARM, Android or other-host qualification is implied.
- **Compiler runtime**: bundled threaded Chez Scheme 10.4.1, source-owned compiler program, six matching TTC library trees (prelude, base, linear, network, contrib, test) and the corresponding support files/C library.
- **External host requirements**: working standard Linux shared libraries and a C toolchain to compile programs emitted by Idriç. These are not an Idriç bootstrap or a source checkout. Native ELF and `ldd` observations are included in the archive.
- **Consumer pin**: `dilapidated-shed/intervals.idr@5590933a1c6668643e8911dfb1260b0ce8c2ee00`.

The `package` CI job builds from the exact compiler source and uploads `idric-linux-x86_64-94dfd99bd3e376507fedc8611053b7173b2519f0.tar.gz` plus its SHA-256 file as **candidate GitHub Actions artifacts**, retained for 14 days. It does not publish a release, edit Cat Food's published binary manifest or claim physical-device acceptance.

The separate `fresh-host-intervals` job starts on a new Ubuntu 24.04 runner, downloads only that archive, checks its SHA-256 and internal payload checksums, and installs it to a separate path. It does **not** check out Idriç, restore the cached compiler, or run a compiler bootstrap. It checks the bundled compiler and threaded Chez, then builds and executes both Intervals packages:

```text
idric --build intervals-idric-core.ipkg
idric-env ./build/exec/interval-idric-core-tests
idric --build intervals-idric.ipkg
idric-env ./build/exec/interval-idric-tests
```

An extracted bundle exposes `bin/idric`, `bin/idris2`, `bin/idric-env` and `bin/scheme`. The Idriç commands set matching `IDRIS2_PATH`, `IDRIS2_DATA`, `IDRIS2_LIBS`, Chez boot-file location and runtime search paths relative to the installed archive, without relying on a copied source tree or the producer's absolute workspace paths. Use `idric-env PROGRAM [ARGS...]` when executing programs compiled by this bundled compiler.

**Acceptance rule**: only a successful `fresh-host-intervals` CI job (and its exact run and archive identity) demonstrates a fresh-host Intervals consumer. The previous passing Intervals run `38058689603` restored an existing compiler cache; that is a different kind of evidence. An artifact upload alone, shell syntax check, or local test does not establish fresh-host compatibility.
