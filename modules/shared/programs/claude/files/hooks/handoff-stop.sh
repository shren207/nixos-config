#!/usr/bin/env bash
# handoff-stop.sh — Claude Stop hook entry. metadata-only 갱신 (commit 없음).
#
# Position in Stop chain (DEC-S11): record-last-stop → handoff-stop → stop-notification → nrs-session-cleanup.
# Claude는 sequential이라 lock cleanup 의존 없음 → record 직후가 단순. Codex는 dispatcher H2(`record-last-stop → nrs-session-cleanup → handoff-stop → stop-notification`) 위치에서 호출 (issue #590 ordering rationale).
#
# 책임 경계: 본 entry는 매 Stop마다 metadata-only로 frontmatter만 갱신. full snapshot/commit은 SessionEnd hook의 handoff-session-end.sh가 담당. non-blocking + idempotent + exit 0 보장.

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

# session_id parsing
SESSION_ID=$(handoff_parse_session_id "$INPUT")
if [ -z "$SESSION_ID" ]; then
  SESSION_ID="${CLAUDE_SESSION_ID:-}"
fi

# turn-counter 증가 (외부 state file 누적). full snapshot trigger는 SessionEnd가 담당하므로 본 entry는 카운터만 갱신.
handoff_increment_turn "$SESSION_ID" >/dev/null 2>&1 || true

exit 0
