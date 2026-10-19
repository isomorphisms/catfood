#!/bin/sh
# Synthetic properties for package-contract tests only; never physical evidence.
case ${CATFOOD_TARGET:-phone} in
    phone) fixture_model='MIRO A1'; fixture_product=''; fixture_abi=armeabi-v7a ;;
    c67) fixture_model='Miro C67'; fixture_product=Miro_C67; fixture_abi=arm64-v8a ;;
    tablet) fixture_model=TAB_P10; fixture_product=TAB_P10_ROW; fixture_abi=arm64-v8a ;;
    *) fixture_model=unknown; fixture_product=unknown; fixture_abi=unknown ;;
esac
case ${1:-} in
    ro.product.model) printf '%s\n' "${CATFOOD_TEST_MODEL-$fixture_model}" ;;
    ro.product.device) printf '%s\n' "${CATFOOD_TEST_DEVICE-$fixture_product}" ;;
    ro.product.cpu.abi) printf '%s\n' "${CATFOOD_TEST_ABI-$fixture_abi}" ;;
    ro.build.fingerprint) printf '%s\n' "synthetic/$fixture_model/test" ;;
    ro.build.version.sdk) printf '%s\n' 34 ;;
esac
