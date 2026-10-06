# MIRO A1: device evidence and diagnostic boundaries

This is the canonical navigation point for the A1 observations below. It is not
an assertion that every A1 phone has the same firmware, installed packages,
paths, or currently running services. It does not redefine Cat Food's ABI
selectors or establish application acceptance.

## Sources

- **phone-receipt-2026-09-18:** the [historical physical-phone receipt](https://github.com/isomorphisms/catfood/blob/c3a27abb5f7c3c50156d8be25c2c10b5942a8905/followers/receipts/catfood-cb726afa73a7-phone.tsv),
  recorded at `2026-09-18T03:23:53Z`. It describes a human-reported run on a
  Foxx MIRO A1, Android 14, ARMv7 / `armeabi-v7a`. Its exact artifact is the
  PowerVR shader runner, not Crystal. The receipt remains on PR #41,
  **Deliver cloud-built PowerVR runners to Android targets**; its presence
  does not mean that PR is merged or that the same package remains installed.
- **session-2026-10-05:** the user's terminal output during Crystal debugging,
  retained as [selected transcript excerpts](../../docs/observations/miro-a1-graphics-rish-2026-10-05.txt)
  and a [field summary](../../docs/observations/miro-a1-graphics-rish-2026-10-05.tsv).
  The conversation identifies the phone as MIRO A1. The local observation date
  is October 5; an exact capture time, device-instance identifier, build
  fingerprint, and APK digests were not supplied. This is reported evidence,
  not a new execution by the audit author.

## Hardware and graphics facts

| Fact | Observation | Source and scope |
| --- | --- | --- |
| Device / Android / ABI | Foxx MIRO A1 / Android 14 / `armeabi-v7a` | Historical phone receipt; not a fresh ABI or firmware probe |
| GPU vendor | Imagination Technologies | Historical runner and October 5 SurfaceFlinger output |
| GPU renderer | PowerVR Rogue GE8322 | Historical runner and October 5 SurfaceFlinger output |
| Advertised GLES version | `196610`, decoded as 3.2 | October 5 `getprop ro.opengles.version` |
| EGL implementation | `1.5 Android META-EGL` | October 5 SurfaceFlinger output |
| Reported GL version/build | `OpenGL ES 3.2 build 1.18@6267915` | SurfaceFlinger RenderEngine context, not Crystal |
| EGL/GL extension strings | Retained in the transcript | Same compositor context; not proof of app-enabled capabilities |

The historical runner receipt reports six shader compile/link passes and six
framebuffer/readback passes for its exact archive
`714e5f706a05224ff4f43188a6fb043e7fa39f6a7f7f6ea7b0ef0dcb424502de`.
That result does not accept another shader, renderer, APK, or device instance.

Crystal's active-context GL/EGL version, GLSL version, enabled extensions,
viewport, rendering path, and installed source identity remain **unknown** in
this session. Query those in the app when the diagnostic claim needs them.
Do not use SurfaceFlinger's `GPU missed frame count: 3876` as an app-attributed
failure or performance measurement.

## Session-only runtime observations

The October 5 package query reported:

```
org.isomorphisms.crystal.bismuth
org.isomorphisms.crystal.halite
org.isomorphisms.crystal.quartz
org.isomorphisms.crystal.inspect.halite
```

Both original and diagnostic Halite namespaces exist. Package presence alone
cannot select the app being viewed or identify its version, signer, APK bytes,
or source commit. A PID must not substitute for that identity.

The session eventually obtained package and SurfaceFlinger output through
`rish -c`. That establishes those operations at that time, not perpetual
Shizuku availability or root. No explicit successful `id` output was supplied.
Earlier failures included the `PKG` application-ID placeholder and
`Server is not running` despite a non-writable private DEX. File readiness,
launcher identity, service readiness, authorization, and effective authority
are separate checks. The reported recovery after an ADB command does not by
itself identify which server transition caused recovery.

For previously observed export and private-execution paths, read the device
identity/storage section of [the root agent instructions](../../AGENTS.md).
Those dated paths must not be projected onto another phone. Refresh mutable
facts only when they affect the requested operation; do not repeatedly ask the
human to rediscover already sourced GPU identity.

## Why the information was missed

At audited main `5c0ae8841e2c5553cfaed69a9bcf660991eddad1`, the Android
index had no A1 profile. GPU evidence lived in historical PR/receipt material;
Shizuku paths were in AGENTS; device inventory and provisioning remained in
separate unmerged work. The assistant also failed to consult existing guidance
before serving commands. Consolidation repairs discoverability, not that
behavioral enforcement failure.

Reuse these existing owners rather than create a parallel registry:

- PR #82, **Record and compare device inventories**, at
  `7a27bbf8222b33eb7a47e8b3e808da3a12e675e1`: open/draft at audit.
- PR #80, **Add idempotent MIRO phone first-run setup**, at
  `0cdf46ce948b55b38da68992d6de43daacbef06a`: open at audit.
- PR #94, **Preserve Shizuku exports and repair the current bootstrap contract**,
  at `fa4b7232af257ebee01bf09bfd27768bfc4a2ff0`: open/draft at audit.

A branch implementation is not a main-branch command, a main-branch command is
not an installed helper, and an installed helper is not a current service probe.
Refresh PR state before acting on this dated audit.

## Repair owners

[Cat Food #110](https://github.com/isomorphisms/catfood/issues/110) owns profile
consumption, provenance, freshness, and visibility of missing evidence.
[Kitchen #26](https://github.com/isomorphisms/kitchen/issues/26) owns the prepared,
identity-bound capture task; [AICI #208](https://github.com/isomorphisms/ai-ci/issues/208)
owns reusable diagnostic-evidence validation. [Crystal #9](https://github.com/functorial-games/crystal/issues/9)
owns app telemetry, frame/input replay, and visual/zoom tests.
[Flexible Pipes #28](https://github.com/isomorphisms/flexible-pipes/issues/28)
composes the existing owners. This document does not close those implementation
issues and does not claim a new APK, emulator run, or physical-device test.
