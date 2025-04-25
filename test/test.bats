#!/usr/bin/env bats
# requires bats-core: https://github.com/bats-core/bats-core
# brew install bats-core
# or:
# apt-get install bats

setup() {
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" \
    >/dev/null 2>&1 && pwd )"  
  source "$DIR/../log.sh"
  
  # Save original environment
  ORIG_DEBUG="${DEBUG:-}"
  ORIG_QUIET="${QUIET:-}"
  ORIG_LOG_LEVEL="${LOG_LEVEL:-}"
  ORIG_NO_COLOR="${NO_COLOR:-}"
  ORIG_FORCE_COLOR="${FORCE_COLOR:-}"
  ORIG_JSON="${JSON:-}"
  
  # Clear variables for tests
  unset DEBUG QUIET LOG_LEVEL NO_COLOR FORCE_COLOR JSON
  unset LOGCOL_INFO LOGCOL_DEBUG LOGCOL_WARN LOGCOL_ERROR 
  unset LOGCOL_SUCCESS LOGCOL_RESET
}

teardown() {
  # Restore environment
  [ -n "$ORIG_DEBUG" ] && export DEBUG="$ORIG_DEBUG" || unset DEBUG
  [ -n "$ORIG_QUIET" ] && export QUIET="$ORIG_QUIET" || unset QUIET
  [ -n "$ORIG_LOG_LEVEL" ] && export LOG_LEVEL="$ORIG_LOG_LEVEL" \
                           || unset LOG_LEVEL
  [ -n "$ORIG_NO_COLOR" ] && export NO_COLOR="$ORIG_NO_COLOR" \
                          || unset NO_COLOR
  [ -n "$ORIG_FORCE_COLOR" ] && export FORCE_COLOR="$ORIG_FORCE_COLOR" \
                             || unset FORCE_COLOR
  [ -n "$ORIG_JSON" ] && export JSON="$ORIG_JSON" || unset JSON
}

# Helper function to capture stderr output
capture_stderr() {
  "$@" 2>&1 1>/dev/null
}

# Basic logging tests
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

@test "basic: log_success outputs message to stderr" {
  run capture_stderr log_success "success message"
  [ "$output" = "success message" ]
}

@test "basic: log with custom level outputs message to stderr" {
  run capture_stderr log "CUSTOM" "custom level message"
  [ "$output" = "custom level message" ]
}

# DEBUG mode tests
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
  
  DEBUG=1 run capture_stderr log_success "success message"
  [ "$output" = "[SUCCESS] success message" ]
}

# QUIET mode tests
@test "quiet mode: suppresses non-error messages" {
  QUIET=1 run capture_stderr log_info "info message"
  [ "$output" = "" ]
  
  QUIET=1 run capture_stderr log_debug "debug message"
  [ "$output" = "" ]
  
  QUIET=1 run capture_stderr log_warn "warn message"
  [ "$output" = "" ]
  
  QUIET=1 run capture_stderr log_success "success message"
  [ "$output" = "" ]
  
  # Only error messages remain
  QUIET=1 run capture_stderr log_error "error message"
  [ "$output" = "error message" ]
}

# LOG_LEVEL filtering tests
@test "log level: ERROR only shows ERROR messages" {
  LOG_LEVEL=ERROR run capture_stderr log_info "info message"
  [ "$output" = "" ]
  
  LOG_LEVEL=ERROR run capture_stderr log_debug "debug message"
  [ "$output" = "" ]
  
  LOG_LEVEL=ERROR run capture_stderr log_warn "warn message"
  [ "$output" = "" ]
  
  LOG_LEVEL=ERROR run capture_stderr log_success "success message"
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
  
  LOG_LEVEL=WARN run capture_stderr log_success "success message"
  [ "$output" = "" ]
  
  LOG_LEVEL=WARN run capture_stderr log_error "error message"
  [ "$output" = "error message" ]
}

@test "log level: INFO shows INFO, SUCCESS, WARN, ERROR not DEBUG" {
  LOG_LEVEL=INFO run capture_stderr log_info "info message"
  [ "$output" = "info message" ]
  
  LOG_LEVEL=INFO run capture_stderr log_debug "debug message"
  [ "$output" = "" ]
  
  LOG_LEVEL=INFO run capture_stderr log_warn "warn message"
  [ "$output" = "warn message" ]
  
  LOG_LEVEL=INFO run capture_stderr log_success "success message"
  [ "$output" = "success message" ]
  
  LOG_LEVEL=INFO run capture_stderr log_error "error message"
  [ "$output" = "error message" ]
}

# Filtering precedence tests
@test "filtering precedence: QUIET overrides DEBUG and LOG_LEVEL" {
  QUIET=1 DEBUG=1 LOG_LEVEL=DEBUG run log_error "error message"
  [ "$output" = "error message" ]
  
  QUIET=1 DEBUG=1 LOG_LEVEL=DEBUG run log_info "info message"
  [ "$output" = "" ]
}

@test "filtering precedence: DEBUG overrides LOG_LEVEL" {
  DEBUG=1 LOG_LEVEL=ERROR run capture_stderr log_debug "debug message"
  [ "$output" = "[DEBUG] debug message" ]
  
  DEBUG=1 LOG_LEVEL=ERROR run capture_stderr log_info "info message"
  [ "$output" = "[INFO] info message" ]
}

# JSON output tests
@test "json mode: formats messages as JSON" {
  JSON=1 run log_info "info message"
  [ "$output" = '{"level":"info","message":"info message"}' ]
  
  JSON=1 run log_error "error message"
  [ "$output" = '{"level":"error","message":"error message"}' ]
}

@test "json mode: handles special characters in messages" {
  JSON=1 run log_info '"qt" and \\bs\\'
  [ "$output" = '{"level":"info","message":"\"qt\" and \\\\bs\\\\"}' ]
  
  # Test newlines and tabs handling
  echo -e "newline\nand tab\t" > \
    "$BATS_TEST_TMPDIR/message.txt"
  JSON=1 run log_info "$(cat "$BATS_TEST_TMPDIR/message.txt")"
  [ "$output" = '{"level":"info","message":"newline\nand tab\t"}' ]
}

# Color handling tests
@test "color: NO_COLOR disables colorized output" {
  NO_COLOR=1 run log_error "test"
  [ "$output" = "test" ]
  
  run log_error "test"
  [ "$output" = "test" ]
}

@test "json + debug/color: JSON mode ignores color and debug settings" {
  JSON=1 DEBUG=1 run log_info "test message"
  [ "$output" = '{"level":"info","message":"test message"}' ]
  
  JSON=1 FORCE_COLOR=1 run log_info "test message"
  [ "$output" = '{"level":"info","message":"test message"}' ]
}

# Test logt_info function
@test "logt_info outputs timestamped info message" {
  run capture_stderr logt_info "timestamped message"
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} timestamped message$ ]]
}
