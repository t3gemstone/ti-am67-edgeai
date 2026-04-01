#!/usr/bin/env bash
# ============================================================
# TI ModelZoo Artifact Downloader
# - Looks up run_dir from artifacts.csv by model_name
# - Downloads <run_dir>.tar.gz and extracts into <model_name>/
# ============================================================

set -euo pipefail

# ---- Configuration -----------------------------------------
CSV_URL="https://downloads.ti.com/jacinto7/esd/modelzoo/11_00_00_00/modelartifacts/AM67A/8bits/artifacts.csv"
BASE_DOWNLOAD_URL="http://software-dl.ti.com/jacinto7/esd/modelzoo/11_00_00_00/modelartifacts/AM67A/8bits"
OUTPUT_DIR="$WORKDIR/workarea/model_zoo"
# ------------------------------------------------------------

# ---- Model list to download --------------------------------
MODELS=(
    "ONR-CL-6360-regNetx-200mf"
    "ONR-KD-7060-human-pose-yolox-s-640x640"
    "ONR-OD-8020-ssd-lite-mobv2-mmdet-coco-512x512"
    "ONR-OD-8200-yolox-nano-lite-mmdet-coco-416x416"
    "ONR-OD-8220-yolox-s-lite-mmdet-coco-640x640"
    "ONR-OD-8420-yolox-s-lite-mmdet-widerface-640x640"
    "ONR-SS-7618-deeplabv3lite-mobv2-qat-robokit-768x432"
    "ONR-SS-8610-deeplabv3lite-mobv2-ade20k32-512x512"
    "TFL-CL-0000-mobileNetV1-mlperf"
    "TFL-OD-2020-ssdLite-mobDet-DSP-coco-320x320"
    "TFL-SS-2580-deeplabv3_mobv2-ade20k32-mlperf-512x512"
    "TVM-CL-3090-mobileNetV2-tv"
    "TVM-OD-5120-ssdLite-mobDet-DSP-coco-320x320"
    "TVM-SS-5710-deeplabv3lite-mobv2-cocoseg21-512x512"
)
# ------------------------------------------------------------

# Colored output
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# Check required tools
for cmd in curl awk tar; do
    command -v "$cmd" &>/dev/null || { log_error "'$cmd' not found. Please install it."; exit 1; }
done

mkdir -p "$OUTPUT_DIR"

# ---- Download CSV ------------------------------------------
log_info "Fetching CSV: $CSV_URL"
TMP_CSV="$(mktemp /tmp/artifacts_XXXXXX.csv)"
trap 'rm -f "$TMP_CSV"' EXIT

if ! curl -fsSL "$CSV_URL" -o "$TMP_CSV"; then
    log_error "Failed to download CSV. Please check the URL."
    exit 1
fi
log_success "CSV downloaded. $(wc -l < "$TMP_CSV") lines found."

# ---- Find column indices for model_name and run_dir --------
HEADER=$(head -1 "$TMP_CSV")

MODEL_NAME_COL=$(echo "$HEADER" | awk -F',' '{
    for(i=1;i<=NF;i++) { gsub(/["\r ]/,"",$i); if($i=="model_name") { print i; exit } }
}')

RUN_DIR_COL=$(echo "$HEADER" | awk -F',' '{
    for(i=1;i<=NF;i++) { gsub(/["\r ]/,"",$i); if($i=="run_dir") { print i; exit } }
}')

if [[ -z "$MODEL_NAME_COL" ]]; then
    log_error "'model_name' column not found in CSV header."
    log_warn "Available headers: $HEADER"
    exit 1
fi

if [[ -z "$RUN_DIR_COL" ]]; then
    log_error "'run_dir' column not found in CSV header."
    log_warn "Available headers: $HEADER"
    exit 1
fi

log_info "'model_name' at column $MODEL_NAME_COL, 'run_dir' at column $RUN_DIR_COL"
echo ""

# ---- Process each model ------------------------------------
SUCCESS=0
FAIL=0
SKIP=0

for MODEL_NAME in "${MODELS[@]}"; do

    # Look up run_dir for this model_name
    RUN_DIR=$(awk -F',' -v col_m="$MODEL_NAME_COL" -v col_r="$RUN_DIR_COL" -v target="$MODEL_NAME" '
        NR>1 {
            m=$col_m; r=$col_r
            gsub(/["\r ]/,"",m); gsub(/["\r ]/,"",r)
            if(m==target) { print r; exit }
        }
    ' "$TMP_CSV")

    if [[ -z "$RUN_DIR" ]]; then
        log_error "model_name not found in CSV: $MODEL_NAME"
        (( FAIL++ )) || true
        continue
    fi

    log_info "[$MODEL_NAME] -> run_dir: $RUN_DIR"

    TAR_NAME="${RUN_DIR}.tar.gz"
    DEST="${OUTPUT_DIR}/${TAR_NAME}"
    EXTRACT_DIR="${OUTPUT_DIR}/${MODEL_NAME}"
    URL="${BASE_DOWNLOAD_URL}/${TAR_NAME}"

    DOWNLOAD_OK=true

    # ---- Download ----
    if [[ -f "$DEST" ]]; then
        log_warn "Already exists, skipping download: $TAR_NAME"
        (( SKIP++ )) || true
    else
        log_info "Downloading: $URL"
        if curl -fL --progress-bar "$URL" -o "$DEST"; then
            log_success "Downloaded: $TAR_NAME"
            (( SUCCESS++ )) || true
        else
            log_error "Download failed: $TAR_NAME"
            rm -f "$DEST"
            (( FAIL++ )) || true
            DOWNLOAD_OK=false
        fi
    fi

    # ---- Extract ----
    if [[ "$DOWNLOAD_OK" == true ]]; then
        if [[ -d "$EXTRACT_DIR" ]]; then
            log_warn "Directory already exists, skipping extraction: $EXTRACT_DIR"
        else
            log_info "Extracting: $TAR_NAME -> $EXTRACT_DIR/"
            mkdir -p "$EXTRACT_DIR"
            if tar -xzf "$DEST" -C "$EXTRACT_DIR" 2>/dev/null; then
                log_success "Extracted: $EXTRACT_DIR/"
            else
                log_error "Extraction failed: $TAR_NAME (file may be corrupt)"
                rm -rf "$EXTRACT_DIR"
                (( FAIL++ )) || true
            fi
        fi
    fi

done

rm -rf $OUTPUT_DIR/*.tar.gz
# ---- Summary -----------------------------------------------
echo ""
echo "=============================="
echo -e "  ${GREEN}Succeeded:${NC} $SUCCESS"
echo -e "  ${YELLOW}Skipped  :${NC} $SKIP"
echo -e "  ${RED}Failed   :${NC} $FAIL"
echo "=============================="
log_info "Output directory: $OUTPUT_DIR/"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
