#!/bin/bash
# Claude Code custom statusline - plan 파일 경로 표시
# stdin으로 JSON 세션 데이터를 받아 statusbar 내용을 stdout으로 출력

input=$(cat)

# --- 필드 추출 ---
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
TRANSCRIPT=$(echo "$input" | jq -r '.transcript_path // empty')
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')

# --- Plan 파일 감지 (세션별 캐싱) ---
# CIR: "filePath":"..." 패턴 선택 — 광범위 패턴('/[^"]*\.claude/plans/[^"]*\.md')은
#   transcript JSONL 내 git diff, CIR 주석, 파일 목록 등에서 대량의 false positive 발생.
#   "filePath":"..." 패턴은 Write/Edit tool result에만 존재하므로 정확히 plan 파일만 매치됨.
PLAN_FILE=""
if [ -n "$SESSION_ID" ]; then
  CACHE="/tmp/claude-plan-${SESSION_ID}"
  if [ -f "$CACHE" ]; then
    PLAN_FILE=$(cat "$CACHE")
  elif [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    PLAN_FILE=$(grep -om1 '"filePath":"[^"]*\.claude/plans/[^"]*\.md"' "$TRANSCRIPT" 2>/dev/null \
      | sed 's/^"filePath":"//;s/"$//')
    [ -n "$PLAN_FILE" ] && printf '%s' "$PLAN_FILE" > "$CACHE"
  fi
fi

# --- 출력 ---
LINE="[$MODEL]"

# Plan 파일이 존재하면 OSC 8 클릭 가능 링크로 경로 추가
if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
  DISPLAY_PATH="${PLAN_FILE/#$HOME/~}"
  # printf '%b' 일관 사용: echo -e와 혼용 시 이중 해석 위험
  printf '%b' "[$MODEL] | \e]8;;file://${PLAN_FILE}\a${DISPLAY_PATH}\e]8;;\a\n"
else
  printf '%s\n' "$LINE"
fi
