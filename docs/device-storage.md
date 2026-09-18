# Device storage ledger

This file records storage and execution facts for concrete physical devices.
It is not a template. Do not transfer a fact from one device to another.

Mutable facts are dated. Re-run the listed checks when a path or mount matters
to the task, especially after media, Android, Termux, or storage changes.

## Rules

- Identify the target first: phone and tablet are separate machines.
- Use `readlink -f` and `df -h` (and mount information when needed) on the
  target before describing a path as internal, shared, removable, or SD.
- `~/storage/downloads` is Android shared Downloads. Its presence does not
  establish an external SD card.
- A missing `~/storage/external-1` means no external-1 mount is currently
  available to Termux; do not invent one from another device's history.
- Shared/removable Android storage may be `noexec`. A successful compile on
  such storage is not proof the resulting ELF can execute there.
- Repository/check-out paths remain discoverable through Cat Food; do not infer
  them merely from the storage table below.

## Phone

Current durable convention:

- `~/opt/bin` is the preferred executable location on the phone's internal
  Termux storage.
- This is a phone convention. Do not project it onto the tablet without an
  explicit tablet decision.
- The phone has previously exposed an external SD card through
  `~/storage/external-1`; verify that mount at runtime before using it because
  removable-media availability can change.
- A previously observed resolution was
  `/storage/4A21-0000/Android/data/com.termux/files`. Treat that as historical
  device evidence, not a universal Android path.

## Tablet

Verified 2026-09-18 on the physical TAB_P10:

- model: `TAB_P10`
- hardware: `sun65iw1p1`
- architecture: `aarch64`
- `~/storage/downloads` resolves to `/storage/emulated/0/Download`
- that Downloads path is Android emulated shared storage, not an external SD
  card
- `~/storage/external-1` is absent
- no working external SD card has been established for this tablet
- Android shared Downloads is not an executable location for ELF binaries;
  physical Mali-G57 acceptance required moving the executable to private Termux
  storage while leaving durable shader inputs/receipts in shared storage

Do not infer a future tablet SD-card mount from the phone. If an SD card is
added later, record its actual tablet path here after verifying it on the
tablet.

## Verification snippets

Shared Downloads:

```sh
readlink -f ~/storage/downloads
df -h ~/storage/downloads
```

External media:

```sh
if [ -e ~/storage/external-1 ]; then
    readlink -f ~/storage/external-1
    df -h ~/storage/external-1
else
    echo 'no external-1 on this device'
fi
```

When execution capability matters, prove it on the exact mount instead of
assuming that Unix mode bits imply execution.
