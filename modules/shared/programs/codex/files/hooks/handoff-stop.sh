#!/usr/bin/env bash
# handoff-stop.sh — Codex Stop hook entry. _stop-dispatcher.sh의 H2 위치에서 호출.
#
# 책임 경계 (Codex SessionEnd 미지원에 대한 DEC-S6 B refined):
#   - 기본: turn-counter 외부 state file 누적 + metadata-only (commit 없음)
#   - turn-counter ≥ HANDOFF_TURN_THRESHOLD 또는 transcript_path mtime ≥ HANDOFF_IDLE_TIMEOUT_SECONDS
#     → handoff_full_snapshot_commit "codex" 호출 (full snapshot + redaction + add + gitleaks --staged + commit)
#   - 실패 시 staged unstage + working tree quarantine, 모든 실패 경로 exit 0 (non-blocking)
#
# Codex 가드: epic #584 패턴. CLAUDECODE/CODEX_PROGRAMMATIC=1이면 early-exit (programmatic 호출 노이즈 차단).
# Keep in sync with ~/.claude/hooks/handoff-stop.sh — Claude은 metadata-only만 수행 (SessionEnd가 별도). drift fixture가 entrypoint 차이를 검증.

set -u

if [ "${CLAUDECODE:-}" = "1" ] || [ "${CODEX_PROGRAMMATIC:-}" = "1" ]; then
  exit 0
fi

INPUT=""
[ ! -t 0 ] && INPUT=$(cat || true)

HOOK_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")")
LIB="${HOOK_DIR}/handoff-lib.sh"
if [ ! -f "$LIB" ]; then
  exit 0
fi
# shellcheck source=./handoff-lib.sh
. "$LIB" || exit 0

SESSION_ID=$(handoff_parse_session_id "$INPUT")
[ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_SESSION_ID:-}"
export HANDOFF_SESSION_ID="$SESSION_ID"

TRANSCRIPT_PATH=$(handoff_parse_transcript_path "$INPUT")

# DEC-S6 B refined: turn-counter + transcript mtime trigger.
if handoff_should_trigger_full "$SESSION_ID" "$TRANSCRIPT_PATH"; then
  handoff_full_snapshot_commit "codex" >/dev/null 2>&1 || true
  handoff_reset_turn "$SESSION_ID" >/dev/null 2>&1 || true
fi

exit 0
