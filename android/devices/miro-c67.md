# MIRO C67 physical Android profile

This is the retained Cat Food profile for the physical MIRO C67 measured on
2026-10-05. The machine-readable observation ledger is
[`docs/observations/miro-c67-hardware-2026-10-05.tsv`](../../docs/observations/miro-c67-hardware-2026-10-05.tsv).

The profile records observed device facts separately from model/platform claims
and from build acceptance. It does not claim a package has passed physical C67
acceptance merely because the device ABI is known.

## Identity and Android

```text
manufacturer       Foxx Development Inc
brand              MIRO
model              Miro C67
device             Miro_C67
board              k65v1_64_bsp
hardware           mt6765
Android            14
SDK                34
security patch     2024-10-05
build fingerprint  MIRO/C67/Miro_C67:14/UP1A.231005.007/1727680044:user/release-keys
kernel             Linux 4.19.191 aarch64
```

## Runtime ABI

Physical properties:

```text
primary ABI         arm64-v8a
ABI list            arm64-v8a,armeabi-v7a,armeabi
32-bit ABI list     armeabi-v7a,armeabi
64-bit ABI list     arm64-v8a
kernel machine      aarch64
```

This resolves the previous model-only uncertainty: the C67 is an
`arm64-v8a` Android runtime and also exposes 32-bit ARM compatibility.

Runtime page size and native execution are captured by
`android/record-c67-runtime.sh` during normal `c67` provisioning. The
result is retained at `$CATFOOD_ROOT/receipts/c67-runtime.tsv`; application-level
physical acceptance remains separate for each APK.

## CPU

Physical CPU evidence:

```text
SoC                MediaTek MT6765
cores              8
microarchitecture  Arm Cortex-A53
CPU part           0xd03
CPUs 0-3           900 MHz .. 2.2 GHz
CPUs 4-7           400 MHz .. 1.6 GHz
```

The silicon is homogeneous Cortex-A53, while cpufreq exposes two four-core
frequency policies.

## Memory and storage

Physical evidence:

```text
MemTotal            3865468 kB
SwapTotal           2126000 kB
/data               ~47 GiB formatted
/data filesystem    ext4
/data encryption    inlinecrypt
internal block      mmcblk0
```

`mmcblk0` establishes an MMC/eMMC-style block path. The exact flash package,
manufacturer, geometry, and zram compressor remain unresolved because Android
shell authority could not read the needed nodes. Do not promote the vendor
`charge_full_design`-style oddities or product marketing into storage facts.

## GPU and display

Physical SurfaceFlinger/display evidence:

```text
GPU vendor          Imagination Technologies
GPU renderer        PowerVR Rogue GE8320
EGL                 1.4 Android META-EGL
OpenGL ES           3.2 build 1.13@5776728
display             720 x 1600
density             320
refresh modes       60 Hz, 90 Hz
active/default      90 Hz at capture
HDR                 not supported
```

The C67 therefore has a physically observed GLES 3.2 GE8320 path. Application
requirements must still be driven by each consumer; do not raise a generic
minimum GLES requirement merely because this device supports 3.2.

## USB

Physical/framework evidence:

```text
controller          musb-hdrc
framework features  android.hardware.usb.accessory
                    android.hardware.usb.host
port modes          dual
USB HAL             1.3
```

The phone is therefore a valid USB host/accessory experimentation target.
Actual host-mode peripheral behavior remains device acceptance work.

## Wi-Fi and Bluetooth

Physical Wi-Fi evidence:

```text
bands               2.4 GHz, 5 GHz
2.4 GHz channels    1-11
5 GHz channels      36,40,44,48,149,153,157,161,165
6 GHz               none reported
observed standard   Android Wi-Fi standard 5 / 802.11ac
max link speed      433 Mbps
```

Historical connection records included AP-side Wi-Fi-6 metadata; that is not
proof that the phone itself is Wi-Fi 6.

Physical Bluetooth evidence includes working A2DP source operation, selectable
AAC and SBC, AAC 44.1 kHz / 16-bit / stereo during capture, A2DP offload
disabled, and ten reported LE advertising sets. Do not infer a Bluetooth
marketing version solely from raw HCI/LMP numeric version fields.

## Sensors and input

Physical Android sensor service exposes:

- accelerometer;
- magnetometer;
- orientation;
- gyroscope;
- light;
- proximity.

AOSP virtual/fused sensors include corrected gyroscope, game rotation vector,
geomagnetic rotation vector, gravity, rotation vector, and orientation.

Input evidence:

```text
touchscreen          NVTCapacitiveTouchScreen
multitouch slots     10
touch coordinates    X 0..720, Y 0..1600
touch pressure       0..1000
wired headset path   mt63xx-accdet Headset
```

The headset input device exposes headphone, microphone, line-out, and physical
jack insertion switches.

## Cameras

The retained camera-service excerpt exposes three entries:

```text
back   orientation 90 degrees
front  orientation 270 degrees
back   orientation 90 degrees
```

At least one rear camera reports a flash unit; the front entry reports no flash.
Exact camera IDs, pixel-array dimensions, focal lengths, and sensor models have
not yet been retained, so they remain unresolved.

## Battery

Physical capture at 100%:

```text
technology           Li-ion
charge_full          2946000 uAh
voltage              4360 mV
temperature          18.8 C
cycle_count          1
```

The vendor node reported `charge_full_design=294000` uAh. That conflicts with
the rest of the device evidence and is retained only as a suspect/mis-scaled
vendor value, not as the battery design capacity.

## Shizuku / rish on this C67

Shizuku and `rish` were physically exercised successfully. Current Termux
private placement is:

```text
$HOME/opt/rish
$HOME/opt/rish_shizuku.dex
```

with `$HOME/opt` on `PATH`.

Android 14 rejected a writable DEX path and `rish` removed write permission
before loading. Shizuku supplies Android shell authority, not root; reads such
as `/proc/swaps` and some sysfs details can still be denied.

## C67 APK producer baseline

There is now enough physical information to begin C67-native APK work.

Use these target facts:

```text
application ABI      arm64-v8a
Android runtime      14 / API 34
native architecture  AArch64
GPU                  PowerVR Rogue GE8320 / GLES 3.2
window               720 x 1600
refresh              60/90 Hz
```

Build rules:

1. Prefer an `arm64-v8a` native payload for a C67-specific APK.
2. Keep the application's existing minimum SDK as the NDK API level unless the
   application actually requires a newer Android symbol. Do not mechanically
   turn physical API 34 into `minSdk=34`.
3. Under the Android NDK route, the native compiler target is
   `aarch64-linux-android<minSdk>`; package the resulting shared object under
   `lib/arm64-v8a/`.
4. Use the organization's canonical `isomorphisms/android-NDK` NativeActivity
   / direct-DEX packaging substrate rather than inventing a new Gradle/Java
   wrapper.
5. Preserve the AICI build rule: maintained compile/link stages use qualified
   ICK when that exact surface is proven, otherwise Android NDK with the exact
   ICK capability gap recorded.
6. A shared A1+C67 package may contain both `armeabi-v7a` and `arm64-v8a`
   libraries, but physical acceptance remains per device and per artifact.
7. Do not hard-code 90 Hz. Render against the actual Android window/display
   mode and treat 60/90 Hz as runtime state.
8. GLES 3.2 is available on this C67; require only the GLES level the
   application needs.
9. Strip release native payloads, sign with the application's declared stable
   signer, then separately record package, install, launch, runtime, and
   physical-device evidence.

## Cat Food target selection

The target model now keeps physical device identity separate from the package
ABI lane. Automatic Termux selection is:

```text
ARMv7 Termux                         -> phone
AArch64 + Miro_C67 / Miro C67      -> c67
other AArch64 Termux                -> tablet
```

The `c67` target consumes the existing `tablet` delivery column only as the
shared `arm64-v8a` package lane. Installer receipts retain `device_target=c67`
and the observed product/model/fingerprint, so package reuse no longer erases
the physical-device distinction. `android/check.sh ready c67` applies the same
AArch64 manifest readiness gate while C67 physical acceptance stays independent.

Canonical generic Android-native architecture remains in
`isomorphisms/android-NDK`; this Cat Food file owns the concrete C67
runtime/delivery facts.
