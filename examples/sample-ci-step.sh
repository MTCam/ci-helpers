#!/usr/bin/env bash
# Example script showing how to use ci-helpers.sh in a CI step.

set -Eeuo pipefail
source "$(dirname "$0")/../ci/ci-helpers.sh"

ci_log_info "Starting sample CI step..."

# Check files
ci_check_file "README.md" || ci_die "README.md is required"

# Require a command
ci_require_cmd git || ci_die "git must be available"

# Run a command and check its return code
ci_check_command_rc "echo Hello, world"

# Check command output contains string
ci_check_output_contains "world" echo "Hello, world" \
  || ci_die "Did not find expected string in output"

# Grep a file for content
echo "expected_value" > tmp.txt
ci_check_grep "expected_value" tmp.txt || ci_die "expected_value missing"

ci_log_info "All checks passed!"
