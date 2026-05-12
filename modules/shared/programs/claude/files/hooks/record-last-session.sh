#!/usr/bin/env bash
# Claude Code Stop Hook - cwd 단위 last-session 마커 기록
#
# /clear는 새 session_id를 발급하지만 Claude Code의 SessionStart hook stdin
# schema에는 previous_session_id 류 필드가 없다. 그래서 SessionStart 시점에는
# 직전 sid를 알 수 없다. Stop hook을 매 turn 종료에 발동시켜 cwd-encoded
# 마커 파일에 last_session_id를 누적 갱신해두면, /clear 직후 SessionStart hook이
# "같은 cwd의 직전 sid"를 정확히 식별할 수 있다.
#
# cwd 단위 격리이므로 동시 진행 중인 다른 워크트리/프로젝트 세션과 마커가
# 섞이지 않는다.

set -euo pipefail
umask 077

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat)
fi

if [ -z "$INPUT" ]; then
  exit 0
fi

# subagent 내부 Stop은 무시 (메인 턴만 추적)
AGENT_ID=$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null) || true
[ -n "$AGENT_ID" ] && exit 0

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || true
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null) || true

if [ -z "$SESSION_ID" ] || [ -z "$CWD" ]; then
  exit 0
fi

# session_id allowlist (path traversal 방어 — 마커 파일/sidecar 경로에 사용됨)
case "$SESSION_ID" in
  *[!A-Za-z0-9._-]*) exit 0 ;;
  *..*) exit 0 ;;
esac

STATE_DIR="$HOME/.claude/status-icons"
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR" 2>/dev/null || true

# cwd 인코딩 — sha1 hash. macOS는 shasum 우선, Linux는 sha1sum.
# 둘 다 부재하면 graceful skip (lineage 복원 자체가 비활성).
hash_cwd() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum | awk '{print $1}'
  elif command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha1sum | awk '{print $1}'
  fi
}
ENCODED_CWD=$(hash_cwd "$CWD")
if [ -z "$ENCODED_CWD" ]; then
  exit 0
fi
MARKER_FILE="$STATE_DIR/.last-session-${ENCODED_CWD}"

# atomic write — 같은 디렉토리의 mktemp로 cross-device rename 회피
tmp=$(mktemp "$STATE_DIR/.last-session-XXXXXX")
printf '%s\n' "$SESSION_ID" > "$tmp"
mv "$tmp" "$MARKER_FILE"
chmod 600 "$MARKER_FILE" 2>/dev/null || true

# optional debug log — CLAUDE_HOOK_DEBUG=1 일 때만 활성화
if [ "${CLAUDE_HOOK_DEBUG:-0}" = "1" ]; then
  LOG_DIR="$HOME/.claude/logs"
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  chmod 700 "$LOG_DIR" 2>/dev/null || true
  printf '%s stop sid=%s cwd=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION_ID" "$CWD" \
    >> "$LOG_DIR/session-hooks.log" 2>/dev/null || true
fi

exit 0
