#!/usr/bin/env bash
# Compatibility shim preserving the original slug-only contract.
# New public helper: write-handoff-repo-and-issue.sh (2-line REPO_SLUG + ISSUE_NUM).
# This shim restricts output to REPO_SLUG only so pre-existing handoff docs/runtimes
# that consume the legacy path keep seeing the 1-line contract.
#
# External consumers: issue comments posted by write-handoff before the rename
# (legacy NSS snippets that call `~/.claude/scripts/write-handoff-repo-slug.sh`
# or `~/.codex/scripts/write-handoff-repo-slug.sh`).
#
# Removal criteria: once no active handoff document references the legacy path
# (audit outstanding open issues / comments for callers of this filename), retire
# this shim and the provisioning entries in
# modules/shared/programs/claude/default.nix + modules/shared/programs/codex/default.nix
# along with the verify-ai-compat.sh check.
#
# Self-contained fallback: if the new sibling helper is not yet provisioned
# (e.g. repo code updated but nrs/symlink refresh pending), run the original
# slug-only logic inline to preserve the contract.

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
NEW_HELPER="$SCRIPT_DIR/write-handoff-repo-and-issue.sh"

if [ -x "$NEW_HELPER" ]; then
  "$NEW_HELPER" "$@" | head -n 1
  exit 0
fi

# Fallback: reproduce original slug-only logic when sibling helper is absent.
set -o pipefail

slug=""
issue_arg="${1:-}"

if [ -n "$issue_arg" ]; then
  url=$(gh issue view "$issue_arg" --json url -q .url 2>/dev/null || true)
  parsed=$(printf '%s\n' "$url" | sed -nE 's|^https?://[^/]+/([^/]+/[^/]+)/.*$|\1|p')
  case "$parsed" in
    null|'') ;;
    *) slug="$parsed" ;;
  esac
else
  fallback=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
  case "$fallback" in
    null|'') ;;
    *) slug="$fallback" ;;
  esac
fi

printf '%s\n' "$slug"
exit 0
