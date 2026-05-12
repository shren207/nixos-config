#!/usr/bin/env bash
# shellcheck disable=SC2034
# SC2034: 본 파일의 상수는 source되는 hook에서만 참조한다. shellcheck는 직접
# 사용처를 보지 못해 false positive로 unused를 보고. lib 파일 전체에 대해 disable.
#
# Session state shared helpers for SessionStart hook(session-init-icons.sh)과
# Stop hook(record-last-session.sh)이 공유하는 상수·함수.
#
# 이 파일이 invariant의 SSOT다 — marker 경로 규약, session_id allowlist,
# cwd 인코딩, 디버그 로그 포맷을 두 hook이 동일 정의로 공유한다. 한쪽에서
# 변경하면 lineage 복원이 silently 깨지는 위험을 코드 레벨에서 차단한다.
#
# Source 방법:
#   . "$(dirname "$0")/lib/session-state.sh"
# pinning-{guard,alert}.sh가 lib/pinning-patterns.sh를 source하는 패턴과 동일.

# 공유 상수
SESSION_STATE_DIR="$HOME/.claude/status-icons"
SESSION_MEMO_DIR="$HOME/.claude/memos"
SESSION_LOG_DIR="$HOME/.claude/logs"
SESSION_MARKER_PREFIX=".last-session-"
SESSION_ARTIFACT_RETENTION_DAYS=30

# cwd → sha1 hex. shasum 우선, sha1sum fallback. 둘 다 부재 시 빈 문자열
# (호출부에서 lineage 복원/마커 기록을 graceful skip).
hash_cwd() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum | awk '{print $1}'
  elif command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha1sum | awk '{print $1}'
  fi
}

# cwd → marker 파일 절대 경로
marker_path_for_cwd() {
  local encoded
  encoded=$(hash_cwd "$1")
  [ -z "$encoded" ] && return 1
  printf '%s/%s%s' "$SESSION_STATE_DIR" "$SESSION_MARKER_PREFIX" "$encoded"
}

# session_id가 sidecar/marker 파일명에 안전한지 검사 (0=safe, 1=unsafe).
# 정책: allowlist `[A-Za-z0-9._-]` only + `..` 시퀀스 차단(path traversal 방어).
# 본 검증의 SSOT — hook과 statusline은 모두 이 함수 또는 동일 정책을 따른다.
is_safe_session_id() {
  case "$1" in
    "") return 1 ;;
    *[!A-Za-z0-9._-]*) return 1 ;;
    *..*) return 1 ;;
  esac
  return 0
}

# CLAUDE_HOOK_DEBUG=1일 때만 활성화되는 진단 로그.
# 실제 source 라벨링/cwd 동작을 실측하기 위한 영구 진단 인프라.
# 첫 인자는 이벤트명(예: session-start, stop), 나머지는 자유 key=value pair.
session_hook_log() {
  [ "${CLAUDE_HOOK_DEBUG:-0}" = "1" ] || return 0
  mkdir -p "$SESSION_LOG_DIR" 2>/dev/null || return 0
  chmod 700 "$SESSION_LOG_DIR" 2>/dev/null || true
  printf '%s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "${*:2}" \
    >> "$SESSION_LOG_DIR/session-hooks.log" 2>/dev/null || true
}
