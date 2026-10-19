# Native Grease acquisition before Grease

`sh /verified/catfood/catfood ensure-grease` identifies the actual Android model,
checks ordinary Termux context, and prints one verified absolute runtime path.
Diagnostics and receipt paths go to stderr. The caller prepends the returned
runtime's directory to its own PATH; no shell startup file is changed.

Valid installed payloads are reused. Both stable Grease and its sibling engine
links are checked and repaired only when absent or owned by Cat Food's Grease
package lane. Unowned commands and corrupt installed payloads are preserved
and rejected. Missing packages use the existing Android installer restricted
to their package ID, avoiding unrelated delivery and generic Linux jq probes.
Pinned native bytes and embedded source/packaging/ABI metadata are checked
before install and again before the actual runtime probe. No Python 2 or
device compilation is involved. A provisioning lock refuses concurrent or
uncertain interrupted owners. Each successful probe produces a new receipt.

`grease-payloads.tsv` was derived from the two published archives whose SHA-256
already appears in `packages.tsv`; both archive hashes were independently
checked. Host payload verification is not ARM execution. Initial independent
tests cover genuine payloads, wrong ABI, damaged engine/wrapper/metadata,
missing engine and redirected engine. Target-specific existing suites pass.

Remaining acceptance: installed-visible/hidden/absent cases on real Termux,
interrupted-install recovery and current physical target receipts. The generic
full-provisioner jq failure in issue 130 remains open; the narrow runtime
acquisition path does not establish full-distribution readiness.
