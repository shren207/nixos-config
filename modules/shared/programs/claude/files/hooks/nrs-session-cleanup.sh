#!/usr/bin/env bash
# Claude Code Stop/SessionEnd hook: nrs lock 자동 정리
# LLM turn 종료(Stop) 또는 CC 세션 종료(SessionEnd) 시 해당 worktree의 lock을 자동 해제
#
# PoC 검증 결과 (2026-03-15):
#   - Stop은 main agent turn 종료 시에만 트리거 (sub-agent, Agent Teams 멤버는 미트리거)
#   - SessionEnd는 main 세션 종료 시에만 트리거
#   → 두 이벤트 모두 안전하게 lock 해제 가능

NRS_LOCK_FILE="/tmp/nrs-state"
[[ ! -f "$NRS_LOCK_FILE" ]] && exit 0

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[[ -z "$CWD" ]] && exit 0

# CWD에서 git toplevel 추출 → lock worktree와 비교
GIT_TOPLEVEL=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || exit 0
LOCK_WORKTREE=$(jq -r '.worktree' "$NRS_LOCK_FILE" 2>/dev/null) || exit 0

if [[ "$GIT_TOPLEVEL" == "$LOCK_WORKTREE" ]]; then
    rm -f "$NRS_LOCK_FILE"
fi

exit 0
