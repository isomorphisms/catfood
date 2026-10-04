# MIRO C67 Cat Food target note

This note keeps the C67 visible to Android delivery without pretending its
physical runtime ABI has already been measured.

## Model-level facts

Current product/platform documentation gives:

```text
product           MIRO C67
Android listing   Android 14
SoC               MediaTek Helio G36
CPU               8 x Arm Cortex-A53, up to 2.2 GHz
CPU capability    64-bit
GPU               IMG PowerVR GE8320
physical RAM      4 GB
internal storage  64 GB
display           1600 x 720, 90 Hz
```

Sources:

- https://www.mediatek.com/products/smartphones/mediatek-helio-g36
- https://www.newegg.com/miro-c67-6-75-black/p/23B-00MN-00005
- FCC identity: https://fccid.io/2AQRMC67

## Cat Food mapping is intentionally unresolved

The existing concrete Android targets are currently:

- `phone`: 32-bit `armeabi-v7a`;
- `tablet`: `arm64-v8a`.

The Helio G36 being 64-bit does not establish which ABI the physical C67 Android
userspace exposes. Do not route C67 packages through either target merely from
the SoC specification.

Before assigning it, retain a physical receipt containing:

```text
Android build fingerprint
SDK level
ro.product.cpu.abi
ro.product.cpu.abilist
ro.product.cpu.abilist32
ro.product.cpu.abilist64
uname -m
kernel version
runtime page size
```

Then execute a tiny native artifact for every ABI Cat Food intends to publish
for the C67.

## Optimization handoff

After the ABI receipt exists:

1. map packaging to the existing ABI lane rather than inventing a C67 ABI;
2. keep Cortex-A53 tuning separate from the generic ABI baseline;
3. send CPU/codegen evidence to ICK and the Idriç native ARM line;
4. send GE8320 physical shader/driver evidence to the shader/GPU work;
5. send physical RAM/zram/storage evidence to the memory/zram work;
6. keep package installation, launch, runtime behavior and physical-device
   execution as separate receipts.

Canonical shared hardware notes live in `isomorphisms/android-NDK/hardware/`.
