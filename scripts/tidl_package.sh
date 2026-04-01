#!/bin/bash
# Packages TIDL runtime shared libraries and headers into .deb files per platform.

if [ ! -f /.dockerenv ]; then
    echo "ERROR: This script must be run inside the osrt-build Docker container." >&2
    exit 1
fi

if [ -z "${WORKDIR:-}" ]; then
    echo "ERROR: WORKDIR environment variable is not set." >&2
    exit 1
fi

if [ -z "${SDK_VER:-}" ]; then
    echo "ERROR: SDK_VER environment variable is not set." >&2
    exit 1
fi

source "${WORKDIR}/scripts/logging.sh"

UTILS_SCRIPT="${WORKDIR}/scripts/utils.sh"
if [ ! -f "${UTILS_SCRIPT}" ]; then
    log_error "Utility script not found: ${UTILS_SCRIPT}"
    exit 1
fi
source "${UTILS_SCRIPT}"

WORKAREA="${WORKDIR}/workarea"
OUT_DIR="${WORKDIR}/out"

PKG_VERSION="11.0.0-1"
PKG_ARCHITECTURE="arm64"
PKG_MAINTAINER="T3 Gemstone Project Development Team <support@t3gemstone.org>"

PLATFORMS=("j722s")
MPUS=("A53")

. /etc/os-release
OS_NAME="${ID}_${VERSION_ID//./_}"

copy_lib_files() {
    local target_dir="$1"
    shift
    local lib_files=("$@")

    mkdir -p "${target_dir}"

    for lib_file in "${lib_files[@]}"; do
        if [ ! -f "${lib_file}" ]; then
            log_error "Library file not found: ${lib_file}"
            exit 1
        fi
        local new_name
        new_name=$(basename "${lib_file}" | sed 's/\.so\..*/.so/')
        cp "${lib_file}" "${target_dir}/${new_name}"
        log_info "Copied: $(basename "${lib_file}") → ${new_name}"
    done
}

SECONDS=0

cd "${WORKAREA}"

for i in "${!PLATFORMS[@]}"; do
    platform="${PLATFORMS[$i]}"
    mpu="${MPUS[$i]}"
    platform_upper="${platform^^}"

    DST_DIR="${WORKAREA}/arm-tidl-${platform}_${SDK_VER}-${OS_NAME}"
    DEB_NAME="arm-tidl-${platform}_${SDK_VER}-${OS_NAME}.deb"

    log_info "----------------------------------------"
    log_info " Packaging platform: ${platform} (${mpu})"
    log_info "----------------------------------------"

    TIDL_LIB_FILES=(
        "${WORKAREA}/arm-tidl/rt/out/${platform_upper}/${mpu}/LINUX/release/libvx_tidl_rt.so.1.0"
        "${WORKAREA}/arm-tidl/onnxrt_ep/out/${platform_upper}/${mpu}/LINUX/release/libtidl_onnxrt_EP.so.1.0"
        "${WORKAREA}/arm-tidl/tfl_delegate/out/${platform_upper}/${mpu}/LINUX/release/libtidl_tfl_delegate.so.1.0"
    )

    rm -rf "${DST_DIR}"
    mkdir -p "${DST_DIR}/usr/lib" "${DST_DIR}/DEBIAN"

    log_info "Copying shared libraries..."
    copy_lib_files "${DST_DIR}/usr/lib/" "${TIDL_LIB_FILES[@]}"
    log_success "Shared libraries copied."

    log_info "Copying header files..."
    TIDL_INC_DIR="${WORKAREA}/arm-tidl/rt/inc"
    if [ ! -d "${TIDL_INC_DIR}" ]; then
        log_error "Header directory not found: ${TIDL_INC_DIR}"
        exit 1
    fi

    mkdir -p "${DST_DIR}/usr/include/arm-tidl/rt/inc"
    for header in itidl_rt.h itidl_ti.h itvm_rt.h; do
        if [ ! -f "${TIDL_INC_DIR}/${header}" ]; then
            log_error "Header file not found: ${TIDL_INC_DIR}/${header}"
            exit 1
        fi
        cp "${TIDL_INC_DIR}/${header}" "${DST_DIR}/usr/include/arm-tidl/rt/inc/"
    done
    log_success "Header files copied."

    log_info "Writing DEBIAN/control..."
    cat > "${DST_DIR}/DEBIAN/control" <<EOF
Package: arm-tidl-${platform}
Version: ${PKG_VERSION}
Section: libs
Priority: optional
Architecture: ${PKG_ARCHITECTURE}
Maintainer: ${PKG_MAINTAINER}
Description: TI TIDL runtime libraries for ${platform_upper} — shared libraries and headers.
EOF

    mkdir -p "${OUT_DIR}"
    log_info "Building .deb package: ${DEB_NAME}"
    dpkg-deb --build "${DST_DIR}" "${OUT_DIR}/${DEB_NAME}"
    log_success "Package ready: ${OUT_DIR}/${DEB_NAME}"

    rm -rf "${DST_DIR}"
done

chmod -R a+w "${WORKAREA}"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
