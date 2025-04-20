#!/bin/sh
# shellcheck disable=SC2034
# Variables sourced externally:
#   DEBUG, QUIET, LOG_LEVEL, NO_COLOR, FORCE_COLOR, JSON
#   LOGCOL_INFO, LOGCOL_DEBUG, LOGCOL_WARN, LOGCOL_ERROR,
#   LOGCOL_SUCCESS, LOGCOL_RESET

# A conventions-based POSIX-compliant logger.
#
# Usage:
# log <LEVEL> "..."   # Log a message with custom level
#    log_info "..."   # Log an informational message
#   log_debug "..."   # Log a debug message
#    log_warn "..."   # Log a warning
#   log_error "..."   # Log an error
# log_success "..."   # Log a success message
#
# Environment:
#   LOG_LEVEL=level # Filter on ERROR, WARN, INFO. Default: INFO
#           DEBUG=1 # Enable all logging, print [LEVEL] labels
#           QUIET=1 # Disable all non-error logging
#        NO_COLOR=1 # Disable color output
#     FORCE_COLOR=1 # Force color output, override checks
#            JSON=1 # Output logs in JSON format
#    LOGCOL_<LVL>   # Pre-set tput codes (e.g., LOGCOL_ERROR=$(tput setaf 1))
#                   # avoids tput calls if set. LVL: INFO, DEBUG,
#                   # WARN, ERROR, SUCCESS, RESET

log() {
  _level=$(echo "$1" | tr '[:lower:]' '[:upper:]')
  shift
  _msg="$*"

  # Filtering Logic: QUIET > DEBUG > LOG_LEVEL
  if [ -n "${QUIET:-}" ]; then
    [ "$_level" != "ERROR" ] && return 0
    # In QUIET mode, never show level prefix even for ERROR
    _no_debug=1
  elif [ -n "${DEBUG:-}" ]; then
    :
  else
    _log_level_setting=$(echo "${LOG_LEVEL:-INFO}" | tr '[:lower:]' '[:upper:]')
    case "$_log_level_setting" in
      ERROR) [ "$_level" != "ERROR" ] && return 0 ;;
      WARN) case "$_level" in INFO|SUCCESS|DEBUG) return 0 ;; esac ;;
      INFO|*) case "$_level" in DEBUG) return 0 ;; esac ;;
    esac
  fi

  if [ -n "${JSON:-}" ]; then
    # JSON escaping for BSD and GNU sed
    _emsg=$(printf "%s" "$_msg" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    _emsg=$(printf "%s" "$_emsg" | tr '\t' '■' | sed 's/■/\\t/g')
    _emsg=$(printf "%s" "$_emsg" | tr '\n' '□' | sed 's/□/\\n/g')
    
    _json_level=$(echo "$_level" | tr '[:upper:]' '[:lower:]')
    printf '{"level":"%s","message":"%s"}\n' \
           "${_json_level}" "${_emsg}" >&2
  else
    _usecolor=false; _reset=""; _tag=""; _tputs=false;

    if tput setaf 1 >/dev/null 2>&1 && tput sgr0 >/dev/null 2>&1; then
      _tputs=true
    fi

    if [ "$_tputs" = true ]; then
      if { [ -n "${FORCE_COLOR:-}" ] || \
           { [ -z "${NO_COLOR:-}" ] && [ -t 2 ]; }; }; then
        _usecolor=true
      fi
    fi

    if [ "$_usecolor" = true ]; then
      _reset="${LOGCOL_RESET:-$(tput sgr0 || echo '')}"

      case "$_level" in
        DEBUG)   _tag="${LOGCOL_DEBUG:-$(tput dim || echo '')}" ;;
        WARN)    _tag="${LOGCOL_WARN:-$(tput setaf 3 || echo '')}" ;;
        ERROR)   _tag="${LOGCOL_ERROR:-$(tput setaf 1 || echo '')}" ;;
        SUCCESS) _tag="${LOGCOL_SUCCESS:-$(tput setaf 2 || echo '')}" ;;
        INFO)    _tag="${LOGCOL_INFO:-}" ;;
        *)       _tag="" ;;
      esac
    fi

    if [ -n "${DEBUG:-}" ] && [ -z "${_no_debug:-}" ]; then
      printf "%s[%s]%s %s%s\n" "${_tag}" "${_level}" "${_reset}" \
             "${_msg}" "${_reset}" >&2
    else
      printf "%s%s%s\n" "${_tag}" "${_msg}" "${_reset}" >&2
    fi
  fi
}

# Public convenience functions
log_info()    { log INFO    "$@" ; }
log_debug()   { log DEBUG   "$@" ; }
log_warn()    { log WARN    "$@" ; }
log_error()   { log ERROR   "$@" ; }
log_success() { log SUCCESS "$@" ; }
