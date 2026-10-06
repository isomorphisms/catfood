# Cloud storage delivery reconciliation (issue 117)

The current inventory includes `dilapidated-shed/cloud-storage-api`. Android
delivery remains an explicit current-client-bundle publication gap, not the
retired branch's ordinary-unzip package masquerading as the complete client.
The old architecture-neutral command is preserved at producer
4be1d5a3d603154262f247581dcd76f6a4b317cd, SHA-256
d8f0eee6efbee1125cc227d01448f239c4895a72d254d1a786510aae69a5f97a.
That Apps Script command requires deployment/authorization and is not the live
ZIP64 selective transport, OAuth helper, or SDF bounded uploader.

Current delivery must package the Grease commands and pinned Drive method table
together, plus native google-oauth-loopback, google-drive-download-state,
google-drive-upload-state and zip-central-directory helpers for each qualified
ABI. Runtime dependencies include the declared Grease shell, jq, curl >=8.4,
hash utilities and OpenSSH for SDF. Do not map GNU/Linux ARM helper compilation
to Android/Bionic acceptance. Build on a qualified host through ICK where
supported, otherwise NDK with the exact ICK gap recorded; no phone compiler.
The producer now has `build/android-client.grease`, NDK r27c/API 21 and separate
ARMv7/ARM64 bundles containing all four helpers, commands, table and digests.
Both were built and ELF/interpreter checked on a disposable Linux host. Hosted
artifact publication and admission into target-specific acquisition records
still require current exact-head evidence; no installed-runtime receipt exists.

The C67 profile is retained in `android/devices/miro-c67.md` on current main,
including the 2026-10-06 native ARM32/Bionic and 4 KiB page-size receipt.
It observes Android API 34 with arm64-v8a and ARM32 compatibility. The storage
line must consume that profile, never classify all AArch64
targets as C67 or borrow tablet physical evidence. Until current-profile
acquisition and exact bundle publication are integrated, C67 install/runtime
remain blocked. No target-detector rewrite is made here; issue 118 owns it.

IB's existing Google authorization APK is Java/Play Services without native
libraries. It needs a compatible Android runtime and the canonical signer,
package/version/OAuth registration, not a separate arm64 build. The receiver
remains experimental. The current narrow receiver allows readonly by default
and readonly + drive.file for application-owned archives. Google client/signer
registration and physical C67 Google authorization remain independent gates.

For host registration, `commands/activate-cloud-storage.grease` adds help-tested
commands through a verified installed Grease and an explicit checkout. It does
not install or compile missing native helpers, activate a cloud service, or
provide live provider acceptance. Current desktop/container, GitHub Ubuntu,
Hetzner, Void and SDF remain separate. Issue 117 retains the old exact follower
jobs ae27f2938d405d382d22363c59dbfa1a8d802772 and db7b39f5ede0…;
they are not superseded or accepted by this inventory/registration change.

Kitchen owns preparation; Flexible Pipes owns repeatable contract execution;
AICI owns evidence interpretation. IB owns exact retained sources and decoders.
The transport repository must not acquire another corpus or privacy model.
