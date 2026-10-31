# Android companion build plan (candidate v1)

Cat Food owns the target and companion policy; the application repository owns its
requirements. This operation makes an immutable, read-only plan and never builds,
packages, installs, publishes, or claims physical hardware acceptance.

On a host with a verified Cat Food checkout, run:

    ./catfood plan-android-build /path/to/app/ci/android-application.tsv phone FULL_SOURCE_SHA

The input is an eight-key, two-column UTF-8 TSV. Required keys:
schema=catfood-android-application-v1, repository=owner/name,
package_id, launcher_label, min_sdk, packaging=shared|split,
armeabi-v7a=supported|incompatible|unknown and
arm64-v8a=supported|incompatible|unknown. The equals signs here
describe values: actual file fields are separated by tabs.

A phone request emits A1 plus C67 obligations. Compatible C67 is required;
unsupported C67 remains incompatible, and unresolved C67 remains blocked.
A C67-only request does not infer a reverse A1 obligation.
A separate `tablet` request emits only TAB_P10/arm64-v8a with
`acceptance=not_run`. This is build eligibility from the app's declared ABI,
not observed TAB_P10 hardware, firmware, installed packages, SD state, or proof
that the same ARM64 APK ran on the tablet. The C67 and tablet do not share
physical acceptance receipts. Unsupported or unknown ARM64 blocks a tablet
request, and an unknown target selector is rejected.

The plan includes Cat Food commit, authoritative matrix hash, app requirement
hash, and exact source SHA. Downstream stages must hash the whole plan and
bind that digest to their own artifact and validation receipts. The plan is
not an authorized release, even if its requirements claim support.

The application owns its declarations; AICI/FP must independently check approved
Cat Food policy, required artifact-group ABI set (shared or split), finished APK
label, signing, package, update identity, source provenance and output hashes.
Physical A1, C67 and tablet evidence are independent. Existing code covers
plan creation, not finished-APK qualification or publication.
