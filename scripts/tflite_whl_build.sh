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

TF_DIR="${WORKDIR}/workarea/tensorflow"
OUT_DIR="${WORKDIR}/out"
BUILD_SCRIPT="${TF_DIR}/tensorflow/lite/tools/pip_package/build_pip_package_with_cmake.sh"

BUILD_NUM_JOBS=$(( $(nproc) > 1 ? $(nproc) - 1 : 1 ))

if [ ! -d "${TF_DIR}" ]; then
    log_error "TensorFlow source directory not found: ${TF_DIR}"
    log_error "Make sure tflite_prepare.sh has been run first."
    exit 1
fi

if [ ! -f "${BUILD_SCRIPT}" ]; then
    log_error "Pip package build script not found: ${BUILD_SCRIPT}"
    log_error "Make sure tflite_prepare.sh has been run and the patch was applied."
    exit 1
fi

SECONDS=0

log_info "Building TFLite Python wheel for aarch64..."
log_info "Source dir : ${TF_DIR}"
log_info "Build jobs : ${BUILD_NUM_JOBS}"
log_info "Output dir : ${OUT_DIR}"

cd "${TF_DIR}"

PYTHON=python3 BUILD_NUM_JOBS="${BUILD_NUM_JOBS}" "${BUILD_SCRIPT}" aarch64

log_info "Moving wheel to output directory..."

whl_files=("${TF_DIR}"/tflite_runtime-*.whl)
if [ ! -e "${whl_files[0]}" ]; then
    log_error "No tflite_runtime wheel found in: ${TF_DIR}"
    exit 1
fi

mkdir -p "${OUT_DIR}"
mv "${whl_files[@]}" "${OUT_DIR}/"
log_success "Wheel(s) moved to: ${OUT_DIR}"

chmod -R a+w "${WORKDIR}/workarea"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
