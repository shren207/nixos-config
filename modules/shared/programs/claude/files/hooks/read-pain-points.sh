#!/usr/bin/env bash
# Claude Code SessionStart Hook - Pain point 읽기
# stdin: JSON {session_id, source}
# stdout: JSON {hookSpecificOutput: {additionalContext: "..."}}
#
# 최근 7일 pain point를 severity별로 정렬하여 additionalContext로 주입.
# Claude가 세션 시작 시 자동으로 읽어 행동을 조정할 수 있게 함.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat)
fi
[ -n "$INPUT" ] || exit 0

PAIN_FILE="${PAIN_POINTS_FILE:-$HOME/.claude/pain-points.jsonl}"

# 파일 없거나 비어있으면 skip
[ -f "$PAIN_FILE" ] && [ -s "$PAIN_FILE" ] || exit 0

# 7일 전 날짜 계산 (macOS: -v, Linux: -d)
SEVEN_DAYS_AGO=$(date -u -v-7d +"%Y-%m-%dT%H:%M:%S" 2>/dev/null \
  || date -u -d "7 days ago" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null \
  || exit 0)

# 최근 7일 항목 필터 + severity 정렬 + 최대 10건 + 포맷팅
CONTEXT=$(jq -rs --arg cutoff "$SEVEN_DAYS_AGO" '
  map(select(.ts >= $cutoff))
  | sort_by(.ts) | reverse
  | .[0:10]
  | if length == 0 then empty
    else
      (map(select(.severity == "high")) | length) as $high
      | (map(select(.severity == "medium" and .source == "auto")) | length) as $med
      | (map(select(.source == "manual")) | length) as $manual
      | . as $all
      |
      "## 최근 Pain Points (7일) -- \(length)건\n"
      + if $high > 0 then
          "\n### HIGH (\($high)건)\n"
          + ([$all[] | select(.severity == "high")]
            | map("- [\(.ts[5:10]) \(.session_id[0:8])] \(.description)\n  repo: \(.repo)/\(.branch)")
            | join("\n")) + "\n"
        else "" end
      + if $med > 0 then
          "\n### MEDIUM (\($med)건)\n"
          + ([$all[] | select(.severity == "medium" and .source == "auto")]
            | map("- [\(.ts[5:10]) \(.session_id[0:8])] \(.description)\n  repo: \(.repo)/\(.branch)")
            | join("\n")) + "\n"
        else "" end
      + if $manual > 0 then
          "\n### MANUAL (\($manual)건)\n"
          + ([$all[] | select(.source == "manual")]
            | map("- [\(.ts[5:10]) \(.session_id[0:8])] \(.user_note // .description)\n  repo: \(.repo)/\(.branch)")
            | join("\n")) + "\n"
        else "" end
    end
' "$PAIN_FILE" 2>/dev/null || true)

[ -n "$CONTEXT" ] || exit 0

jq -n --arg ctx "$CONTEXT" \
  '{"hookSpecificOutput":{"additionalContext":$ctx}}'

exit 0
