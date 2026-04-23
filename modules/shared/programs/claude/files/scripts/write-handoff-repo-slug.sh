#!/usr/bin/env bash
# Compatibility shim. New public helper name is write-handoff-repo-and-issue.sh.
# Keep this path for older handoff docs / already-provisioned runtimes.

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
exec "$SCRIPT_DIR/write-handoff-repo-and-issue.sh" "$@"
