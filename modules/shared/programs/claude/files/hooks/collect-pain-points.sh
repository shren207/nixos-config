#!/usr/bin/env bash
# Claude Code Stop Hook - Pain point 자동 수집
# stdin: JSON {session_id, transcript_path, agent_id}
# stdout: (없음 — pain-points.jsonl에 append)
#
# 교정 키워드 감지, tool reject 카운팅, 세션 메트릭 수집.
# 임계값 초과 시 ~/.claude/pain-points.jsonl에 JSONL 레코드 append.
# 7일 이전 항목이 5건+ 쌓이면 claude -p로 패턴 분석 → memory 승격.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

# --- stdin 읽기 ---
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat)
fi
[ -n "$INPUT" ] || exit 0

# 서브에이전트 가드
AGENT_ID=$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null || true)
[ -n "$AGENT_ID" ] && exit 0

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)

[ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ] || exit 0

# --- 설정 ---
PAIN_FILE="${PAIN_POINTS_FILE:-$HOME/.claude/pain-points.jsonl}"
ARCHIVE_FILE="${PAIN_ARCHIVE_FILE:-$HOME/.claude/pain-points.archive.jsonl}"
TURN_THRESHOLD=30

# --- Git 정보 ---
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
# worktree에서 REPO가 worktree 디렉토리명으로 잡히므로 실제 repo 이름 사용
COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null || true)
if [ -n "$COMMON_DIR" ] && [ "$COMMON_DIR" != ".git" ]; then
  REPO=$(basename "$(cd "$COMMON_DIR/.." 2>/dev/null && pwd)" 2>/dev/null || echo "$REPO")
fi

# --- Transcript 분석 ---

# user 메시지 텍스트 추출 (string과 array 형식 모두 처리)
USER_MESSAGES=$(jq -Rrs '
  split("\n")
  | map(select(length > 0) | fromjson?)
  | map(
      select(.type == "user")
      | .message.content
      | if type == "string" then .
        elif type == "array" then
          [.[] | select(.type == "text") | .text] | join("\n")
        else ""
        end
    )
  | map(select(length > 0))
' "$TRANSCRIPT_PATH" 2>/dev/null || echo '[]')

# 턴 수 (user 메시지 수)
TURNS=$(printf '%s' "$USER_MESSAGES" | jq 'length' 2>/dev/null || echo "0")

# 세션 시간 (분) — 첫/마지막 타임스탬프 차이
DURATION_MIN=$(jq -Rrs '
  split("\n")
  | map(select(length > 0) | fromjson?)
  | map(.timestamp // empty | select(. != null and . != ""))
  | if length > 1 then
      ( (last | split(".")[0] + "Z" | fromdateiso8601)
      - (first | split(".")[0] + "Z" | fromdateiso8601) ) / 60 | floor
    else 0 end
' "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")

# 교정 키워드 매칭
# ;; → high severity
# 아니 (접속사 "아니면" 제외), 해야지, 그거 말고 → medium
CORRECTIONS=$(printf '%s' "$USER_MESSAGES" | jq '[
  .[] | select(
    test(";;")
    or test("^아니[^면]|^아니$|^아니 ")
    or test("해야지")
    or test("그거 말고")
  )
]' 2>/dev/null || echo '[]')

CORRECTION_COUNT=$(printf '%s' "$CORRECTIONS" | jq 'length' 2>/dev/null || echo "0")

# severity: ;; 감지 → high
HAS_DOUBLE_SEMI=$(printf '%s' "$CORRECTIONS" | jq '[.[] | select(test(";;"))] | length > 0' 2>/dev/null || echo "false")
SEVERITY="medium"
[ "$HAS_DOUBLE_SEMI" = "true" ] && SEVERITY="high"

# tool rejection 카운팅 (사용자가 tool call을 거부한 경우)
REJECTS=$(jq -Rrs '
  split("\n")
  | map(select(length > 0) | fromjson?)
  | map(
      select(.type == "user")
      | .message.content
      | if type == "array" then
          [.[] | select(
            .type == "tool_result"
            and .is_error == true
            and ((.content // "") | test("user doesn.t want to proceed|rejected"; "i"))
          )]
        else []
        end
    )
  | map(select(length > 0))
  | length
' "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")

# --- 임계값 판정 ---
SHOULD_RECORD=false
[ "$CORRECTION_COUNT" -gt 0 ] && SHOULD_RECORD=true
[ "$REJECTS" -gt 0 ] && SHOULD_RECORD=true
[ "$TURNS" -gt "$TURN_THRESHOLD" ] && SHOULD_RECORD=true

if [ "$SHOULD_RECORD" = "true" ]; then
  DESC_PARTS=()
  [ "$CORRECTION_COUNT" -gt 0 ] && DESC_PARTS+=("교정 ${CORRECTION_COUNT}회")
  [ "$REJECTS" -gt 0 ] && DESC_PARTS+=("reject ${REJECTS}회")
  [ "$TURNS" -gt "$TURN_THRESHOLD" ] && DESC_PARTS+=("${TURNS}턴")
  DESCRIPTION=$(IFS=", "; echo "${DESC_PARTS[*]}")

  TS=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

  umask 077
  jq -nc \
    --arg ts "$TS" \
    --arg sid "${SESSION_ID:-unknown}" \
    --arg repo "$REPO" \
    --arg branch "$BRANCH" \
    --arg sev "$SEVERITY" \
    --argjson corrections "$CORRECTIONS" \
    --argjson rejects "$REJECTS" \
    --argjson turns "$TURNS" \
    --argjson dur "$DURATION_MIN" \
    --arg desc "$DESCRIPTION" \
    '{
      ts: $ts, session_id: $sid, repo: $repo, branch: $branch,
      source: "auto", severity: $sev,
      signals: { corrections: $corrections, rejects: ($rejects), turns: ($turns), duration_min: ($dur) },
      description: $desc, user_note: null
    }' >> "$PAIN_FILE"
fi

# --- 정제: 7일 이전 항목 처리 ---
if [ -f "$PAIN_FILE" ] && [ -s "$PAIN_FILE" ]; then
  SEVEN_DAYS_AGO=$(date -u -v-7d +"%Y-%m-%dT%H:%M:%S" 2>/dev/null \
    || date -u -d "7 days ago" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null \
    || true)

  if [ -n "$SEVEN_DAYS_AGO" ]; then
    OLD_COUNT=$(jq -rs --arg cutoff "$SEVEN_DAYS_AGO" \
      'map(select(.ts < $cutoff)) | length' "$PAIN_FILE" 2>/dev/null || echo "0")

    if [ "$OLD_COUNT" -ge 5 ]; then
      OLD_ENTRIES=$(jq -rs --arg cutoff "$SEVEN_DAYS_AGO" \
        'map(select(.ts < $cutoff))' "$PAIN_FILE" 2>/dev/null)

      # memory 디렉토리 탐색 (git repo 기반 경로 인코딩)
      REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
      if [ -n "$REPO_ROOT" ]; then
        ENCODED=$(printf '%s' "$REPO_ROOT" | sed 's|[^a-zA-Z0-9]|-|g')
        MEMORY_DIR="$HOME/.claude/projects/$ENCODED/memory"
      else
        MEMORY_DIR=""
      fi

      # claude -p로 패턴 분석 (실패해도 아카이브는 수행)
      if command -v claude >/dev/null 2>&1 && [ -n "$MEMORY_DIR" ] && [ -d "$MEMORY_DIR" ]; then
        RESULT=$(printf '%s' "$OLD_ENTRIES" | timeout 120 claude -p \
          "아래 pain point 로그를 분석하세요. 반복 패턴(2회+)이 있으면 feedback memory를 생성하세요.

규칙:
- 2회 이상 반복되는 패턴만 memory로 추출
- 1회성 항목은 무시
- 출력: JSON {\"memories\": [{\"filename\": \"pain-xxx.md\", \"content\": \"---\nname: pain-xxx\ndescription: one-line\ntype: feedback\n---\n\n본문\n\n**Why:** 근거\n**How to apply:** 적용 방법\"}]}
- memory가 없으면 {\"memories\": []}

로그:" 2>/dev/null || echo "")

        if [ -n "$RESULT" ]; then
          # JSON에서 memories 배열 추출
          MEMORY_COUNT=$(printf '%s' "$RESULT" | jq '.memories | length' 2>/dev/null || echo "0")
          for i in $(seq 0 $((MEMORY_COUNT - 1))); do
            FNAME=$(printf '%s' "$RESULT" | jq -r ".memories[$i].filename" 2>/dev/null)
            MCONTENT=$(printf '%s' "$RESULT" | jq -r ".memories[$i].content" 2>/dev/null)
            if [ -n "$FNAME" ] && [ "$FNAME" != "null" ] && [ -n "$MCONTENT" ] && [ "$MCONTENT" != "null" ]; then
              printf '%s\n' "$MCONTENT" > "$MEMORY_DIR/$FNAME"
              # MEMORY.md 인덱싱 (중복 방지)
              MDESC=$(printf '%s' "$MCONTENT" | grep '^description:' | head -1 | sed 's/^description: *//')
              if [ -f "$MEMORY_DIR/MEMORY.md" ] && ! grep -qF "$FNAME" "$MEMORY_DIR/MEMORY.md"; then
                printf -- '- [%s](%s) — %s\n' "$FNAME" "$FNAME" "${MDESC:-pain point 자동 정제}" >> "$MEMORY_DIR/MEMORY.md"
              fi
            fi
          done
        fi
      fi

      # 오래된 항목을 archive로 이동
      jq -rs --arg cutoff "$SEVEN_DAYS_AGO" \
        '.[] | select(.ts < $cutoff)' "$PAIN_FILE" >> "$ARCHIVE_FILE" 2>/dev/null || true

      # pain-points.jsonl에서 오래된 항목 제거 (atomic write)
      tmp=$(mktemp)
      jq -rs --arg cutoff "$SEVEN_DAYS_AGO" \
        '[.[] | select(.ts >= $cutoff)] | .[]' "$PAIN_FILE" > "$tmp" 2>/dev/null \
        && mv "$tmp" "$PAIN_FILE" \
        || rm -f "$tmp"
    fi
  fi
fi

# 아카이브 30일 초과 정리
if [ -f "$ARCHIVE_FILE" ] && [ -s "$ARCHIVE_FILE" ]; then
  THIRTY_DAYS_AGO=$(date -u -v-30d +"%Y-%m-%dT%H:%M:%S" 2>/dev/null \
    || date -u -d "30 days ago" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null \
    || true)
  if [ -n "$THIRTY_DAYS_AGO" ]; then
    tmp=$(mktemp)
    jq -rs --arg cutoff "$THIRTY_DAYS_AGO" \
      '[.[] | select(.ts >= $cutoff)] | .[]' "$ARCHIVE_FILE" > "$tmp" 2>/dev/null \
      && mv "$tmp" "$ARCHIVE_FILE" \
      || rm -f "$tmp"
  fi
fi

exit 0
