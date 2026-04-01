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

# --- Load Utility Functions ---
UTILS_SCRIPT="${WORKDIR}/scripts/utils.sh"
if [ ! -f "${UTILS_SCRIPT}" ]; then
    log_error "Utility script not found: ${UTILS_SCRIPT}"
    exit 1
fi
source "${UTILS_SCRIPT}"

OUT_DIR="${WORKDIR}/out"
WORKAREA="${WORKDIR}/workarea"

SECONDS=0

log_info "Installing .deb packages from: ${OUT_DIR}"

deb_files=("${OUT_DIR}"/*.deb)
if [ ! -e "${deb_files[0]}" ]; then
    log_error "No .deb files found in: ${OUT_DIR}"
    exit 1
fi

log_info "Found ${#deb_files[@]} .deb file(s): ${deb_files[*]}"
dpkg -i "${deb_files[@]}"
log_success ".deb packages installed."

log_info "Installing Python wheel packages from: ${OUT_DIR}"

whl_files=("${OUT_DIR}"/*.whl)
if [ ! -e "${whl_files[0]}" ]; then
    log_warn "No .whl files found in: ${OUT_DIR}, skipping pip install."
else
    log_info "Found ${#whl_files[@]} .whl file(s): ${whl_files[*]}"
    pip3 install "${whl_files[@]}"
    log_success "Python wheels installed."
fi

log_info "Cloning edgeai-app-stack repository..."

extract_repo_info "edgeai-app-stack"

cd "${WORKAREA}"
clone_repo "$repo_url" "$repo_tag" "$repo_branch" "$repo_commit" edgeai-app-stack
log_success "edgeai-app-stack cloned."

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
