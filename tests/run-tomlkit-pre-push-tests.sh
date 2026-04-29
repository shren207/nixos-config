#!/usr/bin/env bash
# tests/run-tomlkit-pre-push-tests.sh
# Pre-push wrapper for test suites that require the shared tomlkit runtime.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091  # source file is fixed inside the repository.
. "$REPO_ROOT/scripts/ai/lib/tomlkit-bootstrap.sh"
tomlkit_bootstrap_require "$REPO_ROOT" "${BASH_SOURCE[0]}" "$@"

bash "$SCRIPT_DIR/run-shell-script-tests.sh"
bash "$SCRIPT_DIR/test-codex-hook-fixtures.sh" --no-live
