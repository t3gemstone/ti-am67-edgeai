#!/bin/bash
# Builds TIDL runtime modules: TIDL-RT, TFLite-RT delegate, and ONNX-RT execution provider.

if [ ! -f /.dockerenv ]; then
    echo "ERROR: This script must be run inside the osrt-build Docker container." >&2
    exit 1
fi

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

WORKAREA="${WORKDIR}/workarea"
TIDL_DIR="${WORKAREA}/arm-tidl"
TARGET_FS=""

protobuf_ver=$(get_yaml_value "onnxruntime" "protobuf_ver")
if [ -z "${protobuf_ver}" ]; then
    log_error "Could not read 'protobuf_ver' for 'onnxruntime' from config.yaml."
    exit 1
fi

export CONCERTO_ROOT="${WORKAREA}/concerto"

PLATFORMS=(
    j722s
)

if [ ! -d "${TIDL_DIR}" ]; then
    log_error "arm-tidl directory not found: ${TIDL_DIR}"
    exit 1
fi

if [ ! -d "${CONCERTO_ROOT}" ]; then
    log_error "concerto directory not found: ${CONCERTO_ROOT}"
    exit 1
fi

SECONDS=0

log_info "Building TIDL runtime modules..."
log_info "TIDL dir      : ${TIDL_DIR}"
log_info "CONCERTO root : ${CONCERTO_ROOT}"
log_info "protobuf ver  : ${protobuf_ver}"
log_info "Platforms     : ${PLATFORMS[*]}"

cd "${TIDL_DIR}"

log_info "Scrubbing previous build artifacts..."
make rt_scrub tfl_delegate_scrub onnxrt_ep_scrub
log_success "Scrub complete."

for platform in "${PLATFORMS[@]}"; do
    log_info "----------------------------------------"
    log_info " Building for platform: ${platform}"
    log_info "----------------------------------------"

    log_info "Cleaning previous build for ${platform}..."
    make rt_clean tfl_delegate_clean onnxrt_ep_clean

    make -C "${TIDL_DIR}" \
        PSDK_INSTALL_PATH="${WORKAREA}/" \
        IVISION_PATH="${TARGET_FS}/usr/include/processor_sdk/ivision" \
        VISION_APPS_PATH="${TARGET_FS}/usr/include/processor_sdk/vision_apps" \
        APP_UTILS_PATH="${TARGET_FS}/usr/include/processor_sdk/app_utils" \
        TIOVX_PATH="${TARGET_FS}/usr/include/processor_sdk/tiovx" \
        LINUX_FS_PATH="${TARGET_FS}" \
        CONCERTO_ROOT="${CONCERTO_ROOT}" \
        TF_REPO_PATH="${WORKAREA}/tensorflow" \
        ONNX_REPO_PATH="${WORKAREA}/onnxruntime" \
        TIDL_PROTOBUF_PATH="${WORKAREA}/protobuf-${protobuf_ver}" \
        GCC_LINUX_ARM_ROOT=/usr \
        TARGET_SOC="${platform}" \
        CROSS_COMPILE_LINARO= \
        LINUX_SYSROOT_ARM="${TARGET_FS}" \
        TREAT_WARNINGS_AS_ERROR=0

    log_success "Build complete for platform: ${platform}"
done

chmod -R a+w "${WORKAREA}"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
