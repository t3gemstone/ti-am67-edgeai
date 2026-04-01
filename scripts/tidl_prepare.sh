#!/bin/bash
# Prepares all dependencies required for the TIDL build:
# concerto, protobuf source, onnxruntime, tensorflow, and arm-tidl.
#
# Depends: onnxrt_prepare.sh, tflite_prepare.sh, dlr_prepare.sh

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
SCRIPTS_DIR="${WORKDIR}/scripts"

protobuf_ver=$(get_yaml_value "onnxruntime" "protobuf_ver")
if [ -z "${protobuf_ver}" ]; then
    log_error "Could not read 'protobuf_ver' for 'onnxruntime' from config.yaml."
    exit 1
fi

run_prepare() {
    local script="${SCRIPTS_DIR}/$1"
    local description="$2"

    if [ ! -f "${script}" ]; then
        log_error "Prepare script not found: ${script}"
        exit 1
    fi

    log_info "Running: $1 (${description})..."
    bash "${script}"
    log_success "$1 completed."
}

SECONDS=0

cd "${WORKAREA}"

log_info "Checking concerto..."
extract_repo_info "concerto"
CONCERTO_DIR="${WORKAREA}/concerto"

if [ -d "${CONCERTO_DIR}" ]; then
    log_warn "concerto already exists, skipping clone: ${CONCERTO_DIR}"
else
    log_info "Cloning concerto..."
    clone_repo "$repo_url" "$repo_tag" "$repo_branch" "$repo_commit" concerto
    log_success "concerto cloned."
fi

PROTOBUF_DIR="${WORKAREA}/protobuf-${protobuf_ver}"
log_info "Checking protobuf source (v${protobuf_ver})..."

if [ -d "${PROTOBUF_DIR}" ]; then
    log_warn "protobuf source already exists, skipping download: ${PROTOBUF_DIR}"
else
    TARBALL="v${protobuf_ver}.tar.gz"
    TARBALL_URL="https://github.com/protocolbuffers/protobuf/archive/refs/tags/v${protobuf_ver}/${TARBALL}"

    log_info "Downloading protobuf v${protobuf_ver}..."
    if ! wget --quiet --show-progress -O "${TARBALL}" "${TARBALL_URL}"; then
        log_error "Failed to download protobuf tarball: ${TARBALL_URL}"
        exit 1
    fi

    log_info "Extracting ${TARBALL}..."
    tar -xzf "${TARBALL}" -C "${WORKAREA}"
    rm -f "${TARBALL}"
    log_success "protobuf v${protobuf_ver} extracted to: ${PROTOBUF_DIR}"
fi

log_info "Checking onnxruntime..."
if [ -d "${WORKAREA}/onnxruntime" ]; then
    log_warn "onnxruntime already exists, skipping: ${WORKAREA}/onnxruntime"
else
    run_prepare "onnxrt_prepare.sh" "Clone and patch ONNXRuntime"
fi

log_info "Checking tensorflow..."
if [ -d "${WORKAREA}/tensorflow" ]; then
    log_warn "tensorflow already exists, skipping: ${WORKAREA}/tensorflow"
else
    run_prepare "tflite_prepare.sh" "Clone and patch TensorFlow"
fi

log_info "Checking arm-tidl..."
if [ -d "${WORKAREA}/arm-tidl" ]; then
    log_warn "arm-tidl already exists, skipping: ${WORKAREA}/arm-tidl"
else
    run_prepare "dlr_prepare.sh" "Clone neo-ai-dlr and arm-tidl"
fi

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
