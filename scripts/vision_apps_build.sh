#!/bin/bash

if [ ! -f /.dockerenv ]; then
    echo "ERROR: This script must be run inside the osrt-build Docker container." >&2
    exit 1
fi

if [ -z "${WORKDIR:-}" ]; then
    echo "ERROR: WORKDIR environment variable is not set." >&2
    exit 1
fi

source "${WORKDIR}/scripts/logging.sh"

set -e

if [ -z "${SOC:-}" ]; then
    log_error "SOC environment variable is not set."
    exit 1
fi

if [ -z "${BASE_IMAGE:-}" ]; then
    log_error "BASE_IMAGE environment variable is not set."
    exit 1
fi

. /etc/os-release
OS_NAME="${ID}.${VERSION_ID}"

OUT_DIR="${WORKDIR}/out"
DEB_GLOB="${WORKDIR}/workarea/sdk/vision_apps/out/J722S/A53/LINUX/release/*-${OS_NAME}.deb"

SECONDS=0

log_info "Building vision_apps for SOC=${SOC}, BASE_IMAGE=${BASE_IMAGE}, OS=${OS_NAME}..."

log_info "Running yocto_build..."
GCC_LINUX_ARM_ROOT=/usr \
    CROSS_COMPILE_LINARO= \
    LINUX_SYSROOT_ARM=/ \
    LINUX_FS_PATH=/ \
    TREAT_WARNINGS_AS_ERROR=0 \
    make yocto_build
log_success "yocto_build complete."

log_info "Packaging (dist=${OS_NAME})..."
PKG_DIST=${OS_NAME} \
    TIDL_PATH=/opt/psdk-rtos/workarea/tidl_j7 \
    make deb_package
log_success "deb_package complete."

log_info "Copying .deb artifacts to ${OUT_DIR}..."
mkdir -p "${OUT_DIR}"
cp ${DEB_GLOB} "${OUT_DIR}/"
log_success "Artifacts copied to ${OUT_DIR}."

log_info "Fixing permissions on SDK workarea..."
chmod -R a+w "${WORKDIR}/workarea/sdk"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
