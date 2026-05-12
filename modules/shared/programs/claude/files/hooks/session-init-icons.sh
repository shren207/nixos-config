#!/usr/bin/env bash
# Claude Code SessionStart Hook - Status bar icons 초기화/복원
# stdin: JSON (session_id, transcript_path, source, cwd 등)
# stdout: JSON (hookSpecificOutput with additionalContext)
#
# 권한 정책:
# - umask 077 + chmod 700 디렉토리 / 600 파일. status JSON에는 Jira/Slack/Figma
#   private URL이, memo MD에는 세션 메모가 담길 수 있어 동일 사용자만 접근 가능.
#
# Lineage 복원 (cwd-encoded marker):
# - Stop hook(record-last-session.sh)이 매 턴 종료에 cwd-encoded 마커 파일에
#   last_session_id를 기록한다. /clear가 새 session_id를 발급해 STATE_FILE이
#   부재할 때, 같은 cwd 마커의 sid에서 sidecar/memo를 deep clone 복원한다.
# - 글로벌 mtime 기반 탐색은 cross-cwd 누수를 일으키므로 사용하지 않는다.
#
# Retention 정책:
# - SESSION_ARTIFACT_RETENTION_DAYS=30: status-icons JSON, memo MD, marker 파일에
#   동일 적용. 변경 시 storage 누적 영향 검토.

set -euo pipefail
umask 077

SESSION_ARTIFACT_RETENTION_DAYS=30

# jq 필수 — 없으면 graceful skip
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# stdin JSON 읽기
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat)
fi

if [ -z "$INPUT" ]; then
  exit 0
fi

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || true
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null) || true
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null) || true
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null) || true

# session_id resolution — statusline.sh와 동일 fallback (D-8)
# stdin.session_id 우선, 비어있으면 transcript basename — 단, transcript는
# .jsonl 확장자 + $HOME/.claude/projects/ 하위에 있을 때만 fallback 허용
# (audit Edge Cases-3: non-jsonl/outside transcript basename으로 sidecar 생성 방지)
if [ -z "$SESSION_ID" ] && [ -n "$TRANSCRIPT" ]; then
  case "$TRANSCRIPT" in
    "$HOME"/.claude/projects/*/*.jsonl)
      SESSION_ID=$(basename "$TRANSCRIPT" .jsonl)
      ;;
  esac
fi
# 패턴 검증 — sidecar 파일명에 사용되므로 safe filename 보장
case "$SESSION_ID" in
  *[!A-Za-z0-9._-]*) SESSION_ID="" ;;
  *..*) SESSION_ID="" ;;
esac
if [ -z "$SESSION_ID" ]; then
  exit 0
fi

STATE_DIR="$HOME/.claude/status-icons"
MEMO_DIR="$HOME/.claude/memos"
STATE_FILE="$STATE_DIR/$SESSION_ID.json"
MEMO_FILE="$MEMO_DIR/$SESSION_ID.md"

mkdir -p "$STATE_DIR" "$MEMO_DIR"
chmod 700 "$STATE_DIR" "$MEMO_DIR" 2>/dev/null || true

# cwd-encoded marker lookup helper (Stop hook과 동일 인코딩)
hash_cwd() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum | awk '{print $1}'
  elif command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha1sum | awk '{print $1}'
  fi
}

# 같은 cwd의 직전 sid sidecar를 deep clone 복원 (성공 시 RESTORED=true)
# - LAST_SID 검증 (allowlist + 자기 자신 제외)
# - memo 파일은 원본 내용을 새 sid 파일로 cp (참조 충돌 방지)
# - status JSON은 통째 복사 + .memo.path만 새 경로로 rewrite
# - jq 실패 시 fallback은 호출부에서 처리
restore_from_cwd_lineage() {
  [ -z "$CWD" ] && return 1
  local encoded marker last_sid last_state old_memo
  encoded=$(hash_cwd "$CWD")
  [ -z "$encoded" ] && return 1
  marker="$STATE_DIR/.last-session-${encoded}"
  [ -f "$marker" ] || return 1
  last_sid=$(head -1 "$marker" 2>/dev/null | tr -d '[:space:]') || return 1
  [ -z "$last_sid" ] && return 1
  case "$last_sid" in
    *[!A-Za-z0-9._-]*) return 1 ;;
    *..*) return 1 ;;
  esac
  [ "$last_sid" = "$SESSION_ID" ] && return 1
  last_state="$STATE_DIR/${last_sid}.json"
  [ -f "$last_state" ] || return 1

  old_memo=$(jq -r '.memo.path // empty' "$last_state" 2>/dev/null) || old_memo=""
  if [ -n "$old_memo" ] && [ -f "$old_memo" ]; then
    cp "$old_memo" "$MEMO_FILE"
  else
    touch "$MEMO_FILE"
  fi
  jq --arg new_memo "$MEMO_FILE" \
    'if .memo then .memo.path = $new_memo else . end' \
    "$last_state" > "$STATE_FILE" 2>/dev/null
}

# optional debug log — CLAUDE_HOOK_DEBUG=1 일 때만 활성화
# 실제 source 라벨링/cwd 동작을 실측하기 위한 진단 인프라.
if [ "${CLAUDE_HOOK_DEBUG:-0}" = "1" ]; then
  LOG_DIR="$HOME/.claude/logs"
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  chmod 700 "$LOG_DIR" 2>/dev/null || true
  printf '%s session-start src=%s sid=%s cwd=%s state_exists=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SOURCE" "$SESSION_ID" "$CWD" \
    "$([ -f "$STATE_FILE" ] && echo y || echo n)" \
    >> "$LOG_DIR/session-hooks.log" 2>/dev/null || true
fi

case "$SOURCE" in
  startup)
    # STATE_FILE 존재 시 보존 (어떤 source가 startup으로 라벨되어도 기존 아이콘
    # 유실 방지). 부재 시에만 lineage 복원을 시도하고, 실패하면 빈 객체로 시작.
    if [ ! -f "$STATE_FILE" ]; then
      if ! restore_from_cwd_lineage; then
        echo '{}' > "$STATE_FILE"
        [ ! -f "$MEMO_FILE" ] && touch "$MEMO_FILE"
      fi
    fi
    [ ! -f "$MEMO_FILE" ] && touch "$MEMO_FILE"
    chmod 600 "$STATE_FILE" "$MEMO_FILE" 2>/dev/null || true

    # 30일 초과 파일 정리 (status-icons + memos + lineage 마커)
    find "$STATE_DIR" -maxdepth 1 -type f -name '*.json' \
      -mtime "+${SESSION_ARTIFACT_RETENTION_DAYS}" -delete 2>/dev/null || true
    find "$STATE_DIR" -maxdepth 1 -type f -name '.last-session-*' \
      -mtime "+${SESSION_ARTIFACT_RETENTION_DAYS}" -delete 2>/dev/null || true
    find "$MEMO_DIR" -maxdepth 1 -type f -name '*.md' \
      -mtime "+${SESSION_ARTIFACT_RETENTION_DAYS}" -delete 2>/dev/null || true

    if [ -f "$STATE_FILE" ]; then
      ACTIVE_ICONS=$(jq -r 'keys | join(", ")' "$STATE_FILE" 2>/dev/null) || ACTIVE_ICONS=""
      [ -z "$ACTIVE_ICONS" ] && ACTIVE_ICONS="없음"
    else
      ACTIVE_ICONS="없음"
    fi

    CONTEXT="Status bar icons 초기화됨.
상태 파일: $STATE_FILE
메모: $MEMO_FILE
활성 아이콘: $ACTIVE_ICONS
링크 설정: /set-icons 스킬로 Jira, Slack, Figma 링크를 추가할 수 있습니다."
    ;;

  clear|resume|compact)
    # /resume과 /compact는 같은 session_id를 유지하므로 STATE_FILE이 보통 존재
    # → 그대로 사용. /clear는 새 session_id를 발급하여 STATE_FILE이 부재 →
    # 같은 cwd 마커의 직전 sid에서 lineage 복원. 다른 cwd 마커와는 자연 격리됨.
    if [ ! -f "$STATE_FILE" ]; then
      if ! restore_from_cwd_lineage; then
        echo '{}' > "$STATE_FILE"
        [ ! -f "$MEMO_FILE" ] && touch "$MEMO_FILE"
      fi
      chmod 600 "$STATE_FILE" "$MEMO_FILE" 2>/dev/null || true
    fi

    ACTIVE_ICONS="없음"
    if [ -f "$STATE_FILE" ]; then
      ACTIVE_ICONS=$(jq -r 'keys | join(", ")' "$STATE_FILE" 2>/dev/null) || ACTIVE_ICONS="없음"
      [ -z "$ACTIVE_ICONS" ] && ACTIVE_ICONS="없음"
    fi

    CONTEXT="Status icons 복원됨.
상태 파일: $STATE_FILE
메모: $MEMO_FILE
활성 아이콘: $ACTIVE_ICONS"
    ;;

  *)
    # 알 수 없는 source — skip
    exit 0
    ;;
esac

# additionalContext 출력
jq -n --arg ctx "$CONTEXT" \
  '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$ctx}}'

exit 0
