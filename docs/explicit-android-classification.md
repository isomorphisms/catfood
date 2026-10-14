# Classify captured Android properties

`catfood classify-android-target PRODUCT MODEL PRIMARY_ABI` exposes the existing
`catfood_android_profile` oracle for host-side capture consumers. It runs before
target selection/provisioning and ignores planning overrides. Conflicting known
product/model fields or a wrong primary ABI fail. Unknown fields return termux,
which a physical-device consumer must reject.

This operation classifies supplied values. It does not obtain them, attest
hardware, install anything, or upgrade a capture to physical acceptance.
Kitchen's FC-M4 procedure records its actual per-serial ADB property outputs,
then passes those bytes here rather than treating an absent property adapter
as a planning-only target selection. Tests cover A1/C67 classification, an
override that must not change the result, unknown identity, conflicting model,
wrong ABI and missing arguments. Existing targets.sh regressions still pass.
