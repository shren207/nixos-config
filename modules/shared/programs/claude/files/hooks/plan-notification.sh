#!/usr/bin/env bash
# Claude Code PreToolUse Hook - ExitPlanMode Pushover 알림
# 계획 승인을 요청할 때 계획 파일 내용과 함께 Pushover 알림을 보냅니다.
#
# [중요] PreToolUse hook의 stdout은 tool call을 수정/차단할 수 있으므로,
# 모든 외부 명령 출력을 반드시 /dev/null로 리다이렉트해야 합니다.

# UTF-8 인코딩 강제 설정 (Claude Code 환경에서 LANG이 미설정될 수 있음)
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Pushover 메시지 최대 길이
MAX_MESSAGE_CHARS=1024

# agenix로 관리되는 credentials 로드
CREDENTIALS_FILE="$HOME/.config/pushover/claude-code"
PUSHOVER_API_URL="${PUSHOVER_API_URL:-https://api.pushover.net/1/messages.json}"

PUSHOVER_AVAILABLE=false
if [ -f "$CREDENTIALS_FILE" ]; then
  # shellcheck source=/dev/null
  source "$CREDENTIALS_FILE"
  PUSHOVER_AVAILABLE=true
fi

# --- 유틸리티 함수 ---

# UTF-8 길이 계산 (jq 미설치 시 bash 길이로 폴백)
str_len() {
  local s="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -Rrn --arg s "$s" '$s | length' 2>/dev/null || printf '%s' "${#s}"
  else
    printf '%s' "${#s}"
  fi
}

# UTF-8 기준 앞에서 n자 유지 (처음부터 n자)
clip_head_chars() {
  local s="$1"
  local n="$2"

  if [ "$n" -le 0 ]; then
    printf ''
    return 0
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -Rrn --arg s "$s" --argjson n "$n" '
      if ($s | length) <= $n then $s else $s[:$n] end
    ' 2>/dev/null || printf '%s' "${s:0:$n}"
  else
    # bash substring expansion: LC_ALL=en_US.UTF-8 환경에서 문자 단위로 동작
    printf '%s' "${s:0:$n}"
  fi
}

# 줄바꿈/제어문자 정리
normalize_text() {
  local s="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -Rrn --arg s "$s" '
      $s
      | gsub("\u0000"; "")
      | gsub("\r"; "")
      | gsub("\n{3,}"; "\n\n")
    ' 2>/dev/null || printf '%s' "$s"
  else
    printf '%s' "$s"
  fi
}

# --- 정보 수집 ---
HOST=$(hostname -s 2>/dev/null || echo "?")
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -n "$GIT_ROOT" ]; then
  REPO=$(basename "$GIT_ROOT")
  BRANCH=$(git branch --show-current 2>/dev/null)
  # detached HEAD: git branch --show-current는 exit 0이지만 빈 문자열 반환
  if [ -z "$BRANCH" ]; then
    BRANCH=$(git rev-parse --short HEAD 2>/dev/null || echo "?")
  fi
  BASE_MESSAGE="🖥️ $HOST
📁 $REPO · 🌿 $BRANCH"
else
  DIR=$(basename "$PWD")
  BASE_MESSAGE="🖥️ $HOST
📁 $DIR"
fi

# --- Plan 파일 읽기 ---
PROJECT_DIR="${GIT_ROOT:-$PWD}"
PLAN_TEXT=""

# Claude Code가 plan 파일명을 생성하므로 특수문자 없음 (e.g. effervescent-stargazing-aho.md)
if [ -d "$PROJECT_DIR/.claude/plans" ]; then
  PLAN_FILE=$(ls -t "$PROJECT_DIR/.claude/plans/"*.md 2>/dev/null | head -1)
  if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
    # 대용량 파일 방어: 8KB로 제한 (1024자 예산 대비 충분, ARG_MAX/jq 처리 지연 방지)
    PLAN_TEXT=$(head -c 8192 "$PLAN_FILE" 2>/dev/null || true)
    PLAN_TEXT=$(normalize_text "$PLAN_TEXT")
  fi
fi

# --- 메시지 구성 ---
if [ -n "$PLAN_TEXT" ]; then
  PREFIX="$BASE_MESSAGE
📝 "
  PREFIX_LEN=$(str_len "$PREFIX")
  ELLIPSIS="…"
  ELLIPSIS_LEN=1  # U+2026, 1 codepoint
  BUDGET=$((MAX_MESSAGE_CHARS - PREFIX_LEN - ELLIPSIS_LEN))
  if [ "$BUDGET" -lt 0 ]; then
    BUDGET=0
  fi

  PLAN_TEXT_LEN=$(str_len "$PLAN_TEXT")
  if [ "$PLAN_TEXT_LEN" -gt "$BUDGET" ]; then
    CLIPPED_PLAN="$(clip_head_chars "$PLAN_TEXT" "$BUDGET")${ELLIPSIS}"
  else
    CLIPPED_PLAN="$PLAN_TEXT"
  fi
  MESSAGE="${PREFIX}${CLIPPED_PLAN}"
else
  MESSAGE="$BASE_MESSAGE"
fi

# 최종 안전망: 전체 메시지 1024자 상한 보장
MESSAGE="$(clip_head_chars "$MESSAGE" "$MAX_MESSAGE_CHARS")"

# CIR: hs.notify+Pushover 중복 해소 미구현 의사결정 → stop-notification.sh 참조

# macOS 로컬 데스크탑 알림 (Hammerspoon hs.notify)
# hs 미설치/에러 시 무시 — Pushover 전송에 영향 주지 않도록
if [[ "$OSTYPE" == darwin* ]] && command -v hs >/dev/null 2>&1; then
  # REPO가 있으면 "repo · branch", 없으면 빈 subtitle
  HS_SUBTITLE="${REPO:+$REPO}${BRANCH:+ · $BRANCH}"
  HS_ICON="$HOME/.claude/assets/notification-icon.png"
  # Lua string 삽입 시 single quote/backslash를 제거 (hs -c는 IPC 기반이라 os.getenv 불가)
  HS_SUBTITLE_SAFE="${HS_SUBTITLE//\'/}"
  HS_SUBTITLE_SAFE="${HS_SUBTITLE_SAFE//\\/}"
  hs -c "
    local n = hs.notify.new({
      title = 'Claude Code [🙏계획 승인 요청]',
      subTitle = '${HS_SUBTITLE_SAFE}',
      soundName = 'Glass',
      -- CIR: withdrawAfter 의사결정 → stop-notification.sh Lua 블록 참조
      withdrawAfter = 0
    })
    local img = hs.image.imageFromPath('${HS_ICON}')
    if img then n:contentImage(img) end
    n:send()
  " >/dev/null 2>&1 || true
fi

if [ "$PUSHOVER_AVAILABLE" = true ]; then
  curl -s --max-time 4 -X POST \
    -H "Content-Type: application/x-www-form-urlencoded; charset=utf-8" \
    --data-urlencode "token=$PUSHOVER_TOKEN" \
    --data-urlencode "user=$PUSHOVER_USER" \
    --data-urlencode "title=Claude Code [🙏계획 승인 요청]" \
    --data-urlencode "priority=0" \
    --data-urlencode "sound=falling" \
    --data-urlencode "message=$MESSAGE" \
    "$PUSHOVER_API_URL" > /dev/null
fi

exit 0
