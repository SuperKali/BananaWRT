#!/usr/bin/env bash
#
# lib/functions.sh — shared helpers (color output, timers, utilities).
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me> — MIT.
#

# CI log viewers render ANSI even though stdout is piped, so force colors
# when CI/GITHUB_ACTIONS is set (unless NO_COLOR is explicit).
_color_enabled=0
if [[ -z "${NO_COLOR:-}" ]]; then
    if [[ -t 1 || -n "${FORCE_COLOR:-}" \
          || "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
        _color_enabled=1
    fi
fi

if (( _color_enabled )); then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'
    C_ITALIC='\033[3m'
    C_RED='\033[31m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_BLUE='\033[34m'
    C_MAGENTA='\033[35m'
    C_CYAN='\033[36m'
    C_WHITE='\033[37m'
    C_GRAY='\033[90m'
else
    C_RESET='' C_BOLD='' C_DIM='' C_ITALIC=''
    C_RED='' C_GREEN='' C_YELLOW='' C_BLUE=''
    C_MAGENTA='' C_CYAN='' C_WHITE='' C_GRAY=''
fi
unset _color_enabled

if [[ "${LANG:-}" == *UTF-8* || "${LC_ALL:-}" == *UTF-8* ]]; then
    G_OK='✓'   G_FAIL='✗'   G_WARN='!'   G_INFO='›'   G_STEP='▸'
    G_DOT='•'  G_ARROW='→'  G_BULLET='─'
    B_TL='╔' B_TR='╗' B_BL='╚' B_BR='╝' B_H='═' B_V='║'
    BS_TL='┌' BS_TR='┐' BS_BL='└' BS_BR='┘' BS_H='─' BS_V='│' BS_L='├' BS_R='┤'
else
    G_OK='[OK]'   G_FAIL='[X]'   G_WARN='[!]'   G_INFO='>'   G_STEP='>'
    G_DOT='*'  G_ARROW='->'  G_BULLET='-'
    B_TL='+' B_TR='+' B_BL='+' B_BR='+' B_H='=' B_V='|'
    BS_TL='+' BS_TR='+' BS_BL='+' BS_BR='+' BS_H='-' BS_V='|' BS_L='+' BS_R='+'
fi

# ──────────────────────────────────────────────────────────────────────────────
#  Display / logging
# ──────────────────────────────────────────────────────────────────────────────
# display_alert <level> <message> [detail]
#   level ∈ { info | ok | warn | err | step | debug }
display_alert() {
    local level="${1:-info}"
    local msg="${2:-}"
    local detail="${3:-}"
    local tag color icon

    case "$level" in
        info)   tag='INFO'   ; color="$C_BLUE"   ; icon="$G_INFO" ;;
        ok)     tag='OK'     ; color="$C_GREEN"  ; icon="$G_OK"   ;;
        warn)   tag='WARN'   ; color="$C_YELLOW" ; icon="$G_WARN" ;;
        err)    tag='ERROR'  ; color="$C_RED"    ; icon="$G_FAIL" ;;
        step)   tag='STEP'   ; color="$C_CYAN"   ; icon="$G_STEP" ;;
        debug)  [[ "${BANANAWRT_DEBUG:-0}" != "1" ]] && return 0
                tag='DEBUG'  ; color="$C_GRAY"   ; icon="$G_DOT"  ;;
        *)      tag='LOG'    ; color="$C_WHITE"  ; icon="$G_INFO" ;;
    esac

    if [[ -n "$detail" ]]; then
        printf '%b%s [%s]%b %s %b(%s)%b\n' \
            "$color$C_BOLD" "$icon" "$tag" "$C_RESET" \
            "$msg" \
            "$C_DIM" "$detail" "$C_RESET"
    else
        printf '%b%s [%s]%b %s\n' \
            "$color$C_BOLD" "$icon" "$tag" "$C_RESET" \
            "$msg"
    fi
}

# display_title <title>
#   Prints a horizontal heavy-box banner section.
display_title() {
    local title="$1"
    local width=72
    local line
    printf -v line '%*s' "$width" ''
    line="${line// /$B_H}"
    printf '\n%b%s%s%s%b\n' "$C_BOLD$C_CYAN" "$B_TL" "$line" "$B_TR" "$C_RESET"
    printf '%b%s%b %-*s %b%s%b\n' \
        "$C_BOLD$C_CYAN" "$B_V" "$C_RESET" \
        $((width - 2)) "$title" \
        "$C_BOLD$C_CYAN" "$B_V" "$C_RESET"
    printf '%b%s%s%s%b\n\n' "$C_BOLD$C_CYAN" "$B_BL" "$line" "$B_BR" "$C_RESET"
}

# display_subheader <text>
display_subheader() {
    printf '\n%b%s %s%b\n' "$C_BOLD$C_MAGENTA" "$G_ARROW" "$1" "$C_RESET"
}

# display_box <title> <line1> [line2...]
#   Lightweight info box for summaries.
display_box() {
    local title="$1" ; shift
    local width=72
    local -a lines=("$@")
    local rule
    printf -v rule '%*s' "$width" ''
    rule="${rule// /$BS_H}"

    printf '%b%s%s%s%b\n' "$C_BOLD$C_GREEN" "$BS_TL" "$rule" "$BS_TR" "$C_RESET"
    printf '%b%s%b %-*s %b%s%b\n' \
        "$C_BOLD$C_GREEN" "$BS_V" "$C_RESET" \
        $((width - 2)) "$title" \
        "$C_BOLD$C_GREEN" "$BS_V" "$C_RESET"
    printf '%b%s%s%s%b\n' "$C_BOLD$C_GREEN" "$BS_L" "$rule" "$BS_R" "$C_RESET"
    local l
    for l in "${lines[@]}"; do
        printf '%b%s%b %-*s %b%s%b\n' \
            "$C_BOLD$C_GREEN" "$BS_V" "$C_RESET" \
            $((width - 2)) "$l" \
            "$C_BOLD$C_GREEN" "$BS_V" "$C_RESET"
    done
    printf '%b%s%s%s%b\n' "$C_BOLD$C_GREEN" "$BS_BL" "$rule" "$BS_BR" "$C_RESET"
}

# ──────────────────────────────────────────────────────────────────────────────
#  Progress rendering
# ──────────────────────────────────────────────────────────────────────────────
# stage_header <index> <total> <title>
stage_header() {
    local idx="$1" total="$2" title="$3"
    printf '\n%b[%d/%d] %s%b\n' "$C_BOLD$C_CYAN" "$idx" "$total" "$title" "$C_RESET"
}

# substep <description> - opens a line, use substep_done / substep_fail to close
substep() {
    local desc="$1"
    local width=55
    local dots
    printf -v dots '%*s' "$width" ''
    dots="${dots// /.}"
    local padded="${desc}${dots}"
    padded="${padded:0:$width}"
    printf '  %b%s%b %s' "$C_DIM" "$G_BULLET" "$C_RESET" "$padded"
    BANANAWRT_SUBSTEP_START="$(date +%s)"
}

substep_done() {
    local extra="${1:-}"
    local duration=$(( $(date +%s) - ${BANANAWRT_SUBSTEP_START:-$(date +%s)} ))
    local human
    human="$(human_duration "$duration")"
    if [[ -n "$extra" ]]; then
        printf ' %b%s%b %b%s %s%b\n' "$C_GREEN$C_BOLD" "$G_OK" "$C_RESET" "$C_DIM" "$human" "$extra" "$C_RESET"
    else
        printf ' %b%s%b %b%s%b\n' "$C_GREEN$C_BOLD" "$G_OK" "$C_RESET" "$C_DIM" "$human" "$C_RESET"
    fi
    unset BANANAWRT_SUBSTEP_START
}

substep_fail() {
    local extra="${1:-}"
    printf ' %b%s%b %b%s%b\n' "$C_RED$C_BOLD" "$G_FAIL" "$C_RESET" "$C_DIM" "$extra" "$C_RESET"
    unset BANANAWRT_SUBSTEP_START
}

substep_skip() {
    local reason="${1:-skipped}"
    printf ' %b%s skip%b %b%s%b\n' "$C_YELLOW" "$G_DOT" "$C_RESET" "$C_DIM" "$reason" "$C_RESET"
    unset BANANAWRT_SUBSTEP_START
}

# ──────────────────────────────────────────────────────────────────────────────
#  Timers (slot-based, up to 16 concurrent)
# ──────────────────────────────────────────────────────────────────────────────
declare -gA BANANAWRT_TIMERS=()

timer_start() {
    local name="${1:-default}"
    BANANAWRT_TIMERS[$name]="$(date +%s)"
}

timer_elapsed() {
    local name="${1:-default}"
    local start="${BANANAWRT_TIMERS[$name]:-$(date +%s)}"
    echo $(( $(date +%s) - start ))
}

timer_stop() {
    local name="${1:-default}"
    timer_elapsed "$name"
    unset "BANANAWRT_TIMERS[$name]"
}

# human_duration <seconds> → "1h 23m 45s"
human_duration() {
    local s="${1:-0}"
    if (( s < 60 )); then
        printf '%ds' "$s"
    elif (( s < 3600 )); then
        printf '%dm %02ds' $(( s / 60 )) $(( s % 60 ))
    else
        printf '%dh %02dm %02ds' $(( s / 3600 )) $(( (s % 3600) / 60 )) $(( s % 60 ))
    fi
}

# format_bytes <bytes> → "1.5 GB"
format_bytes() {
    local b="${1:-0}"
    local units=( B KB MB GB TB )
    local i=0
    local n="$b"
    while (( n >= 1024 && i < 4 )); do
        n=$(( n / 1024 ))
        i=$((i + 1))
    done
    printf '%d %s' "$n" "${units[$i]}"
}

# ──────────────────────────────────────────────────────────────────────────────
#  Command execution with error capture
# ──────────────────────────────────────────────────────────────────────────────
# run_cmd <description> <cmd...>
#   Executes cmd, captures output. On success: brief confirmation.
#   On failure: prints captured output and propagates error.
run_cmd() {
    local desc="$1" ; shift
    local log
    log="$(mktemp -t bananawrt-cmd.XXXXXX)"
    substep "$desc"
    if "$@" >"$log" 2>&1; then
        substep_done
        rm -f "$log"
        return 0
    else
        local rc=$?
        substep_fail "exit $rc"
        printf '\n%b---- command output ----%b\n' "$C_DIM" "$C_RESET"
        cat "$log"
        printf '%b------------------------%b\n\n' "$C_DIM" "$C_RESET"
        rm -f "$log"
        return "$rc"
    fi
}

# run_cmd_stream <description> <cmd...>
#   Executes cmd with live output. Use for long-running compilations.
run_cmd_stream() {
    local desc="$1" ; shift
    display_alert step "$desc"
    if "$@"; then
        display_alert ok "$desc completed"
        return 0
    else
        local rc=$?
        display_alert err "$desc failed (exit $rc)"
        return "$rc"
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
#  Error handling
# ──────────────────────────────────────────────────────────────────────────────
exit_with_error() {
    local msg="${1:-unspecified error}"
    local code="${2:-1}"
    display_alert err "$msg"
    exit "$code"
}

trap_handler() {
    local rc=$?
    local line="${1:-?}"
    if (( rc != 0 )); then
        display_alert err "Aborted at line $line (exit $rc)"
    fi
    # Execute user cleanup hooks
    if declare -f on_exit >/dev/null; then
        on_exit "$rc"
    fi
    exit "$rc"
}

install_traps() {
    set -o errtrace
    trap 'trap_handler $LINENO' ERR INT TERM
}

# ──────────────────────────────────────────────────────────────────────────────
#  Cache helpers
# ──────────────────────────────────────────────────────────────────────────────
# cache_key <label> <file1> [file2...] → hashed key string
cache_key() {
    local label="$1" ; shift
    local hash_input=""
    local f
    for f in "$@"; do
        [[ -e "$f" ]] || continue
        hash_input+="$(sha256sum "$f" | awk '{print $1}') "
    done
    local short
    short="$(printf '%s' "$hash_input" | sha256sum | awk '{print $1}' | cut -c1-16)"
    printf '%s-%s' "$label" "$short"
}

# ──────────────────────────────────────────────────────────────────────────────
#  CI detection
# ──────────────────────────────────────────────────────────────────────────────
is_ci() {
    [[ -n "${BANANAWRT_CI:-}" ]] && return 0
    [[ "${CI:-}" == "true" ]] && return 0
    [[ "${GITHUB_ACTIONS:-}" == "true" ]] && return 0
    return 1
}

# ──────────────────────────────────────────────────────────────────────────────
#  String helpers
# ──────────────────────────────────────────────────────────────────────────────
capitalize() {
    local s="${1:-}"
    [[ -z "$s" ]] && return 0
    printf '%s%s' "$(printf '%s' "${s:0:1}" | tr '[:lower:]' '[:upper:]')" "${s:1}"
}

# pad_right <string> <width>
pad_right() {
    local s="$1" w="$2"
    printf '%-*s' "$w" "$s"
}

# ──────────────────────────────────────────────────────────────────────────────
#  Logging to file (optional, set BANANAWRT_LOG_FILE)
# ──────────────────────────────────────────────────────────────────────────────
log_to_file() {
    [[ -z "${BANANAWRT_LOG_FILE:-}" ]] && return 0
    printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >> "$BANANAWRT_LOG_FILE"
}
