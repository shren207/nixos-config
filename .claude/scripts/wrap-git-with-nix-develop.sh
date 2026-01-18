#!/bin/bash
# PreToolUse hook: git 명령어를 nix develop 환경에서 실행
# 이 프로젝트는 lefthook (gitleaks, shellcheck 등)을 사용하므로
# nix develop 환경에서 git 명령어를 실행해야 함

set -euo pipefail

input=$(cat)

# 디버그 로깅 (문제 발생 시 주석 해제)
# exec 2>>/tmp/claude-hook-debug.log
# echo "=== $(date) ===" >&2
# echo "Input: $input" >&2

tool_name=$(echo "$input" | jq -r '.tool_name')

# Bash 도구가 아니면 통과
if [[ "$tool_name" != "Bash" ]]; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // empty')

# command가 없으면 통과
if [[ -z "$command" ]]; then
  exit 0
fi

# git add/commit/push/stash로 시작하고, 아직 래핑되지 않은 경우
if [[ "$command" =~ ^git[[:space:]]+(add|commit|push|stash) ]] && \
   [[ ! "$command" =~ ^nix[[:space:]]+develop ]] && \
   [[ ! "$command" =~ ^echo[[:space:]].*base64 ]]; then

  # Base64 인코딩으로 모든 특수문자 문제 회피
  encoded=$(printf '%s' "$command" | base64 | tr -d '\n')
  wrapped_command="echo $encoded | base64 -d | nix develop -c bash"

  jq -n \
    --arg cmd "$wrapped_command" \
    --arg msg "lefthook 사용을 위해 nix develop 환경에서 실행합니다." \
    '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        updatedInput: { command: $cmd }
      },
      systemMessage: $msg
    }'
  exit 0
fi

# 그 외 명령어는 그대로 통과
exit 0
