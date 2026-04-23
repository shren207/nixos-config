#!/usr/bin/env bash
# Compatibility shim preserving the original slug-only contract.
# New public helper is write-handoff-repo-and-issue.sh (2-line REPO_SLUG + ISSUE_NUM).
# This shim restricts output to the first line (REPO_SLUG only) so that pre-existing
# handoff docs/runtimes that consume the legacy path continue to see the 1-line contract.

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
"$SCRIPT_DIR/write-handoff-repo-and-issue.sh" "$@" | head -n 1
