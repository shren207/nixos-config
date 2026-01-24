#!/usr/bin/env bash
# Claude Code Stop Hook - Pushover 알림 전송
# 작업 완료 시 현재 깃 브랜치 정보와 함께 알림을 보냅니다.

# agenix로 관리되는 credentials 로드
CREDENTIALS_FILE="$HOME/.config/pushover/credentials"

if [ -f "$CREDENTIALS_FILE" ]; then
  # shellcheck source=/dev/null
  source "$CREDENTIALS_FILE"
else
  echo "Error: Pushover credentials not found at $CREDENTIALS_FILE" >&2
  exit 1
fi

BRANCH=$(git branch --show-current 2>/dev/null || echo "깃 브랜치 ❌")

curl -s \
  --form-string "token=$PUSHOVER_TOKEN" \
  --form-string "user=$PUSHOVER_USER" \
  -F "sound=jobs_done" \
  --form-string "message= 작업이 완료되었습니다. [깃 브랜치: $BRANCH]" \
  https://api.pushover.net/1/messages.json > /dev/null
