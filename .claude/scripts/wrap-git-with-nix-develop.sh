#!/bin/bash
# PreToolUse hook: git 명령어를 nix develop -c로 감싸기
# 이 프로젝트는 lefthook (gitleaks, shellcheck 등)을 사용하므로
# nix develop 환경에서 git 명령어를 실행해야 함

set -euo pipefail

input=$(cat)
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

# git 명령어인지 확인 (git add, git commit 등)
# 이미 nix develop으로 감싸져 있으면 통과
if [[ "$command" =~ ^git[[:space:]]+(add|commit|push|stash) ]] && [[ ! "$command" =~ ^nix[[:space:]]+develop ]]; then
  # nix develop -c로 감싸기
  wrapped_command="nix develop -c $command"

  # updatedInput으로 명령어 수정
  cat <<EOF
{
  "hookSpecificOutput": {
    "permissionDecision": "allow",
    "updatedInput": {
      "command": $(echo "$wrapped_command" | jq -R .)
    }
  },
  "systemMessage": "이 프로젝트는 lefthook (gitleaks, shellcheck)을 사용합니다. git 명령어를 nix develop 환경에서 실행합니다."
}
EOF
  exit 0
fi

# 그 외 명령어는 그대로 통과
exit 0
