#!/bin/bash
# Builds the TensorFlow Lite static library (libtensorflow-lite.a) for aarch64 targets.
# Output: <tensorflow_path>/tensorflow/tflite_build/libtensorflow-lite.a

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
BUILD_DIR="${TF_DIR}/tflite_build"
SOURCE_DIR="${TF_DIR}/tensorflow/lite"

NPROC=$(( $(nproc) > 1 ? $(nproc) - 1 : 1 ))

if [ ! -d "${TF_DIR}" ]; then
    log_error "TensorFlow source directory not found: ${TF_DIR}"
    exit 1
fi

if [ ! -d "${SOURCE_DIR}" ]; then
    log_error "TFLite source directory not found: ${SOURCE_DIR}"
    exit 1
fi

# -Wno-error=stringop-overflow is required on Ubuntu 24.04 to suppress a
# compiler error that incorrectly treats this warning as fatal.
ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "")
CMAKE_CXX_FLAGS_EXTRA=""
if [ "${ubuntu_version}" = "24.04" ]; then
    log_warn "Ubuntu 24.04 detected — adding -Wno-error=stringop-overflow workaround."
    CMAKE_CXX_FLAGS_EXTRA="-Wno-error=stringop-overflow"
fi

COMMON_FLAGS="-funsafe-math-optimizations -mno-outline-atomics"

SECONDS=0

log_info "Building TFLite with ${NPROC} parallel jobs..."
log_info "Source dir : ${SOURCE_DIR}"
log_info "Build dir  : ${BUILD_DIR}"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

cmake \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_CXX_COMPILER=g++ \
    -DCMAKE_C_FLAGS="${COMMON_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${COMMON_FLAGS} ${CMAKE_CXX_FLAGS_EXTRA}" \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DTFLITE_ENABLE_XNNPACK=ON \
    "${SOURCE_DIR}"

cmake --build . -j"${NPROC}"

chmod -R a+w "${WORKDIR}/workarea"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
