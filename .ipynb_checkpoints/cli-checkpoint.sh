#!/bin/sh
  
# CLI with simplified option parsing - no equals syntax allowed
#   
# usage: 
# args.sh [-d|--debug] [-q|--quiet] [-j|--json] 
#         [-n|--no-color] [-f|--force-color] 
#         [-l|--log-level LEVEL] | ERROR, WARN, or INFO

. "$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)/log.sh"

parseargs() {
  while [ "$#" -gt 0 ]; do
    # First detect any use of equals and reject it
    case "$1" in
      *=*) log_error "cannot use '=': use '${1%%=*} ${1#*=}' not '$1'"; exit 1 ;;
    esac
    
    case "$1" in
      # Simple boolean flags - short and long options
      -d|--debug)       DEBUG=1 ;;f
      -q|--quiet)       QUIET=1 ;;
      -j|--json)        JSON=1 ;;
      -n|--no-color)    NO_COLOR=1 ;;
      -f|--force-color) FORCE_COLOR=1 ;;
      
      # Log level with validation - space syntax only
      -l|--log-level)
        if [ -z "$2" ] || [ "${2#-}" != "$2" ]; then
          log_error "error: --log-level requires a value"; exit 1
        fi
        level="$(echo "$2" | tr '[:lower:]' '[:upper:]')"
        case "$level" in
          ERROR|WARN|INFO) LOG_LEVEL="$level"; shift ;;
          *) log_error "error: log-level must be ERROR, WARN, or INFO"; exit 1 ;;
        esac ;;

      --) shift; break ;;
      -*) log_error "bad: $1"; exit 1 ;;
      *)  break ;;
    esac
    shift
  done
}
  
parseargs "$@"

# basic

log_info  "bootstrapping..."
log_warn  "fallback default"
log_done  "backup completed"

log_debug "reached codepath"
log_error "failed to update"

# timestamp

logt_info() { log_info "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

logt_info "a timestamped info message"
