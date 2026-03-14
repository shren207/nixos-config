#!/usr/bin/env bash
# Claude Code PreToolUse hook: nrs worktree lock guard
# Bash 도구가 nrs/rebuild 명령을 실행할 때 lock 충돌을 차단

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')

# Early return: Bash 도구가 아니면 즉시 통과
[[ "$TOOL_NAME" != "Bash" ]] && exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$COMMAND" ]] && exit 0

NRS_LOCK_FILE="/tmp/nrs-state"

# 규칙 3: nrs-unlock / nrs-lock.sh unlock 시도 차단
if echo "$COMMAND" | grep -qE '(nrs-unlock|nrs-lock\.sh[[:space:]]+unlock)'; then
    jq -n '{decision: "block", reason: "nrs-unlock은 사용자가 직접 터미널에서 실행해야 합니다."}'
    exit 0
fi

# 규칙 2: lock 파일 직접 삭제 차단
if echo "$COMMAND" | grep -qE 'rm[[:space:]].*nrs-state'; then
    jq -n '{decision: "block", reason: "nrs lock 파일을 직접 삭제할 수 없습니다. 사용자가 nrs-unlock을 실행하세요."}'
    exit 0
fi

# 규칙 1: nrs/darwin-rebuild/nixos-rebuild 실행 시 lock 충돌 확인
if echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\||;)(sudo[[:space:]]+)?(nrs|darwin-rebuild|nixos-rebuild)\b'; then
    # lock 없으면 통과
    [[ ! -f "$NRS_LOCK_FILE" ]] && exit 0

    # 현재 worktree 판별
    CURRENT_WORKTREE=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
    LOCK_WORKTREE=$(jq -r '.worktree' "$NRS_LOCK_FILE" 2>/dev/null || echo "")

    # 같은 worktree면 통과 (nrs.sh 내부에서 re-entry 처리)
    if [[ -n "$CURRENT_WORKTREE" && "$CURRENT_WORKTREE" == "$LOCK_WORKTREE" ]]; then
        exit 0
    fi

    LOCK_BRANCH=$(jq -r '.branch' "$NRS_LOCK_FILE" 2>/dev/null || echo "?")
    jq -n --arg wt "$LOCK_WORKTREE" --arg br "$LOCK_BRANCH" \
        '{decision: "block", reason: ("다른 worktree(" + $wt + ", branch: " + $br + ")가 nrs lock을 보유 중입니다. 사용자가 nrs-unlock을 실행하세요.")}'
    exit 0
fi

# 매칭 없음 — 통과
exit 0
