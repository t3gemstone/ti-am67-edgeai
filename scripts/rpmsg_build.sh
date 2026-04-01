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

RPMSG_DIR="${WORKDIR}/workarea/ti-rpmsg-char"

NPROC=$(( $(nproc) > 1 ? $(nproc) - 1 : 1 ))

if [ ! -d "${RPMSG_DIR}" ]; then
    log_error "ti-rpmsg-char source directory not found: ${RPMSG_DIR}"
    exit 1
fi

SECONDS=0

log_info "Building ti-rpmsg-char with ${NPROC} parallel jobs..."
log_info "Source dir : ${RPMSG_DIR}"

cd "${RPMSG_DIR}"

log_info "Running autoreconf..."
autoreconf -i

log_info "Running configure for aarch64..."
./configure --host=aarch64-none-linux-gnu --prefix=/usr

log_info "Compiling..."
make -j"${NPROC}"

chmod -R a+w "${WORKDIR}/workarea"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
