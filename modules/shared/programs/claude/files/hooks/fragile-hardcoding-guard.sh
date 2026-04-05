#!/usr/bin/env bash
# PreToolUse Hook: SKILL.md fragile hardcoding 감지
# 코드에서 동적으로 확인 가능한 정보(줄 수, 파일 수, 경로 열거)를
# SKILL.md에 하드코딩하면 코드 변경 시 즉시 outdated 되므로 차단한다.

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

case "$TOOL_NAME" in Edit|Write) ;; *) exit 0 ;; esac

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

# [WHY] SKILL.md body와 references/는 LLM이 생성/수정하는 스킬 콘텐츠.
# 이 영역에 코드 상태를 하드코딩하면 코드 변경 시 문서가 즉시 stale 됨.
# project-scope (.claude/skills/) + user-scope 소스 (modules/.../skills/) 모두 대상.
case "$FILE_PATH" in
  */.claude/skills/*/SKILL.md|*/.claude/skills/*/references/*|\
  */modules/*/claude/files/skills/*/SKILL.md|*/modules/*/claude/files/skills/*/references/*) ;;
  *) exit 0 ;;
esac

# [WHY] Write는 전체 문서, Edit는 조각. 검사 정책을 통일하기 위해
# Edit에서도 post-edit 전체 문서를 재구성하되, 재구성 실패 시
# fragment 모드로 fallback하여 fence strip 오작동을 방지.
# SCAN_MODE: document=전체 문서(fence strip 가능), fragment=조각(fence strip 불가).
SCAN_MODE="document"
if [ "$TOOL_NAME" = "Write" ]; then
  CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)
else
  OLD_STR=$(printf '%s' "$INPUT" | jq -r '.tool_input.old_string // empty' 2>/dev/null)
  NEW_STR=$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null)
  if [ -n "$OLD_STR" ] && [ -f "$FILE_PATH" ]; then
    # [WHY] awk ENVIRON + index() + substr()로 순수 문자열 치환.
    # -v 대신 ENVIRON을 사용하여 C-style escape 변환을 방지.
    # regex 특수문자 안전. exit code로 매치 여부 반환.
    CONTENT=$(OLD_STR="$OLD_STR" NEW_STR="$NEW_STR" awk '
      BEGIN { RS="\0"; ORS="" }
      {
        old = ENVIRON["OLD_STR"]; new = ENVIRON["NEW_STR"]
        idx = index($0, old)
        if (idx > 0) { print substr($0, 1, idx-1) new substr($0, idx+length(old)); exit 0 }
        else { exit 1 }
      }' "$FILE_PATH" 2>/dev/null)
    # [WHY] 미매치(exit 1) 시 원본 문서를 반환하면 적용 안 될
    # 변경에 대해 기존 내용으로 block 발생. fragment로 전환.
    if [ $? -ne 0 ]; then
      CONTENT="$NEW_STR"
      SCAN_MODE="fragment"
    fi
  else
    CONTENT="$NEW_STR"
    SCAN_MODE="fragment"
  fi
fi
[ -z "$CONTENT" ] && exit 0

# [WHY] fence strip은 전체 문서(document 모드)에서만 적용.
# fragment 모드에서 미완결 fence(opening만 있고 closing 없음)를 strip하면
# 이후 라인이 모두 제거되어 false negative 발생.
# awk fence parser: Markdown spec 기준 0-3칸 들여쓰기 + 3개 이상 backtick.
#   depth=fence 내부 여부, fence_len=opening backtick 수.
#   닫힘 조건: backtick 수 >= opening 길이 && 뒤에 텍스트 없음.
if [ "$SCAN_MODE" = "document" ]; then
  SCAN_INPUT=$(printf '%s' "$CONTENT" | awk '
    BEGIN { depth = 0; fence_len = 0 }
    {
      s = $0; sub(/^[ ]{0,3}/, "", s); ticks = 0
      while (substr(s, ticks+1, 1) == "`") ticks++
      if (ticks >= 3) {
        tail = substr(s, ticks+1); gsub(/[ \t\r]/, "", tail)
        if (depth == 0) { depth = 1; fence_len = ticks; next }
        if (ticks >= fence_len && tail == "") { depth = 0; fence_len = 0; next }
      }
      if (depth == 0) print
    }')
else
  SCAN_INPUT="$CONTENT"
fi

# [WHY] Edit + document 모드에서 post-edit 전체 문서를 검사하면
# 원본에 이미 있던 하드코딩도 차단됨 (이번 Edit과 무관한 회귀).
# 원본에 대해서도 동일한 fence strip + 패턴 검사를 수행하고,
# 원본에도 있는 경고는 이번 Edit이 도입한 것이 아니므로 제외.
OLD_HAS_LINE="" OLD_HAS_FILE="" OLD_HAS_PATH=""
if [ "$TOOL_NAME" = "Edit" ] && [ "$SCAN_MODE" = "document" ]; then
  OLD_STRIPPED=$(awk '
    BEGIN { depth = 0; fence_len = 0 }
    {
      s = $0; sub(/^[ ]{0,3}/, "", s); ticks = 0
      while (substr(s, ticks+1, 1) == "`") ticks++
      if (ticks >= 3) {
        tail = substr(s, ticks+1); gsub(/[ \t\r]/, "", tail)
        if (depth == 0) { depth = 1; fence_len = ticks; next }
        if (ticks >= fence_len && tail == "") { depth = 0; fence_len = 0; next }
      }
      if (depth == 0) print
    }' "$FILE_PATH")
  printf '%s' "$OLD_STRIPPED" | grep -E '[0-9]+줄|[0-9]+ lines' | \
    grep -qvE '[0-9]+줄[[:space:]]*(이내|이하|미만|이상|설명|요약|제한)' && OLD_HAS_LINE=1
  printf '%s' "$OLD_STRIPPED" | grep -E '[0-9]+개 파일|[0-9]+곳' | \
    grep -qvE '[1-9]-[1-9]개 파일' && OLD_HAS_FILE=1
  OLD_PATH_COUNT=$(printf '%s' "$OLD_STRIPPED" | grep -oE '\.claude/skills/[a-z0-9_-]+' | sort -u | wc -l)
  [ "$OLD_PATH_COUNT" -ge 3 ] && OLD_HAS_PATH=1
fi

WARNINGS=""

# [WHY] 줄 수는 코드 수정 시 즉시 변경됨 → wc -l로 동적 확인 가능
# [WHY_EXCLUDE] "N줄 이내/이하/설명" 등은 작성 규칙 표현이지 코드 상태 하드코딩이 아님
if [ -z "$OLD_HAS_LINE" ]; then
  printf '%s' "$SCAN_INPUT" | grep -E '[0-9]+줄|[0-9]+ lines' | \
    grep -qvE '[0-9]+줄[[:space:]]*(이내|이하|미만|이상|설명|요약|제한)' && \
    WARNINGS="${WARNINGS}줄 수 하드코딩. "
fi

# [WHY] 파일/참조 수는 파일 추가/삭제 시 변경됨 → grep -c로 동적 확인 가능
# [WHY_EXCLUDE] "N-N개 파일"(예: "1-2개 파일")은 범위 지침이지 정확한 수량 아님
if [ -z "$OLD_HAS_FILE" ]; then
  printf '%s' "$SCAN_INPUT" | grep -E '[0-9]+개 파일|[0-9]+곳' | \
    grep -qvE '[1-9]-[1-9]개 파일' && \
    WARNINGS="${WARNINGS}파일/참조 수 하드코딩. "
fi

# [WHY] 스킬 경로를 3개 이상 나열하면 스킬 추가/삭제 시 목록이 stale 됨.
# 3개 미만은 정당한 교차 참조(예: "NOT for X, use Y")로 간주.
if [ -z "$OLD_HAS_PATH" ]; then
  SKILL_PATH_COUNT=$(printf '%s' "$SCAN_INPUT" | grep -oE '\.claude/skills/[a-z0-9_-]+' | sort -u | wc -l)
  [ "$SKILL_PATH_COUNT" -ge 3 ] && \
    WARNINGS="${WARNINGS}.claude/skills/ 경로 ${SKILL_PATH_COUNT}개 열거. "
fi

[ -z "$WARNINGS" ] && exit 0

# Claude Code PreToolUse hook 차단 형식: {decision: "block", reason: "..."}
jq -n --arg reason "[Fragile hardcoding] ${WARNINGS}코드에서 동적 확인 가능한 정보입니다. 하드코딩 대신 확인 방법을 기술하세요." \
  '{decision: "block", reason: $reason}'
exit 0
