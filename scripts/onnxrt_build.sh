#!/bin/bash

if [ -z "${WORKDIR:-}" ]; then
    echo "ERROR: WORKDIR environment variable is not set." >&2
    exit 1
fi

source "${WORKDIR}/scripts/logging.sh"

UTILS_SCRIPT="${WORKDIR}/scripts/utils.sh"
if [ ! -f "${UTILS_SCRIPT}" ]; then
    log_error "Utility script not found: ${UTILS_SCRIPT}"
    exit 1
fi
source "${UTILS_SCRIPT}"

ONNX_DIR="${WORKDIR}/workarea/onnxruntime"

NPROC=$(( $(nproc) > 1 ? $(nproc) - 1 : 1 ))

protobuf_ver=$(get_yaml_value "onnxruntime" "protobuf_ver")
if [ -z "${protobuf_ver}" ]; then
    log_error "Could not read 'protobuf_ver' for 'onnxruntime' from config.yaml."
    exit 1
fi

PROTOC_BIN="${ONNX_DIR}/cmake/external/protoc-${protobuf_ver}-linux-aarch_64/bin/protoc"
TOOLCHAIN_FILE="${ONNX_DIR}/tool.cmake"

if [ ! -d "${ONNX_DIR}" ]; then
    log_error "ONNXRuntime source directory not found: ${ONNX_DIR}"
    exit 1
fi

if [ ! -f "${TOOLCHAIN_FILE}" ]; then
    log_error "CMake toolchain file not found: ${TOOLCHAIN_FILE}"
    exit 1
fi

if [ ! -f "${PROTOC_BIN}" ]; then
    log_error "protoc binary not found: ${PROTOC_BIN}"
    exit 1
fi

SECONDS=0

log_info "Building ONNXRuntime with ${NPROC} parallel jobs..."
log_info "Source dir   : ${ONNX_DIR}"
log_info "protobuf ver : ${protobuf_ver}"
log_info "protoc path  : ${PROTOC_BIN}"

cd "${ONNX_DIR}"

./build.sh \
    --parallel "${NPROC}" \
    --compile_no_warning_as_error \
    --skip_tests \
    --enable_onnx_tests \
    --build_shared_lib \
    --config Release \
    --cmake_extra_defines="CMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE}" \
    --path_to_protoc_exe "${PROTOC_BIN}" \
    --use_tidl \
    --build_wheel \
    --allow_running_as_root

chmod -R a+w "${WORKDIR}/workarea"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
