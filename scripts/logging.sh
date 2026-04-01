#!/bin/bash
# logging.sh — Shared colored logging utilities.
# Usage: source "${WORKDIR}/scripts/logging.sh"

if [ -n "${_LOGGING_SH_LOADED:-}" ]; then
    return 0
fi
_LOGGING_SH_LOADED=1

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
