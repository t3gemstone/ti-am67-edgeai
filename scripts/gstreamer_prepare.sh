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

UTILS_SCRIPT="${WORKDIR}/scripts/utils.sh"
if [ ! -f "${UTILS_SCRIPT}" ]; then
    log_error "Utility script not found: ${UTILS_SCRIPT}"
    exit 1
fi
source "${UTILS_SCRIPT}"

WORKAREA="${WORKDIR}/workarea"
GST_PLUGINS_DIR="${WORKAREA}/gstreamer/subprojects/gst-plugins-good"

PATCH_BASE_URL="https://git.ti.com/cgit/arago-project/meta-arago/plain/meta-arago-extras/recipes-multimedia/gstreamer/gstreamer1.0-plugins-good"
PATCH_BRANCH="scarthgap"

PATCH_FILES=(
    "0001-Adding-support-for-raw10-raw12-and-raw16-bayer-formats.patch"
    "0001-v4l2jpegenc-Add-support-for-cropping-in-JPEG-Encoder.patch"
    "0002-Adding-support-for-bayer-formats-with-IR-component.patch"
    "0003-v4l2-Changes-for-DMA-Buf-import-j721s2.patch"
    "0004-v4l2-Give-preference-to-contiguous-format-if-support.patch"
    "0005-HACK-gstv4l2object-Increase-min-buffers-for-CSI-capt.patch"
)

SECONDS=0

log_info "Cloning GStreamer repository..."

extract_repo_info "gstreamer"

rm -rf "${WORKAREA}/gstreamer"

cd "${WORKAREA}"
clone_repo "$repo_url" "$repo_tag" "$repo_branch" "$repo_commit" gstreamer
log_success "GStreamer cloned."

log_info "Applying patches to gst-plugins-good..."

if [ ! -d "${GST_PLUGINS_DIR}" ]; then
    log_error "gst-plugins-good directory not found: ${GST_PLUGINS_DIR}"
    exit 1
fi

cd "${GST_PLUGINS_DIR}"

total=${#PATCH_FILES[@]}
index=0

for patch_file in "${PATCH_FILES[@]}"; do
    index=$(( index + 1 ))
    patch_url="${PATCH_BASE_URL}/${patch_file}?h=${PATCH_BRANCH}"

    log_info "[${index}/${total}] Downloading: ${patch_file}"
    if ! wget --quiet --show-progress -O "${patch_file}" "${patch_url}"; then
        log_error "Download failed: ${patch_url}"
        exit 1
    fi

    log_info "[${index}/${total}] Applying: ${patch_file}"
    if ! patch -p1 < "${patch_file}"; then
        log_error "Failed to apply patch: ${patch_file}"
        exit 1
    fi

    log_success "[${index}/${total}] Applied: ${patch_file}"
done

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
