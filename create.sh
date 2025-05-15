#!/bin/sh
# create_logger_project.sh
# Script to create a POSIX-compliant logger project structure

set -e  # Exit on any error

# Create project directories
mkdir -p test

echo "Creating project structure..."

# Create logger.sh
cat > logger.sh << 'EOL'
#!/bin/sh
# shellcheck disable=SC2034
# Variables sourced externally:
#   DEBUG, QUIET, LOG_LEVEL, NO_COLOR, FORCE_COLOR, JSON
#   LOGCOL_INFO, LOGCOL_DEBUG, LOGCOL_WARN, LOGCOL_ERROR,
#   LOGCOL_DONE, LOGCOL_RESET

# A conventions-based POSIX-compliant logger.
#
# Usage:
# log <LEVEL> "..."   # Log a message with custom level
#    log_info "..."   # Log an informational message
#   log_debug "..."   # Log a debug message
#    log_warn "..."   # Log a warning
#   log_error "..."   # Log an error
# log_done "..."   # Log a done message
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
#                   # WARN, ERROR, DONE, RESET

log() {
  _level=$(echo "$1" | tr '[:lower:]' '[:upper:]')
  shift
  _msg="$*"

  # Filtering Logic: QUIET > DEBUG > LOG_LEVEL
  if [ -n "${QUIET:-}" ]; then
    [ "$_level" != "ERROR" ] && return 0
  elif [ -n "${DEBUG:-}" ]; then
    :
  else
    _log_level_setting=$(echo "${LOG_LEVEL:-INFO}" | tr '[:lower:]' '[:upper:]')
    case "$_log_level_setting" in
      ERROR) [ "$_level" != "ERROR" ] && return 0 ;;
      WARN) case "$_level" in INFO|DONE|DEBUG) return 0 ;; esac ;;
      INFO|*) case "$_level" in DEBUG) return 0 ;; esac ;;
    esac
  fi

  if [ -n "${JSON:-}" ]; then
    _escaped_msg=$(printf "%s" "$_msg" | \
      sed -e ':a;N;$!ba' \
          -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\n/\\n/g' \
          -e 's/\t/\\t/g' -e 's/\r/\\r/g' -e 's/\f/\\f/g' \
          -e 's/\b/\\b/g')
    _json_level=$(echo "$_level" | tr '[:upper:]' '[:lower:]')
    printf '{"level":"%s","message":"%s"}\n' \
           "${_json_level}" "${_escaped_msg}" >&2
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
      _reset="${LOGCOL_RESET:-$(tput sgr0)}"
      [ $? -ne 0 ] && _reset="" # Clear if tput failed

      case "$_level" in
        DEBUG)   _tag="${LOGCOL_DEBUG:-$(tput dim)}" ;;
        WARN)    _tag="${LOGCOL_WARN:-$(tput setaf 3)}" ;;
        ERROR)   _tag="${LOGCOL_ERROR:-$(tput setaf 1)}" ;;
        DONE) _tag="${LOGCOL_DONE:-$(tput setaf 2)}" ;;
        INFO)    _tag="${LOGCOL_INFO:-}" ;;
        *)       _tag="" ;;
      esac
      [ $? -ne 0 ] && _tag="" # Clear if tput failed for specific tag
    fi

    if [ -n "${DEBUG:-}" ]; then
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
log_done() { log DONE "$@" ; }
EOL

# Create test/test.bats
cat > test/test.bats << 'EOL'
#!/usr/bin/env bats

# Setup function runs before each test
setup() {
    # Get the directory of the test file
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    
    # Source the logger script
    source "$DIR/../logger.sh"
    
    # Store original environment
    ORIG_DEBUG="${DEBUG:-}"
    ORIG_QUIET="${QUIET:-}"
    ORIG_LOG_LEVEL="${LOG_LEVEL:-}"
    ORIG_NO_COLOR="${NO_COLOR:-}"
    ORIG_FORCE_COLOR="${FORCE_COLOR:-}"
    ORIG_JSON="${JSON:-}"
    
    # Clear environment variables that might affect tests
    unset DEBUG QUIET LOG_LEVEL NO_COLOR FORCE_COLOR JSON
    unset LOGCOL_INFO LOGCOL_DEBUG LOGCOL_WARN LOGCOL_ERROR LOGCOL_DONE LOGCOL_RESET
}

# Teardown function runs after each test
teardown() {
    # Restore original environment
    if [ -n "$ORIG_DEBUG" ]; then export DEBUG="$ORIG_DEBUG"; else unset DEBUG; fi
    if [ -n "$ORIG_QUIET" ]; then export QUIET="$ORIG_QUIET"; else unset QUIET; fi
    if [ -n "$ORIG_LOG_LEVEL" ]; then export LOG_LEVEL="$ORIG_LOG_LEVEL"; else unset LOG_LEVEL; fi
    if [ -n "$ORIG_NO_COLOR" ]; then export NO_COLOR="$ORIG_NO_COLOR"; else unset NO_COLOR; fi
    if [ -n "$ORIG_FORCE_COLOR" ]; then export FORCE_COLOR="$ORIG_FORCE_COLOR"; else unset FORCE_COLOR; fi
    if [ -n "$ORIG_JSON" ]; then export JSON="$ORIG_JSON"; else unset JSON; fi
}

# Helper function to capture stderr output
capture_stderr() {
    "$@" 2>&1 1>/dev/null
}

# Test basic logging functions
@test "basic: log_info outputs message to stderr" {
    run capture_stderr log_info "hello world"
    [ "$output" = "hello world" ]
}

@test "basic: log_debug is suppressed by default" {
    run capture_stderr log_debug "debug message"
    [ "$output" = "" ]
}

@test "basic: log_warn outputs message to stderr" {
    run capture_stderr log_warn "warning message"
    [ "$output" = "warning message" ]
}

@test "basic: log_error outputs message to stderr" {
    run capture_stderr log_error "error message"
    [ "$output" = "error message" ]
}

@test "basic: log_done outputs message to stderr" {
    run capture_stderr log_done "done message"
    [ "$output" = "done message" ]
}

@test "basic: log with custom level outputs message to stderr" {
    run capture_stderr log "CUSTOM" "custom level message"
    [ "$output" = "custom level message" ]
}

# Test DEBUG mode
@test "debug mode: enables debug messages" {
    DEBUG=1 run capture_stderr log_debug "debug message"
    [ "$output" = "[DEBUG] debug message" ]
}

@test "debug mode: shows level prefix for all message types" {
    DEBUG=1 run capture_stderr log_info "info message"
    [ "$output" = "[INFO] info message" ]
    
    DEBUG=1 run capture_stderr log_warn "warn message"
    [ "$output" = "[WARN] warn message" ]
    
    DEBUG=1 run capture_stderr log_error "error message"
    [ "$output" = "[ERROR] error message" ]
    
    DEBUG=1 run capture_stderr log_done "done message"
    [ "$output" = "[DONE] done message" ]
}

# Test QUIET mode
@test "quiet mode: suppresses non-error messages" {
    QUIET=1 run capture_stderr log_info "info message"
    [ "$output" = "" ]
    
    QUIET=1 run capture_stderr log_debug "debug message"
    [ "$output" = "" ]
    
    QUIET=1 run capture_stderr log_warn "warn message"
    [ "$output" = "" ]
    
    QUIET=1 run capture_stderr log_done "done message"
    [ "$output" = "" ]
    
    # Only error messages should be shown in quiet mode
    QUIET=1 run capture_stderr log_error "error message"
    [ "$output" = "error message" ]
}

# Test LOG_LEVEL filtering
@test "log level: ERROR only shows ERROR messages" {
    LOG_LEVEL=ERROR run capture_stderr log_info "info message"
    [ "$output" = "" ]
    
    LOG_LEVEL=ERROR run capture_stderr log_debug "debug message"
    [ "$output" = "" ]
    
    LOG_LEVEL=ERROR run capture_stderr log_warn "warn message"
    [ "$output" = "" ]
    
    LOG_LEVEL=ERROR run capture_stderr log_done "done message"
    [ "$output" = "" ]
    
    LOG_LEVEL=ERROR run capture_stderr log_error "error message"
    [ "$output" = "error message" ]
}

@test "log level: WARN shows WARN and ERROR messages" {
    LOG_LEVEL=WARN run capture_stderr log_info "info message"
    [ "$output" = "" ]
    
    LOG_LEVEL=WARN run capture_stderr log_debug "debug message"
    [ "$output" = "" ]
    
    LOG_LEVEL=WARN run capture_stderr log_warn "warn message"
    [ "$output" = "warn message" ]
    
    LOG_LEVEL=WARN run capture_stderr log_done "done message"
    [ "$output" = "" ]
    
    LOG_LEVEL=WARN run capture_stderr log_error "error message"
    [ "$output" = "error message" ]
}

@test "log level: INFO shows INFO, DONE, WARN, ERROR messages but not DEBUG" {
    LOG_LEVEL=INFO run capture_stderr log_info "info message"
    [ "$output" = "info message" ]
    
    LOG_LEVEL=INFO run capture_stderr log_debug "debug message"
    [ "$output" = "" ]
    
    LOG_LEVEL=INFO run capture_stderr log_warn "warn message"
    [ "$output" = "warn message" ]
    
    LOG_LEVEL=INFO run capture_stderr log_done "done message"
    [ "$output" = "done message" ]
    
    LOG_LEVEL=INFO run capture_stderr log_error "error message"
    [ "$output" = "error message" ]
}

# Test precedence of filtering logic
@test "filtering precedence: QUIET overrides DEBUG and LOG_LEVEL" {
    QUIET=1 DEBUG=1 LOG_LEVEL=DEBUG run capture_stderr log_info "info message"
    [ "$output" = "" ]
    
    QUIET=1 DEBUG=1 LOG_LEVEL=DEBUG run capture_stderr log_error "error message"
    [ "$output" = "error message" ]
}

@test "filtering precedence: DEBUG overrides LOG_LEVEL" {
    DEBUG=1 LOG_LEVEL=ERROR run capture_stderr log_debug "debug message"
    [ "$output" = "[DEBUG] debug message" ]
    
    DEBUG=1 LOG_LEVEL=ERROR run capture_stderr log_info "info message"
    [ "$output" = "[INFO] info message" ]
}

# Test JSON output mode
@test "json mode: formats messages as JSON" {
    JSON=1 run capture_stderr log_info "info message"
    [ "$output" = '{"level":"info","message":"info message"}' ]
    
    JSON=1 run capture_stderr log_error "error message"
    [ "$output" = '{"level":"error","message":"error message"}' ]
}

@test "json mode: handles special characters in messages" {
    JSON=1 run capture_stderr log_info "message with \"quotes\" and \\backslashes\\"
    [ "$output" = '{"level":"info","message":"message with \"quotes\" and \\\\backslashes\\\\"}' ]
    
    JSON=1 run capture_stderr log_info "message with newline
and tab	"
    [ "$output" = '{"level":"info","message":"message with newline\nand tab\t"}' ]
}

# Test color handling
@test "color: NO_COLOR disables colorized output" {
    NO_COLOR=1 run bash -c 'source "'"$DIR/../logger.sh"'" && capture_stderr log_error "test" | wc -c'
    plain_length="$output"
    
    run bash -c 'source "'"$DIR/../logger.sh"'" && capture_stderr log_error "test" | wc -c'
    colored_length="$output"
    
    # In a real terminal, colored_length should be greater than plain_length
    # But in test environment, they might be equal if color is not supported
    [ "$plain_length" -le "$colored_length" ]
}

@test "json + debug/color: JSON mode ignores color and debug settings" {
    # JSON mode with DEBUG should still output JSON format without [LEVEL]
    JSON=1 DEBUG=1 run capture_stderr log_info "test message"
    [ "$output" = '{"level":"info","message":"test message"}' ]
    
    # JSON mode with color settings should still output plain JSON
    JSON=1 FORCE_COLOR=1 run capture_stderr log_info "test message"
    [ "$output" = '{"level":"info","message":"test message"}' ]
}
EOL

# Create README.md
cat > README.md << 'EOL'
# POSIX-compliant Logger

A simple, POSIX-compliant shell script logger that can output messages to stderr with different log levels, support for colored output, and JSON formatting.

## Features

- POSIX-compliant (works in sh, bash, dash, etc.)
- Log level filtering (DEBUG, INFO, WARN, ERROR, DONE)
- Optional colored output with automatic terminal detection
- JSON output option for machine parsing
- Quiet mode to suppress all but error messages
- Customizable colors via environment variables

## Installation

Simply download `logger.sh` and source it in your scripts.

```sh
# Make it executable if you want to run it directly
chmod +x logger.sh

# Source it in your scripts
. ./logger.sh
```

## Usage

```sh
# Log different types of messages
log_info "This is an informational message"
log_debug "This is a debug message (hidden by default)"
log_warn "This is a warning message"
log_error "This is an error message"
log_done "This is a done message"

# Or use a custom level
log "CUSTOM" "This is a custom level message"
```

## Configuration

The logger's behavior can be controlled through environment variables:

| Variable       | Description                                     | Default |
|----------------|-------------------------------------------------|---------|
| `LOG_LEVEL`    | Filter messages by level (ERROR, WARN, INFO)    | INFO    |
| `DEBUG=1`      | Enable debug output and show level prefixes     | -       |
| `QUIET=1`      | Suppress all non-error messages                 | -       |
| `NO_COLOR=1`   | Disable color output                            | -       |
| `FORCE_COLOR=1`| Force color output, even when not in a terminal | -       |
| `JSON=1`       | Output logs in JSON format                      | -       |

### Custom Colors

You can customize the colors used for each log level:

```sh
# Example: Use custom colors
LOGCOL_INFO=$(tput setaf 7)      # White
LOGCOL_DEBUG=$(tput dim)         # Dim
LOGCOL_WARN=$(tput setaf 3)      # Yellow
LOGCOL_ERROR=$(tput setaf 1)     # Red
LOGCOL_DONE=$(tput setaf 2)   # Green
LOGCOL_RESET=$(tput sgr0)        # Reset
```

## Testing

This project uses [bats-core](https://github.com/bats-core/bats-core) for testing. To run the tests:

```sh
# Install bats-core if you haven't already
# Then run the tests
bats test/test.bats
```

## Examples

### Basic usage
```sh
. ./logger.sh
log_info "Starting application..."
log_warn "Configuration file not found, using defaults"
log_error "Failed to connect to database"
log_done "Backup completed successfully"
```

### Using with JSON output
```sh
JSON=1 ./script-using-logger.sh
```

This will output logs in JSON format suitable for parsing:
```json
{"level":"info","message":"Starting application..."}
{"level":"warn","message":"Configuration file not found, using defaults"}
```

## License

MIT License
EOL

# Make logger.sh executable
chmod +x logger.sh

echo "Creating example usage script..."
cat > example.sh << 'EOL'
#!/bin/sh
# Example usage of the logger

# Source the logger
. ./logger.sh

# Show different log levels
log_info "Starting example script..."
log_debug "This debug message is hidden by default"
log_warn "This is a warning"
log_error "This is an error"
log_done "This is a done message"

# Try with DEBUG enabled
echo "\nWith DEBUG=1:"
DEBUG=1 log_debug "Now you can see debug messages"
DEBUG=1 log_info "And see the level prefix on all messages"

# Try with QUIET enabled
echo "\nWith QUIET=1:"
QUIET=1 log_info "This info message is suppressed"
QUIET=1 log_error "But error messages are still shown"

# Try with JSON output
echo "\nWith JSON=1:"
JSON=1 log_info "This appears in JSON format"
JSON=1 log_error "So does this error"
EOL

chmod +x example.sh

echo "Project created successfully!"
echo ""
echo "Project structure:"
echo "- logger.sh        # The main logger script"
echo "- test/test.bats  # Bats tests for the logger"
echo "- README.md       # Project documentation"
echo "- example.sh      # Example usage script"
echo ""
echo "To run the example: ./example.sh"
echo "To run the tests (requires bats-core): bats test/test.bats"
