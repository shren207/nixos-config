#!/usr/bin/env bash
# handoff-session-end.sh — Claude SessionEnd hook. handoff_full_snapshot_commit helper로 위임.
#
# DEC-S2 T4 + DEC-S5 P1 + DEC-S7 E2 + DEC-S13 staged ordering 적용:
#   1. snapshot 작성 (allowlist + redaction, umask 077)
#   2. handoff_compute_diff로 noise field 제외 후 빈 diff면 commit skip (idempotent)
#   3. git add → gitleaks protect --staged → 통과 시 commit (chore(handoff): prefix)
#   4. 실패 시 staged unstage + working tree quarantine
# non-blocking: 모든 실패 경로에서 exit 0.
# Codex Stop heuristic-trigger도 같은 helper를 호출한다 (DEC-S9 G2).

set -u

INPUT=""
[ ! -t 0 ] && INPUT=$(cat || true)

HOOK_DIR=$(dirname -- "${BASH_SOURCE[0]}")
LIB="${HOOK_DIR}/handoff-lib.sh"
if [ ! -f "$LIB" ]; then
  exit 0
fi
# shellcheck source=./handoff-lib.sh
. "$LIB" || exit 0

SESSION_ID=$(handoff_parse_session_id "$INPUT")
[ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_SESSION_ID:-}"
export HANDOFF_SESSION_ID="$SESSION_ID"

handoff_full_snapshot_commit "claude-code" >/dev/null 2>&1 || true

# turn-counter reset (full snapshot 후 카운터 초기화)
[ -n "$SESSION_ID" ] && handoff_reset_turn "$SESSION_ID" >/dev/null 2>&1 || true

exit 0
