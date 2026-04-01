#!/bin/bash

if [ ! -f /.dockerenv ]; then
    echo "ERROR: This script must be run inside the osrt-build Docker container." >&2
    exit 1
fi

if [ -z "${WORK_DIR:-}" ]; then
    echo "ERROR: WORK_DIR environment variable is not set." >&2
    exit 1
fi

source "${WORK_DIR}/scripts/logging.sh"

set -e

. /etc/os-release
OS_NAME="${ID}.${VERSION_ID}"

PLATFORMS=(
    j784s4
    j721s2
    j721e
    j722s
    am62a
)

WORKAREA="${WORK_DIR}/workarea"
SDK_BUILDER_DIR="${WORKAREA}/sdk_builder"

SECONDS=0
current_dir=$(pwd)

log_info "Starting multi-platform vision_apps build for OS: ${OS_NAME}"
log_info "Platforms : ${PLATFORMS[*]}"
log_info "SDK builder: ${SDK_BUILDER_DIR}"

cd "${SDK_BUILDER_DIR}"

for platform in "${PLATFORMS[@]}"; do
    log_info "------------------------------------------------------------"
    log_info "Platform: ${platform} — cleaning..."
    SOC=${platform} make yocto_clean

    log_info "Platform: ${platform} — building..."
    SOC=${platform} \
        GCC_LINUX_ARM_ROOT=/usr \
        CROSS_COMPILE_LINARO= \
        LINUX_SYSROOT_ARM=/ \
        LINUX_FS_PATH=/ \
        TREAT_WARNINGS_AS_ERROR=0 \
        make yocto_build
    log_success "Platform: ${platform} — build complete."

    log_info "Platform: ${platform} — packaging (dist=${OS_NAME})..."
    SOC=${platform} \
        PKG_DIST=${OS_NAME} \
        TIDL_PATH=/opt/psdk-rtos/workarea/tidl_j7 \
        make deb_package
    log_success "Platform: ${platform} — package complete."

    log_info "Platform: ${platform} — post-build clean..."
    SOC=${platform} make yocto_clean
    log_success "Platform: ${platform} — done."
done

log_info "Fixing permissions on workarea..."
chmod -R a+w "${WORKAREA}"

cd "${current_dir}"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
