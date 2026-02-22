#!/usr/bin/env bash
set -euo pipefail

PORT="${CHROME_REMOTE_DEBUG_PORT:-9222}"
CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
LOG_PREFIX="[ensure-chrome-debug-port]"

if [ ! -x "$CHROME_BIN" ]; then
  echo "$LOG_PREFIX Chrome binary not found: $CHROME_BIN" >&2
  exit 1
fi

if /usr/sbin/lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | grep -q "Google Chrome"; then
  exit 0
fi

if pgrep -x "Google Chrome" >/dev/null 2>&1; then
  echo "$LOG_PREFIX Chrome is running without remote debugging; restarting with --remote-debugging-port=$PORT"

  /usr/bin/osascript <<'APPLESCRIPT' >/dev/null
tell application "Google Chrome"
  if it is running then
    try
      quit
    end try
  end if
end tell
APPLESCRIPT

  for _ in $(seq 1 30); do
    if ! pgrep -x "Google Chrome" >/dev/null 2>&1; then
      break
    fi
    sleep 0.2
  done
fi

if pgrep -x "Google Chrome" >/dev/null 2>&1; then
  echo "$LOG_PREFIX Chrome is still running; skip relaunch" >&2
  exit 1
fi

"$CHROME_BIN" "--remote-debugging-port=$PORT" >/dev/null 2>&1 &
exit 0
