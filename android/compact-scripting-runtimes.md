# Compact scripting runtimes on Android

Cat Food owns delivery and footprint evidence for scripting runtimes used on the maintained
phones. Kitchen may pin source; Flexible Pipes may orchestrate builds and checks. Neither
source presence nor a successful host build is Android delivery evidence.

## Current candidates

- **Field Mouse** remains the active JavaScript scripting runtime line.
- **MuJS** is retained as a compact C reference/fallback for footprint work; its presence
  does not replace Field Mouse or create an Android runtime claim.
- **MicroPython** is a compact Python runtime candidate. The intended owned source is
  `dilapidated-shed/micropython`; until a published Android package exists it remains an
  explicit delivery gap.
- Ordinary Lua remains a Cat Food support runtime under its existing package-manager path.

## Phone constraints

The MIRO A1 is the primary constrained target. Do not solve its storage pressure by cloning
interpreter source or compiler trees onto the phone. Build elsewhere, strip releasable ELF
payloads, publish exact artifacts, then let Cat Food download, verify and install only the
runtime payload.

When a maintained interpreter build is promoted, build the MIRO A1 ARMv7 and MIRO C67
AArch64 variants together where the shared build path supports both. If only one target can
be completed, the A1 is primary.

Do not invent a size threshold before measuring. For each candidate record at least:

1. exact source commit and build commit;
2. target ABI and compiler/linker path;
3. native bytes before stripping;
4. native bytes after stripping;
5. final archive/package bytes;
6. installed runtime bytes including required adjacent payloads/libraries;
7. a semantic smoke result on the target;
8. physical-device evidence separately for A1 and C67.

For MicroPython, do not recursively fetch its large hardware-specific submodule graph unless
the selected build actually requires those submodules. For JavaScript footprint work, compare
the complete delivered Field Mouse runtime (including its support payload/runtime dependency)
against an equivalently functional MuJS build rather than comparing only one executable file.

A smaller interpreter is useful only if the helper-script surface we depend on still works.
Size reduction and semantic reduction must therefore be recorded together.
