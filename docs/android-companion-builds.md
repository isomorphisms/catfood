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

The plan includes Cat Food commit, authoritative matrix hash, app requirement
hash, and exact source SHA. Downstream stages must hash the whole plan and
bind that digest to their own artifact and validation receipts. The plan is
not an authorized release, even if its requirements claim support.

The application owns its declarations; AICI/FP must independently check approved
Cat Food policy, required artifact-group ABI set (shared or split), finished APK
label, signing, package, update identity, source provenance and output hashes.
Physical A1, C67 and tablet evidence are independent. Existing code covers
plan creation, not finished-APK qualification or publication.
