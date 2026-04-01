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

WORKAREA="${WORKDIR}/workarea"
ONNX_DIR="${WORKAREA}/onnxruntime"
PATCH_TOOLCHAIN="${WORKAREA}/patches/onnxruntime/tool.cmake"

protobuf_ver=$(get_yaml_value "onnxruntime" "protobuf_ver")
protobuf_ver_rel=$(get_yaml_value "onnxruntime" "protobuf_ver_rel")

if [ -z "${protobuf_ver}" ] || [ -z "${protobuf_ver_rel}" ]; then
    log_error "Could not read protobuf version(s) for 'onnxruntime' from config.yaml."
    exit 1
fi

PROTOC_DIR="${ONNX_DIR}/cmake/external/protoc-${protobuf_ver}-linux-aarch_64"
PROTOC_ZIP="protoc-${protobuf_ver_rel}-linux-aarch_64.zip"
PROTOC_URL="https://github.com/protocolbuffers/protobuf/releases/download/v${protobuf_ver_rel}/${PROTOC_ZIP}"

SECONDS=0

extract_repo_info "onnxruntime"

cd "${WORKAREA}"

if [ -d "${ONNX_DIR}" ]; then
    log_warn "ONNXRuntime directory already exists, skipping clone: ${ONNX_DIR}"
else
    log_info "Cloning ONNXRuntime repository..."
    clone_repo "$repo_url" "$repo_tag" "$repo_branch" "$repo_commit" onnxruntime
    log_success "ONNXRuntime cloned."
fi

log_info "Initializing submodules..."
cd "${ONNX_DIR}"
git submodule update --init --recursive
log_success "Submodules initialized."

log_info "Patching tool.cmake..."
if [ ! -f "${PATCH_TOOLCHAIN}" ]; then
    log_error "Toolchain patch not found: ${PATCH_TOOLCHAIN}"
    exit 1
fi

if [ -f "tool.cmake" ]; then
    mv tool.cmake tool.cmake.ORG
    log_warn "Original tool.cmake backed up as tool.cmake.ORG"
fi
cp "${PATCH_TOOLCHAIN}" tool.cmake
log_success "tool.cmake patched."

cd "${WORKAREA}"

if [ -d "${PROTOC_DIR}" ]; then
    log_warn "protoc already installed, skipping download: ${PROTOC_DIR}"
else
    log_info "Downloading protoc ${protobuf_ver_rel}..."
    if ! curl -fSL -O "${PROTOC_URL}"; then
        log_error "Failed to download: ${PROTOC_URL}"
        exit 1
    fi

    log_info "Extracting ${PROTOC_ZIP} to ${PROTOC_DIR}..."
    if ! unzip "${PROTOC_ZIP}" -d "${PROTOC_DIR}"; then
        log_error "Failed to extract: ${PROTOC_ZIP}"
        rm -f "${PROTOC_ZIP}"
        exit 1
    fi

    rm -f "${PROTOC_ZIP}"
    log_success "protoc ${protobuf_ver_rel} installed to: ${PROTOC_DIR}"
fi

chmod -R a+w "${WORKAREA}"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
