[![Lint (shellcheck)](https://github.com/MTCam/ci-helpers/actions/workflows/lint.yml/badge.svg)](https://github.com/MTCam/ci-helpers/actions/workflows/lint.yml)
[![Test (helpers & actions)](https://github.com/MTCam/ci-helpers/actions/workflows/test.yml/badge.svg)](https://github.com/MTCam/ci-helpers/actions/workflows/test.yml)

# CI Helpers

A collection of reusable Bash helpers and GitHub Actions for CI pipelines.

This repo gives you a **standard library** of functions and actions for
common tasks in CI:

- Checking for file/directory existence
- Running commands and checking return codes
- Grepping files for content
- Checking command output
- Retrying flaky commands
- Logging utilities (`ci_log_info`, `ci_log_error`, etc.)

All helpers follow Unix conventions: **0 = success, non-zero = failure**.

---

## Usage Modes

You can use these helpers in **two ways**:

### 1. As Composite Actions

Call helpers directly in workflows via `uses:`.

Example:

```yaml
jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Ensure README exists
        uses: MTCam/ci-helpers/actions/check-file@v1
        with:
          path: README.md

      - name: Validate config
        uses: MTCam/ci-helpers/actions/grep-file@v1
        with:
          needle: "enabled: true"
          file: config.yaml

      - name: Build
        uses: MTCam/ci-helpers/actions/run-cmd@v1
        with:
          cmd: "make -j"
```

#### Available actions:

   - actions/check-file

   - actions/grep-file

   - actions/run-cmd

   - actions/output-contains

   - actions/setup-helpers

### 2. Source Shell Library (via Setup)

```yaml
# .github/workflows/ci.yml
name: CI with Sourced Library
on: [push, pull_request]
jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup helpers
        id: setup
        uses: yourorg/ci-helpers/actions/setup-helpers@v1

      - name: Use helpers
        shell: bash
        run: |
          ci_check_file README.md
          ci_check_grep "enabled: true" config.yaml
          ci_require_cmd git
          ci_check_command_rc "make -j"
          ci_check_output_contains "ready" my_service --status

      - name: Show helper path (optional)
        shell: bash
        run: |
          echo "Helpers at: ${{ steps.setup.outputs.helpers_path }}"
          echo "Env says:   $CI_HELPERS_SH"
```