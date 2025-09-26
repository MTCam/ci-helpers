#!/usr/bin/env bash
# Minimal, dependency-free tests for ci-helpers.sh
# Run locally: bash tests/test_ci_helpers.sh
set -Eeuo pipefail

# Locate helpers (support either filename)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT_DIR/ci/ci-helpers.sh" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/ci/ci-helpers.sh"
elif [[ -f "$ROOT_DIR/ci/ci-helper.sh" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/ci/ci-helper.sh"
else
  echo "Could not find ci/ci-helpers.sh or ci/ci-helper.sh" >&2
  exit 1
fi

pass=0
fail=0

assert_ok() {
  local msg="$1"; shift
  if "$@"; then
    echo "✔ $msg"
    ((pass++))
  else
    echo "✘ $msg (expected OK, got RC=$?)" >&2
    ((fail++))
  fi
}

assert_fail() {
  local msg="$1"; shift
  if "$@"; then
    echo "✘ $msg (expected FAIL, got OK)" >&2
    ((fail++))
  else
    echo "✔ $msg"
    ((pass++))
  fi
}

tmpd="$(mktemp -d)"
trap 'rm -rf "$tmpd"' EXIT

# Filesystem checks
touch "$tmpd/exists.txt"
assert_ok   "ci_check_file on existing file"  ci_check_file "$tmpd/exists.txt"
assert_fail "ci_check_file on missing file"  ci_check_file "$tmpd/missing.txt"
mkdir -p "$tmpd/adir"
assert_ok   "ci_check_dir on existing dir"   ci_check_dir "$tmpd/adir"
assert_fail "ci_check_dir on missing dir"    ci_check_dir "$tmpd/nodir"

# Grep/content checks
echo "enabled: true" > "$tmpd/conf.yaml"
assert_ok   "ci_check_grep finds string"     ci_check_grep "enabled: true" "$tmpd/conf.yaml"
assert_fail "ci_check_grep missing string"   ci_check_grep "nope" "$tmpd/conf.yaml"

# Command RC
assert_ok   "ci_check_command_rc OK"         ci_check_command_rc "true"
assert_fail "ci_check_command_rc FAIL"       ci_check_command_rc "false"

# Output contains / regex
assert_ok   "ci_check_output_contains"       ci_check_output_contains "world" echo "hello world"
assert_fail "ci_check_output_contains miss"  ci_check_output_contains "nope"  echo "hello world"
assert_ok   "ci_check_output_matches"        ci_check_output_matches 'v[0-9]+\.[0-9]+' bash -lc 'echo v1.2'
assert_fail "ci_check_output_matches miss"   ci_check_output_matches '^abc$'  bash -lc 'echo xyz'

# Retry (should succeed quickly)
count=0
sometimes_ok() { ((count++)); [[ $count -ge 2 ]]; }  # first fails, second ok
assert_ok   "ci_retry recovers"             ci_retry 3 1 sometimes_ok

echo
echo "Passed: $pass  Failed: $fail"
((fail == 0)) || exit 1
