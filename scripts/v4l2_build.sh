#!/bin/bash
# Builds v4l2-utils using Meson and Ninja for aarch64 targets.

if [ ! -f /.dockerenv ]; then
    echo "ERROR: This script must be run inside the osrt-build Docker container." >&2
    exit 1
fi

if [ -z "${WORKDIR:-}" ]; then
    echo "ERROR: WORKDIR environment variable is not set." >&2
    exit 1
fi

source "${WORKDIR}/scripts/logging.sh"

V4L2_DIR="${WORKDIR}/workarea/v4l2-utils"
BUILD_DIR="${V4L2_DIR}/build"

NPROC=1

if [ ! -d "${V4L2_DIR}" ]; then
    log_error "v4l2-utils source directory not found: ${V4L2_DIR}"
    exit 1
fi

SECONDS=0

log_info "Building v4l2-utils with ${NPROC} parallel jobs..."
log_info "Source dir : ${V4L2_DIR}"
log_info "Build dir  : ${BUILD_DIR}"

cd "${V4L2_DIR}"

log_info "Running meson setup..."
rm -rf "${BUILD_DIR}"
meson setup "${BUILD_DIR}"

log_info "Compiling with Ninja (${NPROC} jobs, up to 20 attempts)..."

MAX_RETRIES=20
attempt=0
until ninja -C "${BUILD_DIR}" -j"${NPROC}"; do
    attempt=$(( attempt + 1 ))
    if [ "${attempt}" -ge "${MAX_RETRIES}" ]; then
        log_error "Ninja failed after ${MAX_RETRIES} attempts. Aborting."
        exit 1
    fi
    log_warn "Ninja attempt ${attempt}/${MAX_RETRIES} failed. Retrying in 3 seconds..."
    sleep 3
done

chmod -R a+w "${WORKDIR}/workarea"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
