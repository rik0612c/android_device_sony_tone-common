#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2021 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"


function blob_fixup() {
    case "${1}" in
    vendor/lib64/libcameralight.so)
        ;&
    vendor/lib/libcameralight.so)
        ;&
    vendor/lib64/lib_fpc_tac_shared.so)
        ;&
    vendor/lib/lib_fpc_tac_shared.so)
        sed -i "s/\/system\/etc\//\/vendor\/etc\//g" "${2}"
        ;;
    vendor/lib/libSecureUILib.so)
        ;&
    vendor/lib/libGPTEE_vendor.so)
        ;&
    vendor/lib/libGPTEE_system.so)
        ;&
    vendor/lib/lib_asb_tee.so)
        ;&
    vendor/lib/libtzdrmgenprov.so)
        ;&
    vendor/lib64/libSecureUILib.so)
        ;&
    vendor/lib64/libGPTEE_vendor.so)
        ;&
    vendor/lib64/libtpm.so)
        ;&
    vendor/lib64/libGPTEE_system.so)
        ;&
    vendor/lib64/lib_asb_tee.so)
        ;&
    vendor/lib64/libtee.so)
        ;&
    vendor/lib64/libtzdrmgenprov.so)
        ;&

    # kang vulkan from Daisy Q
    vendor/lib/hw/vulkan.msm8996.so | vendor/lib64/hw/vulkan.msm8996.so)
        sed -i -e 's|vulkan.msm8953.so|vulkan.msm8996.so|g' "${2}"
        ;;

    # Move telephony packages to /system_ext
    system_ext/etc/init/dpmd.rc)
        sed -i "s/\/system\/product\/bin\//\/system\/system_ext\/bin\//g" "${2}"
        ;;

    # Move telephony packages to /system_ext
    system_ext/etc/permissions/com.qti.dpmframework.xml|system_ext/etc/permissions/dpmapi.xml)
        sed -i "s/\/system\/product\/framework\//\/system\/system_ext\/framework\//g" "${2}"
        ;;

    # Provide shim for libdpmframework.so
    system_ext/lib64/libdpmframework.so)
        for  LIBCUTILS_SHIM in $(grep -L "libcutils_shim.so" "${2}"); do
            patchelf --add-needed "libcutils_shim.so" "$LIBCUTILS_SHIM"
        done
        ;;

    vendor/lib64/libwvhidl.so)
        patchelf --replace-needed "libprotobuf-cpp-lite.so" "libprotobuf-cpp-lite-v29.so" "${2}"
        ;;

    vendor/lib64/libtpm.so)
        patchelf --add-needed "libshim_binder.so" "${2}"
        ;;

    system_ext/lib64/lib-imsvideocodec.so)
        patchelf --add-needed "libims-shim.so" "${2}"
        ;;
    esac
}

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_COMMON=
ONLY_TARGET=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-common )
                ONLY_COMMON=true
                ;;
        --only-target )
                ONLY_TARGET=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

if [ -z "${ONLY_TARGET}" ]; then
    # Initialize the helper for common device
    setup_vendor "${DEVICE_COMMON}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ -z "${ONLY_COMMON}" ] && [ -s "${MY_DIR}/../${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for device
    source "${MY_DIR}/../${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../${DEVICE}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/setup-makefiles.sh"
