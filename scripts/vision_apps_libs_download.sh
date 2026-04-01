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

. /etc/os-release
OS_NAME="${ID}_${VERSION_ID//./_}"

PLATFORMS=(
    j722s
)

DEB_DIR="${WORKDIR}/out"

SECONDS=0

log_info "Resolving download parameters from YAML..."
url=$(get_yaml_value "vision-apps-lib-build" "url")
release=$(get_yaml_value "vision-apps-lib-build" "release")
sdk_ver=$(get_yaml_value "vision-apps-lib-build" "sdk_ver")

log_info "URL     : ${url}"
log_info "Release : ${release}"
log_info "SDK ver : ${sdk_ver}"
log_info "OS      : ${OS_NAME}"
log_info "Platforms: ${PLATFORMS[*]}"

if [ ! -d "${DEB_DIR}" ]; then
    log_error "Output directory does not exist: ${DEB_DIR}"
    exit 1
fi

if [ "$(ls -A "${DEB_DIR}")" ]; then
    log_warn "${DEB_DIR} is not empty — removing existing files..."
    rm -rf "${DEB_DIR:?}"/*
    log_success "Output directory cleared."
fi

current_dir=$(pwd)
cd "${DEB_DIR}"

for platform in "${PLATFORMS[@]}"; do
    deb_pkg="libti-vision-apps-${platform}_${sdk_ver}-${OS_NAME}.deb"
    log_info "Downloading: ${deb_pkg}..."
    if wget -q "${url}/${release}/${deb_pkg}"; then
        log_success "Downloaded: ${deb_pkg}"
    else
        log_error "Failed to download: ${deb_pkg}"
        exit 1
    fi
done

cd "${current_dir}"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
