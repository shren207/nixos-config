#!/bin/bash
# PostToolUse hook: git commit 후 빈 커밋 감지
# tree hash 비교로 staging area 초기화 버그 감지 (Issue #125)
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
[[ "$tool_name" == "Bash" ]] || exit 0

command=$(echo "$input" | jq -r '.tool_input.command // empty')
[[ -n "$command" ]] || exit 0

# git commit 감지 (직접 또는 nix develop 래핑)
is_commit=false
if [[ "$command" =~ git[[:space:]]+commit ]]; then
  is_commit=true
elif [[ "$command" =~ base64.*nix[[:space:]]+develop ]]; then
  encoded=$(echo "$command" | sed -n 's/.*echo \([A-Za-z0-9+/=]*\) .*/\1/p')
  if [[ -n "$encoded" ]]; then
    decoded=$(echo "$encoded" | base64 -d 2>/dev/null || true)
    [[ "$decoded" =~ git[[:space:]]+commit ]] && is_commit=true
  fi
fi
[[ "$is_commit" == "true" ]] || exit 0

# 첫 커밋이면 비교 불가
git rev-parse HEAD~1 &>/dev/null || exit 0

head_tree=$(git rev-parse "HEAD^{tree}" 2>/dev/null) || exit 0
parent_tree=$(git rev-parse "HEAD~1^{tree}" 2>/dev/null) || exit 0

if [[ "$head_tree" == "$parent_tree" ]]; then
  head_sha=$(git rev-parse --short HEAD)
  jq -n \
    --arg reason "EMPTY COMMIT DETECTED: commit $head_sha has identical tree as parent. Staging area was likely corrupted by lefthook. Run 'git reset HEAD~1' to undo, re-stage files, and retry." \
    --arg ctx "This is GitHub Issue #125. Current HEAD tree: $head_tree, Parent tree: $parent_tree (identical). Recovery: git reset HEAD~1 && git add <files> && git commit --no-verify -m 'message'" \
    '{
      decision: "block",
      reason: $reason,
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: $ctx
      }
    }'
fi

exit 0
