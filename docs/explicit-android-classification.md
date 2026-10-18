# Classify captured Android properties

`catfood classify-android-target PRODUCT MODEL PRIMARY_ABI` exposes the existing
`catfood_android_profile` oracle for capture consumers. It runs before target
selection and provisioning, and ignores planning overrides. Conflicting known
product/model fields or a wrong primary ABI fail. Unknown fields return
`termux`, which a physical-device consumer must reject.

This operation classifies supplied values. It does not obtain them, attest
hardware, install anything, or upgrade a capture to physical acceptance.

The command reconciles the retained classifier from Cat Food PR #136. Scoped
profile lookup is a separate operation: classification answers which maintained
target matches supplied identity properties, while `android-profile` validates
source-bound facts for a named physical instance and requested operation.
