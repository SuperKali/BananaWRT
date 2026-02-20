#!/bin/bash
#
# logging.sh - Standardized logging library for BananaWRT
#
# This library provides consistent logging functions with:
# - Terminal color detection
# - Log level support (DEBUG, INFO, SUCCESS, WARNING, ERROR)
# - Backward-compatible aliases
#
# Usage:
#   source "/path/to/lib/logging.sh"
#   log_info "Starting operation..."
#   log_success "Operation completed!"
#

# Prevent multiple sourcing
[[ -n "${_BANANAWRT_LOGGING_LOADED:-}" ]] && return 0
_BANANAWRT_LOGGING_LOADED=1

# Log levels
declare -r LOG_LEVEL_DEBUG=0
declare -r LOG_LEVEL_INFO=1
declare -r LOG_LEVEL_SUCCESS=2
declare -r LOG_LEVEL_WARNING=3
declare -r LOG_LEVEL_ERROR=4

# Current log level (can be overridden via environment)
declare -g BANANAWRT_LOG_LEVEL="${BANANAWRT_LOG_LEVEL:-$LOG_LEVEL_DEBUG}"

# Detect terminal color support
_detect_color_support() {
    local colors=0

    # Check for CI environments that support colors (GitHub Actions, GitLab CI, etc.)
    if [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${GITLAB_CI:-}" ]] || [[ -n "${FORCE_COLOR:-}" ]]; then
        colors=256
    # Check if stdout is a terminal
    elif [[ -t 1 ]]; then
        # Check for COLORTERM variable (true color support)
        if [[ "${COLORTERM:-}" =~ (truecolor|24bit) ]]; then
            colors=16777216
        # Check TERM for 256 color support
        elif [[ "${TERM:-}" =~ (xterm-256color|screen-256color|tmux-256color) ]]; then
            colors=256
        # Check tput for color support
        elif command -v tput &>/dev/null && [[ $(tput colors 2>/dev/null) -ge 8 ]]; then
            colors=$(tput colors)
        fi
    fi

    # Allow override via environment variable
    if [[ -n "${NO_COLOR:-}" ]]; then
        colors=0
    fi

    echo "$colors"
}

# Initialize color codes based on terminal support
_init_colors() {
    local colors
    colors=$(_detect_color_support)

    if [[ "$colors" -ge 8 ]]; then
        # ANSI color codes
        declare -g RESET="\e[0m"
        declare -g BOLD="\e[1m"
        declare -g DIM="\e[2m"
        declare -g ITALIC="\e[3m"
        declare -g UNDERLINE="\e[4m"

        # Foreground colors
        declare -g RED="\e[31m"
        declare -g GREEN="\e[32m"
        declare -g YELLOW="\e[33m"
        declare -g BLUE="\e[34m"
        declare -g MAGENTA="\e[35m"
        declare -g CYAN="\e[36m"
        declare -g WHITE="\e[37m"

        # Bright variants
        declare -g BRIGHT_RED="\e[91m"
        declare -g BRIGHT_GREEN="\e[92m"
        declare -g BRIGHT_YELLOW="\e[93m"
        declare -g BRIGHT_BLUE="\e[94m"
        declare -g BRIGHT_MAGENTA="\e[95m"
        declare -g BRIGHT_CYAN="\e[96m"
    else
        # No color support - empty codes
        declare -g RESET=""
        declare -g BOLD=""
        declare -g DIM=""
        declare -g ITALIC=""
        declare -g UNDERLINE=""
        declare -g RED=""
        declare -g GREEN=""
        declare -g YELLOW=""
        declare -g BLUE=""
        declare -g MAGENTA=""
        declare -g CYAN=""
        declare -g WHITE=""
        declare -g BRIGHT_RED=""
        declare -g BRIGHT_GREEN=""
        declare -g BRIGHT_YELLOW=""
        declare -g BRIGHT_BLUE=""
        declare -g BRIGHT_MAGENTA=""
        declare -g BRIGHT_CYAN=""
    fi
}

# Initialize colors on load
_init_colors

# Internal function to format log messages
_format_log() {
    local level="$1"
    local color="$2"
    local symbol="$3"
    local message="$4"

    echo -e "${BOLD}${color}[${symbol}]${RESET} ${message}"
}

# Log level functions
log_debug() {
    [[ $BANANAWRT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] || return 0
    _format_log "DEBUG" "$DIM$CYAN" "DEBUG" "$*"
}

log_info() {
    [[ $BANANAWRT_LOG_LEVEL -le $LOG_LEVEL_INFO ]] || return 0
    _format_log "INFO" "$BLUE" "INFO" "$*"
}

log_success() {
    [[ $BANANAWRT_LOG_LEVEL -le $LOG_LEVEL_SUCCESS ]] || return 0
    _format_log "SUCCESS" "$GREEN" "OK" "$*"
}

log_warning() {
    [[ $BANANAWRT_LOG_LEVEL -le $LOG_LEVEL_WARNING ]] || return 0
    _format_log "WARNING" "$YELLOW" "WARN" "$*" >&2
}

log_error() {
    [[ $BANANAWRT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]] || return 0
    _format_log "ERROR" "$RED" "FAIL" "$*" >&2
}

# Section header for grouping related log messages
log_section() {
    echo -e "${BOLD}${CYAN}--- $* ---${RESET}"
}

# Formatted/dimmed text (for less prominent info)
log_dim() {
    echo -e "${ITALIC}${DIM}${WHITE}$*${RESET}"
}

# Print a banner with ASCII art
print_banner() {
    echo -e "${BOLD}${CYAN}"
    echo "    ____                               _       ______  ______"
    echo "   / __ )____ _____  ____ _____  ____ | |     / / __ \\/_  __/"
    echo "  / __  / __ \`/ __ \\/ __ \`/ __ \\/ __ \`/ | /| / / /_/ / / /   "
    echo " / /_/ / /_/ / / / / /_/ / / / / /_/ /| |/ |/ / _, _/ / /    "
    echo "/_____/\\__,_/_/ /_/\\__,_/_/ /_/\\__,_/ |__/|__/_/ |_| /_/     "
    echo -e "${BOLD}${YELLOW}          BananaWRT - The Ultimate System Updater       ${RESET}"
    echo ""
}

# Backward-compatible aliases (matching formatter.sh interface)
info() { log_info "$*"; }
success() { log_success "$*"; }
warning() { log_warning "$*"; }
error() { log_error "$*"; }
debug() { log_debug "$*"; }
section() { log_section "$*"; }
formatted_text() { log_dim "$*"; }

# Export functions for use in subshells
export -f log_debug log_info log_success log_warning log_error log_section log_dim print_banner
export -f info success warning error debug section formatted_text
