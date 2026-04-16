#!/bin/bash

if [ -z "${WORKDIR:-}" ]; then
    echo "ERROR: WORKDIR environment variable is not set." >&2
    exit 1
fi

source "${WORKDIR}/scripts/logging.sh"

PROTOBUF_DIR="${WORKDIR}/workarea/onnxruntime/cmake/external/protobuf"

NPROC=1

if [ ! -d "${PROTOBUF_DIR}" ]; then
    log_error "protobuf source directory not found: ${PROTOBUF_DIR}"
    log_error "Make sure onnxrt_prepare.sh has been run first."
    exit 1
fi

if [ ! -f "${PROTOBUF_DIR}/autogen.sh" ]; then
    log_error "autogen.sh not found in: ${PROTOBUF_DIR}"
    exit 1
fi

SECONDS=0

log_info "Building protobuf from source..."
log_info "Source dir : ${PROTOBUF_DIR}"
log_info "Parallel   : ${NPROC} jobs"

cd "${PROTOBUF_DIR}"

log_info "Running autogen.sh..."
./autogen.sh

log_info "Running configure..."
./configure

log_info "Running make with ${NPROC} jobs..."
make -j"${NPROC}"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
