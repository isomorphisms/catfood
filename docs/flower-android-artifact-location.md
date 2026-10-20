# Flower test APK: Cat Food status and artifact location (2026-10-17)

Origin: https://github.com/isomorphisms/flexible-pipes/issues/124
Physical acceptance: https://github.com/isomorphisms/flexible-pipes/issues/125
Flower implementation: https://github.com/isomorphismes/flower/pull/6
Paired C67 build: https://github.com/isomorphismes/flower/pull/7

## Correct fact: no published Cat Food package

Flower was missing from the current Cat Food tools/delivery inventory. This
draft records it as an A1-primary/C67-paired Android runtime with the explicit
gap `apk-publication-missing` in both lanes. It does NOT create a fictional
`android/packages.tsv` row for a GitHub Actions artifact whose URL may require
GitHub authentication and whose retention is limited.

Exact already-built **test-only** candidates, not Cat Food-delivered packages:

- A1 ARMv7 source `25fa730858901665b686c578a09e514ead16400c`;
  APK SHA-256 `7256bb53f40392ca35ef5ccf83cf040a633f70c6a97c27cdf303ea3969085a7d`.
  Build: https://github.com/isomorphismes/flower/actions/runs/39039780230
- C67 AArch64 source `ce697a31edb67e4bbd2843dde824f1779ad05414`;
  APK SHA-256 `14ac3dcc7547075b961436471b249a4354d7603f68c6404c5add2c0898a69bab`.
  Build: https://github.com/isomorphismes/flower/actions/runs/39076708936
- Both used the same development test signer certificate SHA-256
  `0cdc0345351b88296870f277a7a7ae1709f7fbc41603a97a8ad71d5931215543`.
  This is neither a production signer nor physical-device verification.

The exact source-qualified native geometry is separate:
https://github.com/isomorphisms/ai-ci/pull/279. Its independent host ICK/Ike
oracle and mutation controls passed. Neither A1 nor C67 has an observed
physical install, launch, GPU/touch/latency result, or device-instance receipt.

## Where Cat Food looks

- The normal Android runtime workspace is `${CATFOOD_ROOT:-$HOME/opt}`.
- **Managed downloads** are stored at
  `${CATFOOD_ROOT:-$HOME/opt}/downloads/$package-$sha256`, after Cat Food
  obtains a published package URL and validates the exact digest.
- `catfood where TOOL` locates **verified Git checkouts** by origin, not
  arbitrary APK files and not files held privately by the ChatGPT app.
- A ChatGPT Android download or attachment link is NOT evidence that its
  bytes exist under Android Downloads, `~/storage/downloads`, Cat Food
  `~/opt/downloads`, or a specific physical SD card. If a private content URI
  is used, the user must select/export the file using Android's actual file
  picker or an explicit supported materialization step.
- Cat Food currently cannot state the path where the attached Flower APK
  landed on the current physical A1/C67. A fabricated path would be worse
  than a bounded refusal.

## Consequence for command handoff

Kitchen previously generated a Flower installer-intent script which searched
some conventional Downloads paths, found 0 matches, and reported it. That
failure is not evidence that the user's APK is corrupt. Because Flower was
unpublished, **Cat Food could not have acquired it** through normal package
delivery. A repaired Kitchen handoff must:

1. Check the Cat Food managed-download area first, without assuming contents.
2. Check an explicitly supplied readable path if the user knows one.
3. Offer Android's system-document chooser via `termux-storage-get` if the
   Termux:API integration actually exists. Import the chosen bytes into the
   Cat Food managed-download area only after the exact SHA-256 matches.
4. Use `termux-open` only to request the package-installer UI. A requested
   intent is never a PASS installation/launch/device receipt.
5. Block if the APK is not materialized, if only a nonlocal content URI exists
   without supported access, or if multiple distinct candidates remain.
6. Avoid treating this manual *test APK intake* as Cat Food's future durable
   published `packages.tsv` mechanism. A proper release still needs stripped
   native artifacts, stable package URLs, ICK-vs-NDK stage gap accounting,
   signer and independent acceptance records.

No files on a physical phone were inspected while writing this record.
