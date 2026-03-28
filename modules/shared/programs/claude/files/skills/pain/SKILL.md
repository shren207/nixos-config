---
name: pain
description: |
  Pain point 수동 태깅. 세션 중 불편함을 느꼈을 때 기록.
  Trigger: '/pain', 'pain point 기록', '불편 기록', '페인 포인트'.
---

# Pain Point 수동 태깅

사용자가 세션 중 불편함을 느꼈을 때 `/pain <메모>`로 기록합니다.
기록된 pain point는 이후 세션에서 Claude가 자동으로 읽어 행동을 조정합니다.

## 실행 절차

ARGUMENTS의 전체 텍스트를 `user_note`로 사용합니다. ARGUMENTS가 비어있으면 사용자에게 무엇이 불편했는지 AskUserQuestion으로 물어보세요.

Bash tool로 아래 명령을 실행하세요. 두 단계로 나뉩니다:

**Step 1**: 메모를 임시 파일에 저장 (셸 인젝션 방지):

```bash
PAIN_TMP=$(mktemp)
cat > "$PAIN_TMP" << 'PAIN_NOTE_END'
<USER_NOTE>
PAIN_NOTE_END
```

`<USER_NOTE>` 부분을 ARGUMENTS 값으로 교체하세요. 단, ARGUMENTS에 `PAIN_NOTE_END`라는 문자열이 포함되어 있으면 delimiter를 다른 문자열(예: `PAIN_NOTE_XXXX`)로 변경하세요.

**Step 2**: jq로 JSONL 레코드 생성:

```bash
# worktree에서도 canonical repo 이름 사용
COMMON=$(git rev-parse --git-common-dir 2>/dev/null || true)
if [ -n "$COMMON" ] && [ "$COMMON" != ".git" ]; then
  REPO_NAME=$(basename "$(cd "$COMMON/.." && pwd)")
else
  REPO_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo unknown)
fi

jq -nc \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")" \
  --arg repo "$REPO_NAME" \
  --arg branch "$(git branch --show-current 2>/dev/null || echo unknown)" \
  --rawfile note "$PAIN_TMP" \
  '{
    ts: $ts,
    session_id: "manual",
    repo: $repo,
    branch: $branch,
    source: "manual",
    severity: "medium",
    signals: {},
    description: ("수동 태깅: " + ($note | rtrimstr("\n"))),
    user_note: ($note | rtrimstr("\n"))
  }' >> ~/.claude/pain-points.jsonl

rm -f "$PAIN_TMP"
```

## 완료 후

"Pain point 기록 완료" 메시지를 간결하게 출력합니다. 기록한 내용을 되풀이하지 마세요.
