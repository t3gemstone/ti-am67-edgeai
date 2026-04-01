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

WORKAREA="${WORKDIR}/workarea"
V4L2_BUILD_DIR="${WORKAREA}/v4l2-utils/build"
OUT_DIR="${WORKDIR}/out"

PKG_VERSION="1.28"
PKG_ARCHITECTURE="arm64"
PKG_MAINTAINER="T3 Gemstone Project Development Team <support@t3gemstone.org>"

if [ ! -d "${V4L2_BUILD_DIR}" ]; then
    log_error "v4l2-utils build directory not found: ${V4L2_BUILD_DIR}"
    log_error "Make sure v4l2_build.sh has been run first."
    exit 1
fi

. /etc/os-release
OS_NAME="${ID}_${VERSION_ID//./_}"

DST_DIR="${WORKAREA}/v4l2-utils-${OS_NAME}_aarch64"
DEB_NAME="v4l2-utils-${OS_NAME}_aarch64.deb"

SECONDS=0

log_info "Packaging v4l2-utils ${PKG_VERSION} for ${OS_NAME} aarch64..."
log_info "Build dir  : ${V4L2_BUILD_DIR}"
log_info "Staging dir: ${DST_DIR}"
log_info "Output dir : ${OUT_DIR}"

log_info "Preparing staging directory..."
rm -rf "${DST_DIR}"
mkdir -p "${DST_DIR}/DEBIAN"

log_info "Running meson install into staging directory..."
meson install -C "${V4L2_BUILD_DIR}" --destdir="${DST_DIR}"
log_success "meson install complete."

log_info "Writing DEBIAN/control..."
cat > "${DST_DIR}/DEBIAN/control" <<EOF
Package: t3-v4l2-utils
Version: ${PKG_VERSION}
Section: utils
Priority: optional
Architecture: ${PKG_ARCHITECTURE}
Maintainer: ${PKG_MAINTAINER}
Description: V4L2 utilities for ARM64 architecture.
EOF

mkdir -p "${OUT_DIR}"
log_info "Building .deb package: ${DEB_NAME}"
dpkg-deb --build "${DST_DIR}" "${OUT_DIR}/${DEB_NAME}"
log_success "Package ready: ${OUT_DIR}/${DEB_NAME}"

chmod -R a+w "${WORKAREA}"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
