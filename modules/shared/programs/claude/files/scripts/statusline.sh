#!/usr/bin/env bash
# Claude Code custom statusline - plan 파일 경로 표시
# stdin으로 JSON 세션 데이터를 받아 statusbar 내용을 stdout으로 출력

input=$(cat)

# --- 필드 추출 ---
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
TRANSCRIPT=$(echo "$input" | jq -r '.transcript_path // empty')
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')

# --- Plan 파일 감지 (세션별 캐싱, transcript 크기 변화 시 재탐색) ---
# CIR: "filePath":"..." 패턴 선택 — 광범위 패턴('/[^"]*\.claude/plans/[^"]*\.md')은
#   transcript JSONL 내 git diff, CIR 주석, 파일 목록 등에서 대량의 false positive 발생.
#   "filePath":"..." 패턴은 Write/Edit tool result에만 존재하므로 정확히 plan 파일만 매치됨.
# CIR: tail -1로 최신 plan 파일 추출 — grep -m1은 첫 매치를 캐싱하여 세션 중 plan 변경 시
#   stale 경로를 표시. tail -1로 최신(마지막) plan 파일을 취하고, transcript 크기 변화 시
#   캐시를 무효화하여 재탐색.
PLAN_FILE=""
if [ -n "$SESSION_ID" ] && [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  CACHE="/tmp/claude-plan-${SESSION_ID}"
  T_SIZE=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)

  # Cache hit: transcript 크기 불변 → plan 변경 없음
  if [ -f "$CACHE" ]; then
    { read -r CACHED_SIZE; read -r CACHED_PLAN; } < "$CACHE"
    if [ "$T_SIZE" = "$CACHED_SIZE" ]; then
      PLAN_FILE="$CACHED_PLAN"
    fi
  fi

  # Cache miss 또는 transcript 변경: 최신 plan 경로 재탐색
  if [ -z "$PLAN_FILE" ]; then
    PLAN_FILE=$(grep -o '"filePath":"[^"]*\.claude/plans/[^"]*\.md"' "$TRANSCRIPT" 2>/dev/null \
      | tail -1 | sed 's/^"filePath":"//;s/"$//')
    if [ -n "$PLAN_FILE" ]; then
      printf '%s\n%s' "$T_SIZE" "$PLAN_FILE" > "$CACHE"
    fi
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
