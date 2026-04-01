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
APP_STACK_DIR="${WORKAREA}/edgeai-app-stack"
MODEL_ZOO_URL="https://packages.t3gemstone.org/sdk/models/model_zoo.tar.xz"
MODEL_ZOO_ARCHIVE="${WORKAREA}/model_zoo.tar.xz"

PKG_VERSION="11.0"
PKG_ARCHITECTURE="arm64"
PKG_MAINTAINER="T3 Gemstone Project Development Team <support@t3gemstone.org>"
PKG_DEPENDS="arm-tidl-j722s, edgeai-apps-utils, edgeai-dl-inferer, edgeai-tiovx-kernels, \
edgeai-tiovx-modules, t3-gstreamer, edgeai-gst-plugins, t3-libtensorflow-lite-dev, \
libti-vision-apps-j722s, t3-onnxruntime, ti-rpmsg-char, t3-v4l2-utils, libyaml-cpp-dev, \
libopencv-dev, libncurses-dev, python3-pip, libegl1, libgles2, libgbm1, libgudev-1.0-0"

. /etc/os-release
OS_NAME="${ID}_${VERSION_ID//./_}"

DST_DIR="${WORKAREA}/t3-edgeai-dev-${OS_NAME}_aarch64"
DEB_NAME="t3-edgeai-dev-${OS_NAME}_aarch64.deb"

if [ ! -d "${APP_STACK_DIR}" ]; then
    log_error "edgeai-app-stack directory not found: ${APP_STACK_DIR}"
    log_error "Make sure install_and_clone.sh has been run first."
    exit 1
fi

if [ ! -d "${OUT_DIR}" ] || [ -z "$(ls "${OUT_DIR}"/*.whl 2>/dev/null)" ]; then
    log_error "No .whl files found in: ${OUT_DIR}"
    log_error "Make sure all package build scripts have been run first."
    exit 1
fi

SECONDS=0

log_info "Assembling t3-edgeai-dev package..."
log_info "App stack  : ${APP_STACK_DIR}"
log_info "Staging dir: ${DST_DIR}"
log_info "Output dir : ${OUT_DIR}"

log_info "Preparing staging directory structure..."
rm -rf "${DST_DIR}"
mkdir -p \
    "${DST_DIR}/DEBIAN" \
    "${DST_DIR}/opt/whl_packages"

log_info "Downloading model_zoo archive..."
rm -f "${MODEL_ZOO_ARCHIVE}"
wget --show-progress "${MODEL_ZOO_URL}" -P "${WORKAREA}/"
log_success "model_zoo downloaded."

log_info "Copying edgeai-app-stack assets..."
cp -r "${APP_STACK_DIR}/edgeai-gst-apps"   "${DST_DIR}/opt/"
cp -r "${APP_STACK_DIR}/edgeai-test-data"  "${DST_DIR}/opt/"
cp -r "${APP_STACK_DIR}/imaging"           "${DST_DIR}/opt/"
cp -r "${APP_STACK_DIR}/vision_apps"       "${DST_DIR}/opt/"
cp    "${APP_STACK_DIR}/vx_app_arm_remote_log.out" "${DST_DIR}/opt/"
log_success "App stack assets copied."

log_info "Extracting model_zoo archive..."
tar -xJf "${MODEL_ZOO_ARCHIVE}" -C "${DST_DIR}/opt/"
log_success "model_zoo extracted."

log_info "Copying Python wheels..."
cp "${OUT_DIR}"/*.whl "${DST_DIR}/opt/whl_packages/"

chmod -x "${DST_DIR}/opt/whl_packages/"*.whl
log_success "Python wheels copied."

log_info "Writing t3-edgeai-env script..."
cat > "${DST_DIR}/opt/t3-edgeai-env" <<'EOF'
#!/bin/bash
export CPLUS_INCLUDE_PATH=/usr/local/include/gstreamer-1.0:${CPLUS_INCLUDE_PATH:-}
export LIBRARY_PATH=/usr/local/lib/python3.10/dist-packages/dlr:${LIBRARY_PATH:-}
export LD_LIBRARY_PATH=/usr/local/lib/python3.10/dist-packages/dlr:${LD_LIBRARY_PATH:-}
export GST_PLUGIN_PATH=/usr/local/lib/aarch64-linux-gnu/gstreamer-1.0
export EDGEAI_GST_APPS_PATH=/opt/edgeai-gst-apps
export OOB_DEMO_ASSETS_PATH=/opt/oob-demo-assets
export MODEL_ZOO_PATH=/opt/model_zoo
export EDGEAI_DATA_PATH=/opt/edgeai-test-data
export EDGEAI_SDK_VERSION=11_00_00
export EDGEAI_VERSION=11.0
export SOC=j722s
export DEVICE_NAME=AM67A
export PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h(edge-ai)\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
echo -e "\033[1;32m[INFO] T3 EdgeAI environment successfully loaded!\033[0m"
echo -e "\033[1;34mSOC: ${SOC} | DEVICE: ${DEVICE_NAME} | SDK: ${EDGEAI_SDK_VERSION}\033[0m"
EOF
chmod +x "${DST_DIR}/opt/t3-edgeai-env"
log_success "t3-edgeai-env written."

log_info "Writing DEBIAN/control..."
cat > "${DST_DIR}/DEBIAN/control" <<EOF
Package: t3-edgeai-dev
Version: ${PKG_VERSION}
Section: misc
Priority: optional
Architecture: ${PKG_ARCHITECTURE}
Maintainer: ${PKG_MAINTAINER}
Depends: ${PKG_DEPENDS}
Description: T3 EdgeAI development package with necessary libraries, header files and tools
 for T3 EdgeAI application development.
EOF

log_info "Writing DEBIAN/postinst..."
cat > "${DST_DIR}/DEBIAN/postinst" <<'EOF'
#!/bin/bash
set -e
pip3 install /opt/whl_packages/*.whl
exit 0
EOF
chmod 755 "${DST_DIR}/DEBIAN/postinst"
log_success "DEBIAN files written."

mkdir -p "${OUT_DIR}"
log_info "Building .deb package: ${DEB_NAME}"
dpkg-deb --build "${DST_DIR}" "${OUT_DIR}/${DEB_NAME}"
log_success "Package ready: ${OUT_DIR}/${DEB_NAME}"

chmod -R a+w "${WORKAREA}"

duration=${SECONDS}
log_success "$(basename "$0"): Completed in $(( duration / 60 )) minutes and $(( duration % 60 )) seconds."
