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
OUT_DIR="${WORKDIR}/out"
LIB_DIR="${WORKAREA}/onnxruntime/build/Linux/Release"
WHL_SEARCH_DIR="${LIB_DIR}/dist"

onnx_ver=$(get_yaml_value "onnxruntime" "onnx_ver")
if [ -z "${onnx_ver}" ]; then
    log_error "Could not read 'onnx_ver' for 'onnxruntime' from config.yaml."
    exit 1
fi

. /etc/os-release
OS_NAME="${ID}_${VERSION_ID//./_}"

DST_DIR="${WORKAREA}/onnx-${onnx_ver}-${OS_NAME}_aarch64"
DEB_NAME="onnx-${onnx_ver}-${OS_NAME}_aarch64.deb"
SRC_LIB="${LIB_DIR}/libonnxruntime.so.${onnx_ver}"

if [ ! -f "${SRC_LIB}" ]; then
    log_error "Shared library not found: ${SRC_LIB}"
    exit 1
fi

if [ ! -d "${WORKAREA}/onnxruntime" ]; then
    log_error "ONNXRuntime source directory not found: ${WORKAREA}/onnxruntime"
    exit 1
fi

SECONDS=0

log_info "Packaging ONNXRuntime ${onnx_ver} for ${OS_NAME} aarch64..."
log_info "Source lib dir : ${LIB_DIR}"
log_info "Staging dir    : ${DST_DIR}"
log_info "Output dir     : ${OUT_DIR}"

log_info "Preparing staging directory structure..."
rm -rf "${DST_DIR}"
mkdir -p \
    "${DST_DIR}/usr/include/onnxruntime" \
    "${DST_DIR}/usr/lib" \
    "${DST_DIR}/DEBIAN"

log_info "Copying shared library: $(basename "${SRC_LIB}")"

cp "${SRC_LIB}" "${DST_DIR}/usr/lib/libonnxruntime.so"
log_success "Shared library copied."

log_info "Copying header files from onnxruntime source tree..."
(cd "${WORKAREA}/onnxruntime" && find . -name '*.h' -print | tar --create --files-from -) \
    | (cd "${DST_DIR}/usr/include/onnxruntime" && tar xp)
log_success "Header files copied."

log_info "Writing DEBIAN/control..."
cat > "${DST_DIR}/DEBIAN/control" <<EOF
Package: t3-onnxruntime
Version: ${onnx_ver}-1
Section: libdevel
Priority: optional
Architecture: arm64
Maintainer: T3 Gemstone Project Development Team <support@t3gemstone.org>
Description: ONNX Runtime development headers and shared library for ARM64 architecture.
EOF

mkdir -p "${OUT_DIR}"
log_info "Building .deb package: ${DEB_NAME}"
dpkg-deb --build "${DST_DIR}" "${OUT_DIR}/${DEB_NAME}"
log_success "Package ready: ${OUT_DIR}/${DEB_NAME}"

log_info "Searching for onnxruntime_tidl wheel in: ${WHL_SEARCH_DIR}"

if [ ! -d "${WHL_SEARCH_DIR}" ]; then
    log_error "Wheel search directory not found: ${WHL_SEARCH_DIR}"
    exit 1
fi

whl_path=$(find "${WHL_SEARCH_DIR}" -name "onnxruntime_tidl-*.whl" | head -n 1)

if [ -z "${whl_path}" ]; then
    log_error "onnxruntime_tidl wheel not found in: ${WHL_SEARCH_DIR}"
    exit 1
fi

log_info "Found wheel: ${whl_path}"
cp "${whl_path}" "${OUT_DIR}/"
log_success "Wheel copied to: ${OUT_DIR}/$(basename "${whl_path}")"

chmod -R a+w "${WORKAREA}"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
