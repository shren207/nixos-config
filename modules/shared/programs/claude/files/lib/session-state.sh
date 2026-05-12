#!/usr/bin/env bash
# shellcheck disable=SC2034
# SC2034: 본 파일의 상수는 source되는 hook과 statusline에서만 참조한다.
# 정적 분석은 직접 사용처를 보지 못해 false positive로 unused를 보고하므로
# 파일 전체에 대해 disable한다.
#
# Session state shared helpers — SessionStart hook(session-init-icons.sh), Stop
# hook(record-last-session.sh), statusline.sh(validate_session_id 정책)가
# 공유하는 상수·함수의 SSOT. 한쪽에서 변경하면 lineage 복원/sidecar I/O가
# silently 어긋나는 위험을 코드 레벨에서 차단한다.
#
# 공개 API
# ─────────
#   상수:
#     SESSION_STATE_DIR              — `~/.claude/status-icons`. status JSON + 마커 위치.
#     SESSION_MEMO_DIR               — `~/.claude/memos`. 세션 메모 위치.
#     SESSION_LOG_DIR                — `~/.claude/logs`. 디버그 로그 위치(retention
#                                       정리 대상 아님 — single append-only file 모델).
#     SESSION_MARKER_PREFIX          — `.last-session-`. cwd 마커 파일명 prefix.
#     SESSION_ARTIFACT_RETENTION_DAYS=30 — status JSON / memo / 마커 공통 retention.
#   함수:
#     hash_cwd <path>                — cwd → sha1 hex(macOS shasum 우선, Linux sha1sum
#                                       fallback). 둘 다 부재 시 빈 문자열 반환.
#     marker_path_for_cwd <path>     — cwd → 마커 절대경로. encoded 실패 시 return 1.
#     is_safe_session_id <sid>       — 정책 SSOT (0=safe, 1=unsafe). allowlist
#                                       `[A-Za-z0-9._-]` + `..` 차단.
#     session_hook_log <event> <msg> — `CLAUDE_HOOK_DEBUG=1` 게이트. 단일 message
#                                       문자열만 받는다(공백/특수문자 포함 가능).
#                                       허용 event: `session-start`, `session-start-unsafe`,
#                                       `stop`.
#
# Source 방법(pinning-{guard,alert}.sh가 lib/pinning-patterns.sh를 source하는
# 패턴과 동일 — `$HOME/.claude/lib` 우선 + repo fallback):
#   SESSION_STATE_LIB="${SESSION_STATE_LIB:-$HOME/.claude/lib/session-state.sh}"
#   [ -f "$SESSION_STATE_LIB" ] || SESSION_STATE_LIB="<script_dir>/../lib/session-state.sh"
#   . "$SESSION_STATE_LIB"

# 공유 상수
SESSION_STATE_DIR="$HOME/.claude/status-icons"
SESSION_MEMO_DIR="$HOME/.claude/memos"
# SESSION_LOG_DIR은 retention 정리 대상이 아니다 — append-only single file이라
# mtime 기반 정리 모델이 부적합. 누적 우려 시 size-based rotation은 별도 follow-up.
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
# 본 검증의 SSOT — hook과 statusline은 모두 이 함수를 source해서 호출한다.
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
#
# Invariant:
# - 첫 인자는 event 라벨(허용 enum: session-start / session-start-unsafe / stop).
# - 두 번째 인자는 단일 message 문자열. 호출자가 `k=v k=v` 형태를 그대로 넘긴다.
#   reader 측에서 `awk '{ts=$1; ev=$2; rest=$0}'` 형태로 파싱하면 첫 두 토큰만
#   고정 필드, rest는 free-form. 값에 공백이 들어가도 단일 인자라면 한 줄로 기록.
# - unsafe sid 진단 로그처럼 message에 control 문자(특히 newline)가 포함될
#   가능성이 있는 호출을 대비해 message를 sanitize한다 — control 문자를
#   `?`로 치환해 단일 라인 invariant를 강제한다 (tr -d 대신 치환으로 위치
#   정보를 보존). reader는 한 라인 = 한 이벤트 가정을 안전하게 유지.
session_hook_log() {
  [ "${CLAUDE_HOOK_DEBUG:-0}" = "1" ] || return 0
  mkdir -p "$SESSION_LOG_DIR" 2>/dev/null || return 0
  chmod 700 "$SESSION_LOG_DIR" 2>/dev/null || true
  local msg
  # POSIX [:cntrl:]는 \n \r \t \0 등 control 문자 전체를 매치. LC_ALL=C로
  # multibyte 영향 격리. 치환 후 단일 라인 보장.
  msg=$(printf '%s' "$2" | LC_ALL=C tr '[:cntrl:]' '?')
  printf '%s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$msg" \
    >> "$SESSION_LOG_DIR/session-hooks.log" 2>/dev/null || true
}
