#!/usr/bin/env bats

# Setup executed before each test
setup() {
  # Create a temp file for our test results
  RESULT_FILE="$(mktemp)"
  export RESULT_FILE
}

# Cleanup after each test
teardown() {
  [ -f "$RESULT_FILE" ] && rm -f "$RESULT_FILE"
}

# Helper function to wrap demo.sh
run_demo() {
  cat > .wrapper.sh << 'EOF'
#!/bin/sh
# Capture original script dir
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# Override log_error
log_error() {
  echo "ERROR: $*" >&2
  echo "ERROR_MSG=$*" >> "$RESULT_FILE"
  exit 1
}

# Source the demo script
. "$SCRIPT_DIR/cli.sh"

# Run parseargs with fall arguments
parseargs "$@"

# Output results to file
cat > "$RESULT_FILE" << EOT
DEBUG=${DEBUG:-}
QUIET=${QUIET:-}
JSON=${JSON:-}
NO_COLOR=${NO_COLOR:-}
FORCE_COLOR=${FORCE_COLOR:-}
LOG_LEVEL=${LOG_LEVEL:-}
EOT
EOF

  chmod +x .wrapper.sh
  RESULT_FILE="$RESULT_FILE" ./.wrapper.sh "$@" || true
  [ -f "$RESULT_FILE" ] && cat "$RESULT_FILE"
  rm -f .wrapper.sh
}

@test "parseargs: basic boolean flags" {
  run_demo --debug --quiet
  
  grep -q "DEBUG=1" "$RESULT_FILE"
  grep -q "QUIET=1" "$RESULT_FILE"
}

@test "parseargs: short options" {
  run_demo -d -q -j
  
  grep -q "DEBUG=1" "$RESULT_FILE"
  grep -q "QUIET=1" "$RESULT_FILE"
  grep -q "JSON=1" "$RESULT_FILE"
}

@test "parseargs: log-level option" {
  run_demo --log-level ERROR
  
  grep -q "LOG_LEVEL=ERROR" "$RESULT_FILE"
}

@test "parseargs: log-level is case-insensitive" {
  run_demo --log-level info
  
  grep -q "LOG_LEVEL=INFO" "$RESULT_FILE"
}

@test "parseargs: rejects equals syntax" {
  run_demo --debug=1
  
  grep -q "ERROR_MSG=.*cannot use" "$RESULT_FILE" || echo "Expected error message not found"
}

@test "parseargs: rejects missing log-level value" {
  run_demo --log-level
  
  grep -q "ERROR_MSG=.*requires a value" "$RESULT_FILE" || echo "Expected error message not found"
}

@test "parseargs: rejects invalid log-level" {
  run_demo --log-level TRACE
  
  grep -q "ERROR_MSG=.*must be ERROR, WARN, or INFO" "$RESULT_FILE" || echo "Expected error message not found"
}

@test "parseargs: stops at --" {
  run_demo --debug -- --quiet
  
  grep -q "DEBUG=1" "$RESULT_FILE"
  ! grep -q "QUIET=1" "$RESULT_FILE" || return 1
}

@test "parseargs: stops at non-option" {
  run_demo --debug file.txt --quiet
  
  grep -q "DEBUG=1" "$RESULT_FILE"
  ! grep -q "QUIET=1" "$RESULT_FILE" || return 1
}
