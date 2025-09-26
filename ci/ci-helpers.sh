#!/usr/bin/env bash
# ci-helpers.sh
#
# Reusable Bash helpers for CI pipelines.
# - Bash 4+ recommended
# - All helpers RETURN (0=success, non-zero=failure) instead of exiting.
# - Log to stderr; do not assume color TTY.
#
# USAGE (in a script or CI step):
#   source ci/ci-helpers.sh
#   if ci_check_file "path/to/file"; then
#       ci_log_info "File exists"
#   else
#       ci_log_error "Missing file"
#       exit 1
#   fi
#
#   ci_check_command_rc "make -j" || ci_die "Build failed"
#
#   ci_check_output_contains "ready" "my_service --status" \
#       || ci_die "Service not ready"
#
#   ci_retry 3 5 ci_check_grep "expected: true" config.yaml \
#       || ci_die "Config doesn’t contain expected value"
#
# Optional: enable stricter shell behavior in YOUR script (not here):
#   set -Eeuo pipefail
#   trap 'ci_log_error "Line $LINENO: command exited with $?"' ERR

###############################################################################
# Logging
###############################################################################

ci_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

ci_log()       { printf "%s %s\n" "$(ci_ts)" "$*" >&2; }
ci_log_info()  { ci_log "[INFO]  $*"; }
ci_log_warn()  { ci_log "[WARN]  $*"; }
ci_log_error() { ci_log "[ERROR] $*"; }

# Exit the CURRENT script with a message (use sparingly; prefer returning).
# Example:
#   ci_check_file foo.txt || ci_die "foo.txt missing"
ci_die() { ci_log_error "$*"; exit 1; }

###############################################################################
# Preconditions / Environment
###############################################################################

# Ensure env var is set and non-empty.
# Example:
#   ci_assert_var_set GITHUB_SHA || exit 1
ci_assert_var_set() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    ci_log_error "Required env var not set: $name"
    return 1
  fi
}

# Temporarily run a command with KEY=VAL env kv-pairs.
# Example:
#   ci_with_env FOO=bar BAZ=qux -- my_cmd --flag
ci_with_env() {
  local kv envs=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    kv="$1"; envs+=("$kv"); shift
  done
  [[ "$1" == "--" ]] && shift
  ( export "${envs[@]}" ; "$@" )
}

###############################################################################
# Filesystem checks
###############################################################################

# Return 0 if file exists (regular file).
# Example:
#   ci_check_file path/to/file.txt
ci_check_file() {
  local f="$1"
  [[ -f "$f" ]] || { ci_log_error "File not found: $f"; return 1; }
}

# Return 0 if directory exists.
# Example:
#   ci_check_dir path/to/dir
ci_check_dir() {
  local d="$1"
  [[ -d "$d" ]] || { ci_log_error "Directory not found: $d"; return 1; }
}

# Ensure ALL provided files exist.
# Example:
#   ci_require_files README.md LICENSE script.sh
ci_require_files() {
  local missing=0 f
  for f in "$@"; do
    if ! ci_check_file "$f"; then
      missing=1
    fi
  done
  return "$missing"
}

###############################################################################
# Command execution
###############################################################################

# Run a command; return its exit code. Logs on failure.
# Example:
#   ci_check_command_rc "make test"
ci_check_command_rc() {
  local cmd="$*"
  if eval "$cmd"; then
    return 0
  else
    local rc=$?
    ci_log_error "Command failed ($rc): $cmd"
    return "$rc"
  fi
}

# Run a command and capture stdout to a variable name passed as $1.
# Returns RC of the command; variable is set even on failure.
# Example:
#   out=""
#   ci_capture out my_tool --version || ci_log_warn "my_tool failed"
#   echo "Tool says: $out"
ci_capture() {
  local __outvar="$1"; shift
  local out
  out="$("$@" 2>&1)"; local rc=$?
  printf -v "$__outvar" "%s" "$out"
  return "$rc"
}

# Run a command with a hard timeout (seconds). Kills process group on timeout.
# Example:
#   ci_run_with_timeout 60 long_running_task
ci_run_with_timeout() {
  local seconds="$1"; shift
  local cmd=( "$@" )
  local pgid
  (
    set -m
    "${cmd[@]}" &
    local pid=$!
    pgid=$pid
    disown
    for ((i=0; i<seconds; i++)); do
      if ! kill -0 "$pid" 2>/dev/null; then
        exit 0
      fi
      sleep 1
    done
    ci_log_error "Timeout after ${seconds}s: ${cmd[*]}"
    kill -TERM "-$pgid" 2>/dev/null || true
    sleep 2
    kill -KILL "-$pgid" 2>/dev/null || true
    exit 124
  )
  return "$?"
}

# Retry a function/command N times with S seconds between attempts.
# Usage:
#   ci_retry <retries> <sleep_seconds> <cmd...>
# Example:
#   ci_retry 3 5 curl -fsS https://example.com/health
ci_retry() {
  local tries="$1" delay="$2"; shift 2
  local attempt rc
  for ((attempt=1; attempt<=tries; attempt++)); do
    if "$@"; then
      return 0
    fi
    rc=$?
    if (( attempt < tries )); then
      ci_log_warn "Attempt $attempt/$tries failed (rc=$rc). Retrying in ${delay}s…"
      sleep "$delay"
    fi
  done
  ci_log_error "All ${tries} attempts failed for: $*"
  return "$rc"
}

###############################################################################
# Output/content checks
###############################################################################

# Check that a file contains a fixed string (grep -F).
# Example:
#   ci_check_grep "enabled: true" settings.yaml
ci_check_grep() {
  local needle="$1" file="$2"
  if grep -Fq -- "$needle" "$file"; then
    return 0
  else
    ci_log_error "String not found in $file: $needle"
    return 1
  fi
}

# Check that STDOUT of a command contains a fixed string.
# Example:
#   ci_check_output_contains "OK" "my_service --status"
ci_check_output_contains() {
  local needle="$1"; shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]]; then
    ci_log_error "Command failed while checking output: $*"
    ci_log_error "Output:\n$out"
    return "$rc"
  fi
  if grep -Fq -- "$needle" <<<"$out"; then
    return 0
  else
    ci_log_error "Expected substring not found: $needle"
    ci_log_error "Output:\n$out"
    return 1
  fi
}

# Check that STDOUT of a command matches a regex (bash regex).
# Example:
#   ci_check_output_matches 'version: [0-9]+\.[0-9]+' "tool --version"
ci_check_output_matches() {
  local regex="$1"; shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]]; then
    ci_log_error "Command failed while checking regex: $*"
    ci_log_error "Output:\n$out"
    return "$rc"
  fi
  if [[ "$out" =~ $regex ]]; then
    return 0
  else
    ci_log_error "Output did not match regex: $regex"
    ci_log_error "Output:\n$out"
    return 1
  fi
}

###############################################################################
# Small utilities
###############################################################################

# Add a line to a file only if not already present.
# Example:
#   ci_ensure_line_in_file "set -euo pipefail" ./script.sh
ci_ensure_line_in_file() {
  local line="$1" file="$2"
  if grep -Fqx -- "$line" "$file" 2>/dev/null; then
    return 0
  else
    printf "%s\n" "$line" >>"$file" || {
      ci_log_error "Failed to append to $file"
      return 1
    }
  fi
}

# Verify executable is available.
# Example:
#   ci_require_cmd git || exit 1
ci_require_cmd() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    return 0
  else
    ci_log_error "Required command not found in PATH: $name"
    return 1
  fi
}

###############################################################################
# End of library
###############################################################################
