#!/bin/bash
# This script should be run inside the CONTAINER

set -euo pipefail

source "${WORKDIR}/scripts/logging.sh"

if [ ! -f /.dockerenv ]; then
    log_error "This script must be run inside the osrt-build Docker container."
    exit 1
fi

if [ -z "${WORKDIR:-}" ]; then
    log_error "WORKDIR environment variable is not set."
    exit 1
fi

NPROC=1

TIDL_RT_PATH=$(readlink -f "${WORKDIR}/workarea/arm-tidl/rt")
BUILD_DIR="${WORKDIR}/workarea/neo-ai-dlr/build"
SOURCE_DIR="${WORKDIR}/workarea/neo-ai-dlr"

if [ ! -d "${SOURCE_DIR}" ]; then
    log_error "Source directory not found: ${SOURCE_DIR}"
    exit 1
fi

if [ ! -d "${TIDL_RT_PATH}" ]; then
    log_error "TIDL runtime path not found: ${TIDL_RT_PATH}"
    exit 1
fi

SECONDS=0

log_info "Starting DLR build with ${NPROC} parallel jobs..."
log_info "Source dir : ${SOURCE_DIR}"
log_info "TIDL RT    : ${TIDL_RT_PATH}"
log_info "Build dir  : ${BUILD_DIR}"

if [ ! -d "${BUILD_DIR}" ]; then
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"
    cmake \
        -DUSE_TIDL=ON \
        -DUSE_TIDL_RT_PATH="${TIDL_RT_PATH}" \
        -DDLR_BUILD_TESTS=OFF \
        -DCMAKE_TOOLCHAIN_FILE="${SOURCE_DIR}/cmake/aarch64-linux-gcc-native.cmake" \
        "${SOURCE_DIR}"
else
    cd "${BUILD_DIR}"
fi

make -j"${NPROC}"

chmod -R a+w "${WORKDIR}/workarea"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
