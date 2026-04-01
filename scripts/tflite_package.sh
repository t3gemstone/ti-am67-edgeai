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
OUT_DIR="${WORKDIR}/out"
LIB_DIR="tensorflow/tflite_build"

TF_VER=$(get_yaml_value "tensorflow" "tf_ver")
if [ -z "${TF_VER}" ]; then
    log_error "Could not read 'tf_ver' for 'tensorflow' from config.yaml."
    exit 1
fi

. /etc/os-release
OS_NAME="${ID}_${VERSION_ID//./_}"

DST_DIR="${WORKAREA}/tflite-${TF_VER}-${OS_NAME}_aarch64"
TFLITE_LIB_DIR="${WORKAREA}/${LIB_DIR}"

SECONDS=0

log_info "Packaging TFLite ${TF_VER} for ${OS_NAME} aarch64..."
log_info "Source lib dir : ${TFLITE_LIB_DIR}"
log_info "Staging dir    : ${DST_DIR}"
log_info "Output dir     : ${OUT_DIR}"

if [ ! -f "${TFLITE_LIB_DIR}/libtensorflow-lite.a" ]; then
    log_error "libtensorflow-lite.a not found in: ${TFLITE_LIB_DIR}"
    exit 1
fi

log_info "Preparing staging directory structure..."
rm -rf "${DST_DIR}"
mkdir -p \
    "${DST_DIR}/usr/include/tflite_${TF_VER}" \
    "${DST_DIR}/usr/include/tensorflow/third_party" \
    "${DST_DIR}/usr/include/tensorflow/tensorflow/lite" \
    "${DST_DIR}/usr/lib/tflite_${TF_VER}" \
    "${DST_DIR}/DEBIAN"

log_info "Copying main static library..."
cp "${TFLITE_LIB_DIR}/libtensorflow-lite.a" "${DST_DIR}/usr/lib/"

log_info "Copying dependency static libraries from _deps..."
(cd "${TFLITE_LIB_DIR}/_deps" && find . -name '*.a' -print | tar --create --files-from -) \
    | (cd "${DST_DIR}/usr/lib/tflite_${TF_VER}" && tar xp)

log_info "Copying pthreadpool static libraries..."
(cd "${TFLITE_LIB_DIR}" && find pthreadpool -name '*.a' -print | tar --create --files-from -) \
    | (cd "${DST_DIR}/usr/lib/tflite_${TF_VER}" && tar xp)

log_info "Flattening library subdirectories..."
for dir in "${DST_DIR}/usr/lib/tflite_${TF_VER}"/*/; do
    if [ -d "${dir}" ]; then
        find "${dir}" -name "*.a" -exec mv {} "${dir}" \;
    fi
done

if [ -d "${DST_DIR}/usr/lib/tflite_${TF_VER}/ruy_build/ruy" ]; then
    log_info "Flattening ruy_build directory..."
    cp -r "${DST_DIR}/usr/lib/tflite_${TF_VER}/ruy_build/ruy/"* \
          "${DST_DIR}/usr/lib/tflite_${TF_VER}/ruy_build/"
fi

log_info "Copying third_party header files..."
(cd "${WORKAREA}/tensorflow/third_party" && find . -name '*.h' -print | tar --create --files-from -) \
    | (cd "${DST_DIR}/usr/include/tensorflow/third_party" && tar xp)

log_info "Copying TFLite header files..."
(cd "${WORKAREA}/tensorflow/tensorflow/lite" && find . -name '*.h' -print | tar --create --files-from -) \
    | (cd "${DST_DIR}/usr/include/tensorflow/tensorflow/lite" && tar xp)

log_info "Writing DEBIAN/control..."
cat > "${DST_DIR}/DEBIAN/control" <<EOF
Package: t3-libtensorflow-lite-dev
Version: ${TF_VER}-1
Section: libdevel
Priority: optional
Architecture: arm64
Maintainer: T3 Gemstone Project Development Team <support@t3gemstone.org>
Description: TensorFlow Lite static development libraries
 Static libraries and headers for TensorFlow Lite ${TF_VER}.
EOF

mkdir -p "${OUT_DIR}"
DEB_PATH="${OUT_DIR}/tflite-${TF_VER}-${OS_NAME}_aarch64.deb"
log_info "Building .deb package: ${DEB_PATH}"
dpkg-deb --build "${DST_DIR}" "${DEB_PATH}"
log_success "Package ready: ${DEB_PATH}"

log_info "Searching for tflite_runtime wheel..."
WHL_SEARCH_DIR="${WORKAREA}/tensorflow/tensorflow/lite/tools/pip_package/gen/tflite_pip/python3/dist"

if [ ! -d "${WHL_SEARCH_DIR}" ]; then
    log_error "Wheel search directory not found: ${WHL_SEARCH_DIR}"
    exit 1
fi

whl_path=$(find "${WHL_SEARCH_DIR}" -name "tflite_runtime*.whl" | head -n 1)

if [ -z "${whl_path}" ]; then
    log_error "tflite_runtime wheel not found in: ${WHL_SEARCH_DIR}"
    exit 1
fi

log_info "Found wheel: ${whl_path}"
cp "${whl_path}" "${OUT_DIR}/"
log_success "Wheel copied to: ${OUT_DIR}/$(basename "${whl_path}")"

chmod -R a+w "${WORKAREA}"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
