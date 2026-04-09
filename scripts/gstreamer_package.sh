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
GST_DIR="${WORKAREA}/gstreamer"
OUT_DIR="${WORKDIR}/out"

PKG_VERSION="1.22.12"
PKG_ARCHITECTURE="arm64"
PKG_MAINTAINER="T3 Gemstone Project Development Team <support@t3gemstone.org>"

if [ ! -d "${GST_DIR}" ]; then
    log_error "GStreamer source directory not found: ${GST_DIR}"
    exit 1
fi

if [ ! -d "${GST_DIR}/builddir" ]; then
    log_error "Meson build directory not found: ${GST_DIR}/builddir"
    exit 1
fi

. /etc/os-release
OS_NAME="${ID}_${VERSION_ID//./_}"

DST_DIR="${GST_DIR}/gstreamer-${OS_NAME}_aarch64"
DEB_NAME="gstreamer-${OS_NAME}_aarch64.deb"

SECONDS=0

log_info "Packaging GStreamer ${PKG_VERSION} for ${OS_NAME} aarch64..."
log_info "Source dir : ${GST_DIR}"
log_info "Staging dir: ${DST_DIR}"
log_info "Output dir : ${OUT_DIR}"

log_info "Preparing staging directory..."
rm -rf "${DST_DIR}"

log_info "Running meson install into staging directory..."
meson install -C "${GST_DIR}/builddir" --destdir="${DST_DIR}"

log_info "Writing DEBIAN/control..."
mkdir -p "${DST_DIR}/DEBIAN"
cat > "${DST_DIR}/DEBIAN/control" <<EOF
Package: t3-gstreamer
Version: ${PKG_VERSION}
Section: libdevel
Priority: optional
Architecture: ${PKG_ARCHITECTURE}
Depends: libglib2.0-dev, pkg-config, libasound2, libpulse0, libxv1
Maintainer: ${PKG_MAINTAINER}
Description: GStreamer multimedia framework for ARM64 architecture.
EOF

mkdir -p "${OUT_DIR}"
log_info "Building .deb package: ${DEB_NAME}"
dpkg-deb --build "${DST_DIR}" "${OUT_DIR}/${DEB_NAME}"
log_success "Package ready: ${OUT_DIR}/${DEB_NAME}"

chmod -R a+w "${WORKAREA}"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
