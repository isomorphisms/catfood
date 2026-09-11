# Cat Food targets

Cat Food has one implementation and four named acceptance targets. Shared mechanics do not imply shared acceptance.

| Target | Environment | Default workbench policy | What a passing receipt proves |
| --- | --- | --- | --- |
| `phone` | Termux on 32-bit ARMv7 Android | `$HOME/opt`, fetch every repository, no native tool build by default | The repository feed and stage-zero path work on the actual phone. Native Grease/YSH, Idriç, Ithon, and IR still need their own real-device receipts before they are claimed. |
| `tablet` | Termux on AArch64 Android | `$HOME/opt`, fetch every repository, no native tool build by default | The repository feed and stage-zero path work on the actual tablet. A tablet receipt is not a phone/ARMv7 receipt. Native builds remain unclaimed until exercised on the tablet. |
| `container` | Disposable Debian/Ubuntu container or sandbox | full workbench build, depth 1, no shell-profile modification; `/opt` when writable, otherwise `$HOME/opt` | A clean ephemeral Linux workbench can provision and build. It does not prove persistent-host, systemd, reboot, SSH, or provider-specific behavior. |
| `cloud` | Persistent Debian/Ubuntu host, including Hetzner | `/opt`, full workbench build and YSH install | The persistent cloud workbench path provisions and builds. Hetzner-specific acceptance may add resource, boot, SSH, or provider checks beyond ordinary Linux provisioning. |

`termux` remains a compatibility target for an unknown or explicitly generic Termux architecture. `hetzner` is accepted as an alias for `cloud`.

## Selection

Run the normal entrypoint and let Cat Food identify supported Termux architectures:

```sh
./catfood
```

On Termux, `armv7*`/`armv8l` selects `phone` and `aarch64`/`arm64` selects `tablet`. Non-Termux systems continue to select `cloud` automatically for compatibility. Container detection is deliberately not guessed because container and sandbox signals vary; select it explicitly:

```sh
CATFOOD_TARGET=container ./catfood
```

Likewise, any target can be forced explicitly:

```sh
CATFOOD_TARGET=phone ./catfood
CATFOOD_TARGET=tablet ./catfood
CATFOOD_TARGET=cloud ./catfood
```

To inspect selection without provisioning anything:

```sh
./catfood --target
CATFOOD_TARGET=container ./catfood --target
```

## Acceptance rule

Do not substitute receipts across these targets. In particular:

- AArch64 tablet success does not establish ARMv7 phone success.
- Linux container success does not establish the persistent Hetzner/cloud machine.
- GitHub Actions simulation of Termux does not replace execution on either Android device.
- A successful repository feed does not by itself establish native compiler/runtime builds that the target keeps disabled by default.
