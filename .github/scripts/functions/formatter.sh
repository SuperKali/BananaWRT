#!/bin/bash
#
# formatter.sh - DEPRECATED: Legacy logging functions
#
# DEPRECATION NOTICE:
#   This file is deprecated and will be removed in a future version.
#   Please use lib/logging.sh instead.
#
#   Migration guide:
#     Old: source "$SCRIPT_DIR/functions/formatter.sh"
#     New: source "${BANANAWRT_ROOT}/lib/logging.sh"
#
#   This file now sources lib/logging.sh for backward compatibility.
#   All function names remain the same.
#
# Deprecated since: 2025-01-20
# Removal planned: 2026-01-01
#

# Determine BANANAWRT_ROOT
if [[ -n "${BANANAWRT_ROOT:-}" ]]; then
    : # Already set
elif [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
    BANANAWRT_ROOT="$GITHUB_WORKSPACE"
else
    _formatter_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BANANAWRT_ROOT="$(cd "${_formatter_dir}/../.." && pwd)"
fi

# Source the new logging library
if [[ -f "${BANANAWRT_ROOT}/lib/logging.sh" ]]; then
    source "${BANANAWRT_ROOT}/lib/logging.sh"
else
    # Fallback: inline minimal implementations if lib/logging.sh not found
    # This maintains backward compatibility in edge cases
    RESET="\e[0m"
    BOLD="\e[1m"
    DIM="\e[2m"
    ITALIC="\e[3m"
    RED="\e[31m"
    GREEN="\e[32m"
    YELLOW="\e[33m"
    BLUE="\e[34m"
    CYAN="\e[36m"
    WHITE="\e[37m"

    info() { echo -e "${BOLD}${BLUE}[INFO]${RESET} $1"; }
    success() { echo -e "${BOLD}${GREEN}[SUCCESS]${RESET} $1"; }
    warning() { echo -e "${BOLD}${YELLOW}[WARNING]${RESET} $1"; }
    error() { echo -e "${BOLD}${RED}[ERROR]${RESET} $1"; }
    debug() { echo -e "${DIM}${CYAN}[DEBUG]${RESET} $1"; }
    section() { echo -e "${BOLD}${CYAN}--- $1 ---${RESET}"; }
    formatted_text() { echo -e "${ITALIC}${DIM}${WHITE}$1${RESET}"; }
fi
