# Cat Food targets

Cat Food has one control plane and five concrete acceptance targets. Shared mechanics do not imply shared acceptance.

| Target | Environment | Normal policy | What a passing target receipt may prove |
| --- | --- | --- | --- |
| `phone` | Termux on 32-bit ARMv7 Android | `$HOME/opt`; download, verify, and install published `armeabi-v7a` runtime packages only | The exact available ARMv7 phone packages installed and the recorded physical-phone checks ran. |
| `c67` | Termux on the physical MIRO C67 | `$HOME/opt`; consume the existing `arm64-v8a` delivery lane and retain C67 identity separately | The exact AArch64 packages ran on the C67. It does not accept another AArch64 device. |
| `tablet` | Termux on another AArch64 Android tablet target | `$HOME/opt`; download, verify, and install published `arm64-v8a` runtime packages only | The exact available tablet packages installed and the recorded physical-tablet checks ran. It does not accept the C67. |
| `container` | Disposable Debian/Ubuntu container or sandbox | full source workbench; depth 1; no shell-profile modification | A clean ephemeral Linux workbench can provision and build. It does not prove persistent-host or Android behavior. |
| `cloud` | Persistent Debian/Ubuntu host, including Hetzner | `/opt`; full source workbench and host tool builds | The persistent cloud workbench path provisions and builds. Hetzner-specific acceptance may add provider checks. |

`termux` remains a compatibility source-workbench target for an unknown or explicitly generic Termux architecture. `hetzner` is an alias for `cloud`.

## Selection

```sh
./catfood
```

On Termux, `armv7*`/`armv8l` selects `phone`. An AArch64 device whose Android product identity is `Miro_C67` / `Miro C67` selects `c67`; other AArch64 devices select `tablet`. Non-Termux systems continue to select `cloud` automatically. Container detection is deliberately not guessed; select it explicitly:

```sh
CATFOOD_TARGET=container ./catfood
```

Any target can be forced explicitly, and `./catfood --target` reports selection without provisioning.

## Android package lanes

The existing Android delivery manifests still have two package lanes:

- `phone` = `armeabi-v7a`;
- `tablet` = `arm64-v8a`.

The physical `c67` target consumes the `tablet` package lane because the C67 primary ABI is `arm64-v8a`. This is a package/ABI reuse relation, not a claim that the C67 is a tablet. C67 installation receipts retain `device_target=c67` plus the observed product, model, and build fingerprint. `android/check.sh ready c67` evaluates the AArch64 package lane while physical acceptance remains C67-specific.

After normal C67 provisioning, `android/record-c67-runtime.sh` records the runtime page size and executes the pinned AArch64 jq binary, tying a native-execution probe to its Cat Food runtime-binary receipt.

## Android rule

All concrete Android targets are runtime-only consumers. Their normal Cat Food path must not:

- clone the project source fleet;
- install or bootstrap compiler/build toolchains;
- use an unfinished native compiler backend as a prerequisite for an unrelated package;
- repair a missing package by building from source on the device.

`android/delivery.tsv` accounts for the entire declared inventory plus Grease. `android/packages.tsv` contains only actual packages. `android/check.sh ready phone|c67|tablet` is the whole-inventory manifest readiness gate and must stay red while intended runtime deliverables or classifications are unresolved.

Do not substitute receipts across targets or evidence kinds. In particular, ARM64 package compatibility does not turn C67 evidence into tablet evidence; GitHub/container execution is not physical Android execution; installation is not application behavior; and an experimental compiler/backend result is not an Android application delivery result.
