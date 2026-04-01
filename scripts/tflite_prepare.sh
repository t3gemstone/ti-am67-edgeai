#!/bin/bash
# Clones the TensorFlow repository and applies the pip package build script patch.

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

# --- Configuration ---
WORKAREA="${WORKDIR}/workarea"
TF_DIR="${WORKAREA}/tensorflow"

PATCH_SRC="${WORKAREA}/patches/tensorflow/tensorflow/lite/tools/pip_package/build_pip_package_with_cmake.sh"
PATCH_DST="${TF_DIR}/tensorflow/lite/tools/pip_package/build_pip_package_with_cmake.sh"

# --- Timer Start ---
SECONDS=0

# --- Clone TensorFlow ---
log_info "Cloning TensorFlow repository..."

# Parse repo metadata (repo_url, repo_tag, repo_branch, repo_commit) from config.yaml
extract_repo_info "tensorflow"

cd "${WORKAREA}"

if [ -d "${TF_DIR}" ]; then
    log_warn "TensorFlow directory already exists, skipping clone: ${TF_DIR}"
else
    clone_repo "$repo_url" "$repo_tag" "$repo_branch" "$repo_commit" tensorflow
    log_success "TensorFlow cloned."
fi

# --- Apply Pip Package Build Script Patch ---
# Replaces the upstream build_pip_package_with_cmake.sh with a patched version
# that supports the aarch64 wheel build configuration.
log_info "Patching build_pip_package_with_cmake.sh..."

if [ ! -f "${PATCH_SRC}" ]; then
    log_error "Patch file not found: ${PATCH_SRC}"
    exit 1
fi

copy_and_backup "${PATCH_SRC}" "${PATCH_DST}"
log_success "Patch applied: $(basename "${PATCH_DST}")"

# --- Post-setup Permissions ---
# Grant write access to all users under the workarea (required for CI/CD consumers)
chmod -R a+w "${WORKAREA}"

# --- Summary ---
duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
