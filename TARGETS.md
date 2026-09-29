# Cat Food targets

Cat Food has one control plane and five concrete acceptance targets. Shared mechanics do not imply shared acceptance.

| Target | Environment | Normal policy | What a passing target receipt may prove |
| --- | --- | --- | --- |
| `phone` | Termux on 32-bit ARMv7 Android | `$HOME/opt`; download, verify, and install published `armeabi-v7a` runtime packages only | The exact available phone packages installed and the recorded physical-phone checks ran. It does not erase explicit inventory gaps or accept the tablet. |
| `tablet` | Termux on AArch64 Android | `$HOME/opt`; download, verify, and install published `arm64-v8a` runtime packages only | The exact available tablet packages installed and the recorded physical-tablet checks ran. It does not erase explicit inventory gaps or accept the phone. |
| `container` | Disposable Debian/Ubuntu container or sandbox | full source workbench; depth 1; no shell-profile modification | A clean ephemeral Linux workbench can provision and build. It does not prove persistent-host or Android behavior. |
| `cloud` | Persistent Debian/Ubuntu host, including Hetzner | `/opt`; full source workbench and host tool builds | The persistent cloud workbench path provisions and builds. Hetzner-specific acceptance may add provider checks. |
| `sdf` | Explicitly declared SDF NetBSD 9.3 amd64 session | `$HOME/opt`; fetch, verify, and install the pinned Grease NetBSD 9.3 runtime without root | The pinned package passed the executor-owned host checks, checksum verification, installation, and runtime smoke checks on the tested host. |

`termux` remains a compatibility source-workbench target for an unknown or explicitly generic Termux architecture. `hetzner` is an alias for `cloud`.

`netbsd` is a **recognized host class, not a provisioner**. Automatic detection of NetBSD amd64/x86_64 returns `netbsd`; Cat Food then fails closed instead of assuming that every NetBSD machine is SDF. Select `CATFOOD_TARGET=sdf` only when the human or an external machine binding explicitly establishes that role.

## Selection

```sh
./catfood --target
```

On Termux, `armv7*`/`armv8l` selects `phone` and `aarch64`/`arm64` selects `tablet`. Outside Termux, positive platform evidence selects Debian/Ubuntu Linux as `cloud` and NetBSD amd64/x86_64 as the non-provisioning `netbsd` class. Unknown operating systems, unsupported Linux distributions, and unsupported NetBSD architectures fail closed.

Container detection is deliberately not guessed:

```sh
CATFOOD_TARGET=container ./catfood
```

For a session explicitly established as SDF:

```sh
CATFOOD_TARGET=sdf ./catfood
```

Any target can be forced explicitly, and `./catfood --target` reports the normalized selection without provisioning.

## Android rule

Both concrete Android targets are runtime-only consumers. Their normal Cat Food path must not:

- clone the project source fleet;
- install or bootstrap compiler/build toolchains;
- use an unfinished native compiler backend as a prerequisite for an unrelated package;
- repair a missing package by building from source on the device.

`android/delivery.tsv` accounts for the entire declared inventory plus Grease. `android/packages.tsv` contains only actual packages. `android/check.sh ready phone|tablet` is the whole-inventory manifest readiness gate and must stay red while intended runtime deliverables or classifications are unresolved.

Do not substitute receipts across targets or evidence kinds. In particular, AArch64 tablet success is not ARMv7 phone success; GitHub/container execution is not physical Android execution; installation is not application behavior; and an experimental compiler/backend result is not an Android application delivery result.
