#!/bin/bash

source ${WORKDIR}/scripts/logging.sh

if [ ! -f /.dockerenv ]; then
    log_error "This script must be run inside the osrt-build Docker container."
    exit 1
fi

if [ -z "${WORKDIR:-}" ]; then
    log_error "WORKDIR environment variable is not set."
    exit 1
fi

UTILS_SCRIPT="${WORKDIR}/scripts/utils.sh"
if [ ! -f "${UTILS_SCRIPT}" ]; then
    log_error "Utility script not found: ${UTILS_SCRIPT}"
    exit 1
fi
source "${UTILS_SCRIPT}"

WORKAREA="${WORKDIR}/workarea"
PATCH_CMAKE="${WORKDIR}/patches/neo-ai-dlr/cmake/aarch64-linux-gcc-native.cmake"
NEO_DLR_CMAKE_DIR="${WORKAREA}/neo-ai-dlr/cmake"

SECONDS=0

log_info "Cloning neo-ai-dlr repository..."

extract_repo_info "neo-ai-dlr"
cd "${WORKAREA}"
clone_repo "$repo_url" "$repo_tag" "$repo_branch" "$repo_commit" neo-ai-dlr
log_success "neo-ai-dlr cloned."

log_info "Initializing submodules for neo-ai-dlr..."
cd "${WORKAREA}/neo-ai-dlr"
git submodule update --quiet --init --recursive --depth=1
log_success "Submodules initialized."

log_info "Applying CMake toolchain patch..."
if [ ! -f "${PATCH_CMAKE}" ]; then
    log_error "CMake patch file not found: ${PATCH_CMAKE}"
    exit 1
fi
cp "${PATCH_CMAKE}" "${NEO_DLR_CMAKE_DIR}/"
log_success "CMake toolchain patch applied."

log_info "Cloning arm-tidl repository..."
extract_repo_info "arm-tidl"
cd "${WORKAREA}"
clone_repo "$repo_url" "$repo_tag" "$repo_branch" "$repo_commit" arm-tidl
log_success "arm-tidl cloned."

chmod -R a+w "${WORKAREA}"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
