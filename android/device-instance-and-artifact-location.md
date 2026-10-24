# Physical Android identity and artifact-location evidence

A device model and a downloaded-file event are not sufficient evidence for a
specific physical handset or filesystem path.

## Physical handset identity

A model label such as `MIRO A1` describes a device class, not one physical
unit. More than one handset of the same model may be in use, damaged, clean,
rooted, unrooted, or otherwise in different states.

For physical acceptance, diagnostics, installation, and device-specific
instructions:

- do not infer which physical handset is active from the model name alone;
- retain an explicit per-device identity when available, for example a
  user-assigned alias plus observed serial/fingerprint or other
  non-ambiguous receipt data;
- when the physical instance is not established, say that it is unresolved
  rather than selecting one from history;
- do not project a failure observed on one same-model handset onto another.

A device profile may still own facts common to the model/runtime class. A
physical-acceptance receipt must bind observations to the actual instance used.

## Download and file-location evidence

“Downloaded on Android” is not a filesystem-path claim.

The producing app may expose a file through:

- a content URI;
- app-private/cache storage;
- the Android Downloads provider;
- emulated shared storage;
- another user-selected document location;
- a filesystem path explicitly observed in the current session.

Never convert a generic download event into a guessed path such as
`/sdcard/Download/<name>`.

In particular, Android's conventional `/sdcard` path commonly names emulated
shared storage. Its spelling is not evidence that a removable SD card is
present or that a file was written to one.

A shell-side install or inspection step must therefore consume one of:

1. an explicit observed filesystem path;
2. an explicit URI plus a supported materialization/copy step; or
3. a discovery result produced on the current device.

If none is known, the location is unresolved. Do not issue a path-specific
command and then interpret its failure as evidence about the artifact.

### 2026-10-24: MIRO C67 ChordReader APK path and SELinux incident

User-reported source location on this C67: Termux
`~/storage/downloads/chordreader-arm64-v8a.apk`. The user also created
`~/downloads -> storage/downloads` **inside Termux**. Do not rename this
location "external SD" or treat that symlink as present in the Android shell.

Two different install attempts failed for different reasons:

1. `rish -c 'pm install -r ~/downloads/chordreader-arm64-v8a.apk'`
   resolved the path as `//downloads/chordreader-arm64-v8a.apk`: the
   Shizuku-provided shell does **not** expand `~` to Termux's home.
2. `rish -c 'pm install -r /sdcard/Download/chordreader-arm64-v8a.apk'`
   reached Android's package-manager shell command but failed with
   `avc: denied { read }`: `system_server` was forbidden to read the
   shared-storage `fuse` file directly. This is a file-access/SELinux
   failure, not evidence of an invalid APK or wrong signing certificate.

Candidate repair, **not yet executed/accepted on the physical C67**:
use the Shizuku shell to stage the APK from Android's shared Downloads
into `/data/local/tmp`, make it readable, then give that staged path to
the package manager:

```sh
rish -c 'cp /sdcard/Download/chordreader-arm64-v8a.apk /data/local/tmp/ && chmod 644 /data/local/tmp/chordreader-arm64-v8a.apk && pm install -r /data/local/tmp/chordreader-arm64-v8a.apk'
```

The reported Termux path is device-specific; the corresponding
`/sdcard/Download` Android-shell path should be checked on-device if
the copy fails, rather than inferred to be universally valid. **Follow-up user report (2026-10-24):** the exact proposed
`rish -c 'cp ... /data/local/tmp/ && chmod 644 ... && pm install -r ...'`
command succeeded on the user's physical MIRO C67, and the ChordReader
development program launches and shows its UI. Record this as **user-reported
physical installation PASS and launch PASS** for the C67 candidate, not
independent collection of device receipts or verified on-device APK digest.
Search behavior was also exercised: the program hands its search to an
external browser (reported DDG), not IB/ICU. This is a product integration
requirement, not an APK installation failure. The handset's unique instance
identifier, signer/installed-byte readback, and full feature/runtime acceptance
remain **NOT_VERIFIED**. Never upgrade these reports to broader acceptance.

## Acceptance boundary

Build/package success and physical installation remain separate evidence.
Before diagnosing an install failure, bind all of:

- exact artifact identity/digest;
- exact physical handset instance;
- exact way the artifact reached that handset;
- exact install mechanism and its returned failure text/code.

This rule was reinforced by a 2026-10-06 Spinor sideload diagnostic where an
assistant knew only the model class and then incorrectly assumed both a
particular same-model handset and `/sdcard/Download`.
