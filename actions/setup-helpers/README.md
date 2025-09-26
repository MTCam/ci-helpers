# Setup CI Helpers Action

This composite action makes the shared `ci-helpers.sh` library available to
all subsequent `bash` steps in a GitHub Actions workflow.

It does three things:

1. **Verifies** that `ci/ci-helpers.sh` exists in the repo.
2. **Auto-sources** the helpers in all later `bash` steps by appending
   `source "<path>"` into `$BASH_ENV`.
3. **Exposes** the helper path via:
   - `steps.<id>.outputs.helpers_path`
   - the `CI_HELPERS_SH` environment variable

---

## Usage

In your workflow (`.github/workflows/ci.yml`):

```yaml
jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup CI helpers
        id: setup
        uses: yourorg/ci-helpers/actions/setup-helpers@v1

      - name: Verify files
        shell: bash
        run: |
          ci_check_file README.md
          ci_require_cmd git

      - name: Run command
        shell: bash
        run: |
          ci_check_command_rc "make -j"

      - name: Use helpers path explicitly
        shell: bash
        run: |
          echo "Helpers are at: ${{ steps.setup.outputs.helpers_path }}"
          echo "Env var says:   $CI_HELPERS_SH"
