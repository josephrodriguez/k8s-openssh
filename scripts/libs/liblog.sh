#!/bin/bash

# Constants
RESET='\033[0m'
RED='\033[38;5;1m'
GREEN='\033[38;5;2m'
YELLOW='\033[38;5;3m'
MAGENTA='\033[38;5;5m'
CYAN='\033[38;5;6m'

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function stderr_print() {
    printf "%b\\n" "${*}" >&2
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function log() {
    stderr_print "${CYAN}${MODULE:-} ${MAGENTA}$(date "+%T.%2N ")${RESET}${*}"
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function info() {
    log "${GREEN}INFO ${RESET} ==> ${*}"
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function warn() {
    log "${YELLOW}WARN ${RESET} ==> ${*}"
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function error() {
    log "${RED}ERROR${RESET} ==> ${*}"
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function debug() {
    log "${MAGENTA}DEBUG${RESET} ==> ${*}"
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function debug_text() {
    IFS=$'\r\n' read -rd '' -a logs <<< $1
    for line in "${logs[@]}"
      do
        debug "$line"
      done
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function debug_section() {
    local SECTION_NAME=$1
    local TEXT=$2

    section=$(printf -- '-%.0s' {1..64})

    debug "$section"
    debug "$SECTION_NAME"
    debug "$section"
    debug_text "$TEXT"
}