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
source "${WORKDIR}/scripts/utils.sh"

WORKAREA="${WORKDIR}/workarea"

REPO_BASE_URL="https://git.ti.com/cgit/arago-project/meta-arago/plain/meta-arago-extras/recipes-multimedia/v4l2apps/v4l-utils"
REPO_BRANCH="scarthgap"
PATCH_FILES=(
    "0001-media-ctl-Install-media-ctl-header-and-library-files.patch"
    "0002-media-ctl-add-support-for-RGBIr-bayer-formats.patch"
)

SECONDS=0
current_dir=$(pwd)

log_info "Preparing v4l2-utils source tree..."

log_info "Resolving repository info for 'v4l2-utils'..."
extract_repo_info "v4l2-utils"

log_info "Cloning v4l2-utils into ${WORKAREA}..."
mkdir -p "${WORKAREA}"
cd "${WORKAREA}"
rm -rf "${WORKAREA}/v4l2-utils"
clone_repo "$repo_url" "$repo_tag" "$repo_branch" "$repo_commit" v4l2-utils
log_success "Clone complete."

log_info "Applying ${#PATCH_FILES[@]} patch(es) from ${REPO_BASE_URL}..."
cd v4l2-utils
for patch_file in "${PATCH_FILES[@]}"; do
    patch_url="${REPO_BASE_URL}/${patch_file}?h=${REPO_BRANCH}"
    log_info "Downloading patch: ${patch_file}"
    if wget -q -O "${patch_file}" "${patch_url}"; then
        log_info "Applying patch: ${patch_file}"
        if patch -p1 < "${patch_file}"; then
            log_success "Patch applied: ${patch_file}"
        else
            log_error "Failed to apply patch: ${patch_file}"
            exit 1
        fi
    else
        log_error "Failed to download patch: ${patch_file}"
        exit 1
    fi
done

log_info "Fixing permissions on workarea..."
chmod -R a+w "${WORKAREA}"

cd "${current_dir}"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
