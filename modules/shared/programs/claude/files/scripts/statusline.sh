#!/usr/bin/env bash
# Claude Code custom statusline - plan 파일 경로 + status icons 표시
# stdin으로 JSON 세션 데이터를 받아 statusbar 내용을 stdout으로 출력

input=$(cat)

TRANSCRIPT=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null) || true

# transcript_path 비어있으면 전체 skip
if [ -z "$TRANSCRIPT" ]; then
  exit 0
fi

# --- Plan 파일 감지 ---
# 현재 세션의 transcript에서 plan 파일 Read/Write 기록을 추출한다.
# ※ 이전 ls -t 방식은 세션과 무관하게 가장 최근 파일을 반환하여
#   다른 세션의 plan을 오표시하는 버그가 있었음 (worktree fallback 포함).
PLAN_FILE=""
PLAN_STATE_FILE=""

if [ -n "$TRANSCRIPT" ]; then
  # 상태 파일: project 디렉토리에 저장 (worktree별 격리)
  # context clear 후 새 transcript에 plan 기록이 없을 때 fallback으로 사용
  PLAN_STATE_FILE="$(dirname "$TRANSCRIPT")/.statusline-plan"
fi

if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  # agent_progress 이벤트 제외 (subagent가 다른 세션 plan을 읽은 기록 필터링)
  # agent plan 파일명(-agent-) 제외
  PLAN_FILE=$(grep -v '"type":"agent_progress"' "$TRANSCRIPT" 2>/dev/null \
    | grep -oE '"(filePath|file_path|planFilePath)":"[^"]*\.claude/plans/[^"]*\.md"' \
    | grep -v 'plans/[^"]*-agent-' \
    | tail -1 | sed 's/^"[^"]*":"//;s/"$//')
fi

# --- Plan state file 관리 ---
if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ] && [ -n "$PLAN_STATE_FILE" ]; then
  # transcript에서 plan 감지 성공 + 파일 존재 확인 → 상태 파일에 저장
  printf '%s' "$PLAN_FILE" > "$PLAN_STATE_FILE" 2>/dev/null
elif [ -z "$PLAN_FILE" ] && [ -n "$PLAN_STATE_FILE" ] && [ -f "$PLAN_STATE_FILE" ]; then
  # transcript에서 감지 실패 (context clear 등) → 상태 파일에서 복원
  PLAN_FILE=$(cat "$PLAN_STATE_FILE" 2>/dev/null)
fi

# --- Status icons 읽기 ---
SESSION_ID=$(basename "$TRANSCRIPT" .jsonl)
ICONS_FILE="$HOME/.claude/status-icons/$SESSION_ID.json"

JIRA_URL="" JIRA_LABEL=""
SLACK_URL="" SLACK_LABEL=""
FIGMA_URL="" FIGMA_LABEL=""
MEMO_PATH="" MEMO_LABEL=""

if [ -n "$SESSION_ID" ] && [ -f "$ICONS_FILE" ] && command -v jq >/dev/null 2>&1; then
  JIRA_URL=$(jq -r '.jira.url // empty' "$ICONS_FILE" 2>/dev/null) || true
  JIRA_LABEL=$(jq -r '.jira.label // empty' "$ICONS_FILE" 2>/dev/null) || true
  SLACK_URL=$(jq -r '.slack.url // empty' "$ICONS_FILE" 2>/dev/null) || true
  SLACK_LABEL=$(jq -r '.slack.label // empty' "$ICONS_FILE" 2>/dev/null) || true
  FIGMA_URL=$(jq -r '.figma.url // empty' "$ICONS_FILE" 2>/dev/null) || true
  FIGMA_LABEL=$(jq -r '.figma.label // empty' "$ICONS_FILE" 2>/dev/null) || true
  MEMO_PATH=$(jq -r '.memo.path // empty' "$ICONS_FILE" 2>/dev/null) || true
  MEMO_LABEL=$(jq -r '.memo.label // empty' "$ICONS_FILE" 2>/dev/null) || true
fi

# --- 출력 ---
OUTPUT=""

# Plan: cyan underline — 📝
# stale state file은 [ -f "$PLAN_FILE" ]에 의해 아이콘 미표시,
# 새 plan 생성 시 자연 덮어쓰기로 갱신됨
if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
  OUTPUT="\e[4;36m\e]8;;file://${PLAN_FILE}\a\xf0\x9f\x93\x9d Plan\e]8;;\a\e[0m"
fi

# Jira: yellow underline — ⚡
if [ -n "$JIRA_URL" ] && [ -n "$JIRA_LABEL" ]; then
  [ -n "$OUTPUT" ] && OUTPUT="$OUTPUT  "
  OUTPUT="$OUTPUT\e[4;33m\e]8;;${JIRA_URL}\a\xe2\x9a\xa1 ${JIRA_LABEL}\e]8;;\a\e[0m"
fi

# Slack: magenta underline — 💬
if [ -n "$SLACK_URL" ] && [ -n "$SLACK_LABEL" ]; then
  [ -n "$OUTPUT" ] && OUTPUT="$OUTPUT  "
  OUTPUT="$OUTPUT\e[4;35m\e]8;;${SLACK_URL}\a\xf0\x9f\x92\xac ${SLACK_LABEL}\e]8;;\a\e[0m"
fi

# Figma: red underline — 🎨
if [ -n "$FIGMA_URL" ] && [ -n "$FIGMA_LABEL" ]; then
  [ -n "$OUTPUT" ] && OUTPUT="$OUTPUT  "
  OUTPUT="$OUTPUT\e[4;31m\e]8;;${FIGMA_URL}\a\xf0\x9f\x8e\xa8 ${FIGMA_LABEL}\e]8;;\a\e[0m"
fi

# Memo: green underline — 📓
if [ -n "$MEMO_PATH" ] && [ -f "$MEMO_PATH" ]; then
  [ -n "$OUTPUT" ] && OUTPUT="$OUTPUT  "
  OUTPUT="$OUTPUT\e[4;32m\e]8;;file://${MEMO_PATH}\a\xf0\x9f\x93\x93 ${MEMO_LABEL:-Memo}\e]8;;\a\e[0m"
fi

# 아이콘이 하나라도 있으면 출력 + 최종 개행
if [ -n "$OUTPUT" ]; then
  printf '%b' "${OUTPUT}\n"
fi
