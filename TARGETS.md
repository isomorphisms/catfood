# Cat Food targets

Cat Food has one control plane and five concrete provisioning targets. Shared mechanics do not imply shared acceptance.

| Target | Environment | Normal policy | What a passing target receipt may prove |
| --- | --- | --- | --- |
| `phone` | Termux on 32-bit ARMv7 Android | `$HOME/opt`; download, verify, and install published `armeabi-v7a` runtime packages only | The exact available phone packages installed and the named physical-phone runtime checks ran. It does not erase explicit inventory gaps or accept the tablet. |
| `tablet` | Termux on AArch64 Android | `$HOME/opt`; download, verify, and install published `arm64-v8a` runtime packages only | The exact available tablet packages installed and the named physical-tablet runtime checks ran. It does not erase explicit inventory gaps or accept the phone. |
| `container` | Disposable Debian/Ubuntu container or sandbox | full source workbench; depth 1; no shell-profile modification | A clean ephemeral Linux workbench can provision, build, and execute the named runtime acceptance. It does not prove persistent-host or Android behavior. |
| `cloud` | Persistent Debian/Ubuntu host, including Hetzner | `/opt`; full source workbench and host tool builds | The persistent Debian/Ubuntu workbench path provisions, builds, and executes the named runtime acceptance. A Hetzner follower remains its own receipt rather than inheriting GitHub/container evidence. |
| `void` | Persistent Void Linux development workstation | `/opt`; `xbps` dependencies; full source workbench and host tool builds | The Void workbench path provisions, builds, and executes the named runtime acceptance. Ubuntu, container, or Hetzner x86-64 evidence does not satisfy it. |

`termux` remains a compatibility source-workbench target for an unknown or explicitly generic Termux architecture. `hetzner` is a provisioning alias for `cloud`, but `hetzner-x86_64` remains a distinct follower identity because provider/persistence evidence is not interchangeable with GitHub Ubuntu evidence.

## Selection

```sh
./catfood
```

On Termux, `armv7*`/`armv8l` selects `phone` and `aarch64`/`arm64` selects `tablet`. On non-Termux hosts, `/etc/os-release` selects `void` when `ID=void`; other hosts select `cloud`. Container detection is deliberately not guessed; select it explicitly:

```sh
CATFOOD_TARGET=container ./catfood
```

The development-machine target can also be forced explicitly:

```sh
CATFOOD_TARGET=void ./catfood
```

Any target can be forced explicitly, and `./catfood --target` reports selection without provisioning. `CATFOOD_OS_RELEASE` exists for deterministic target tests and unusual host layouts.

## Delivery and follower evidence

`followers/targets.tsv` names concrete acceptance environments rather than collapsing them by CPU architecture. The maintained shared set is:

- physical ARMv7 phone;
- physical AArch64 tablet;
- GitHub-hosted Ubuntu x86-64;
- disposable Ubuntu x86-64 container;
- persistent Hetzner x86-64;
- persistent Void Linux x86-64.

A separate GitHub x86-64 artifact follower verifies published Android artifact identity when an Android delivery path changes.

The x86 runtime action provisions the target and then executes an installed command. Repository tests and target selection run first, but they are not accepted as runtime evidence by themselves. `google-drive-unzip --help` is currently the small credential-free installed-command probe for the cloud-storage delivery boundary.

## Android rule

Both concrete Android targets are runtime-only consumers. Their normal Cat Food path must not:

- clone the project source fleet;
- install or bootstrap compiler/build toolchains;
- use an unfinished native compiler backend as a prerequisite for an unrelated package;
- repair a missing package by building from source on the device.

`android/delivery.tsv` accounts for the entire declared inventory plus Grease. `android/packages.tsv` contains only actual packages. `android/check.sh ready phone|tablet` is the whole-inventory manifest readiness gate and must stay red while intended runtime deliverables or classifications are unresolved.

For the storage API, the Grease/YSH source command is architecture-neutral and therefore may be byte-identical in the phone and tablet package rows. The runtime that executes it is still target-specific: the ARMv7 package depends on the ARMv7 Grease runtime and the AArch64 package depends on the AArch64 Grease runtime. Do not manufacture different binaries merely to make the rows look architecture-specific.

Do not substitute receipts across targets or evidence kinds. In particular, AArch64 tablet success is not ARMv7 phone success; GitHub/container execution is not Hetzner or Void execution; installation is not authenticated Google Drive behavior; and an experimental compiler/backend result is not an Android application delivery result.
