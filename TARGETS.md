# Cat Food targets

Cat Food has one control plane and four concrete acceptance targets. Shared mechanics do not imply shared acceptance.

| Target | Environment | Normal policy | What a passing target receipt may prove |
| --- | --- | --- | --- |
| `phone` | Termux on 32-bit ARMv7 Android | `$HOME/opt`; download, verify, and install published `armeabi-v7a` runtime packages only | The exact available phone packages installed and the recorded physical-phone checks ran. It does not erase explicit inventory gaps or accept the tablet. |
| `tablet` | Termux on AArch64 Android | `$HOME/opt`; download, verify, and install published `arm64-v8a` runtime packages only | The exact available tablet packages installed and the recorded physical-tablet checks ran. It does not erase explicit inventory gaps or accept the phone. |
| `container` | Disposable Debian/Ubuntu container or sandbox | full source workbench; depth 1; no shell-profile modification | A clean ephemeral Linux workbench can provision and build. It does not prove persistent-host or Android behavior. |
| `cloud` | Persistent Debian/Ubuntu host, including Hetzner | `/opt`; full source workbench and host tool builds | The persistent cloud workbench path provisions and builds. Hetzner-specific acceptance may add provider checks. |

`termux` remains a compatibility source-workbench target for an unknown or explicitly generic Termux architecture. `hetzner` is an alias for `cloud`.

## Selection

```sh
./catfood
```

On Termux, `armv7*`/`armv8l` selects `phone` and `aarch64`/`arm64` selects `tablet`. Non-Termux systems continue to select `cloud` automatically. Container detection is deliberately not guessed; select it explicitly:

```sh
CATFOOD_TARGET=container ./catfood
```

Any target can be forced explicitly, and `./catfood --target` reports selection without provisioning.

## Android rule

Both concrete Android targets are runtime-only consumers. Their normal Cat Food path must not:

- clone the project source fleet;
- install or bootstrap compiler/build toolchains;
- use an unfinished native compiler backend as a prerequisite for an unrelated package;
- repair a missing package by building from source on the device.

`android/delivery.tsv` accounts for the entire declared inventory plus Grease. `android/packages.tsv` contains only actual packages. `android/check.sh ready phone|tablet` is the whole-inventory manifest readiness gate and must stay red while intended runtime deliverables or classifications are unresolved.

Do not substitute receipts across targets or evidence kinds. In particular, AArch64 tablet success is not ARMv7 phone success; GitHub/container execution is not physical Android execution; installation is not application behavior; and an experimental compiler/backend result is not an Android application delivery result.
