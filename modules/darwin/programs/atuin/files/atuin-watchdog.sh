#!/usr/bin/env bash
# Atuin Watchdog
# 동기화 상태를 감시하고 지연 시 알림 전송

set -euo pipefail

# PATH 설정 (Hammerspoon 등 다양한 환경에서 실행 가능하도록)
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$HOME/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

THRESHOLD_MINUTES="${ATUIN_SYNC_THRESHOLD_MINUTES:-5}"
CREDENTIALS_FILE="$HOME/.config/pushover/credentials"
HOSTNAME=$(scutil --get LocalHostName 2>/dev/null || hostname -s)

# 알림 전송 함수
send_alert() {
    local title="$1"
    local message="$2"
    local is_error="${3:-false}"

    # 1. macOS 기본 알림 (항상 시도)
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true

    # 2. Hammerspoon 알림 (있으면 추가)
    if command -v hs >/dev/null 2>&1; then
        hs -c "hs.notify.new({title='$title', informativeText='$message'}):send()" 2>/dev/null || true
        echo "Alert sent via Hammerspoon"
    fi

    # 3. Pushover 알림 (에러일 때만)
    if [[ -f "$CREDENTIALS_FILE" ]] && [[ "$is_error" == "true" ]]; then
        # 권한 체크 (600 권장)
        PERMS=$(stat -f %A "$CREDENTIALS_FILE" 2>/dev/null || echo "unknown")
        if [[ "$PERMS" != "600" && "$PERMS" != "400" ]]; then
            echo "Warning: credentials file permission is $PERMS (recommended: 600)"
        fi

        source "$CREDENTIALS_FILE"
        curl -s \
            --form-string "token=$PUSHOVER_TOKEN" \
            --form-string "user=$PUSHOVER_USER" \
            --form-string "priority=1" \
            -F "sound=falling" \
            --form-string "message=$message" \
            https://api.pushover.net/1/messages.json > /dev/null
        echo "Alert sent via Pushover"
    fi
}

# 메뉴바 상태 업데이트 함수
update_menubar() {
    local status="$1"
    if command -v hs >/dev/null 2>&1; then
        hs -c "if atuinMenubar then atuinMenubar:setStatus('$status') end" 2>/dev/null || true
    fi
}

echo "=== Atuin Watchdog ==="
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Host: $HOSTNAME"
echo "Threshold: $THRESHOLD_MINUTES minutes"

# atuin doctor에서 last_sync 추출
if ! command -v atuin >/dev/null 2>&1; then
    echo "Error: atuin not found"
    update_menubar "error"
    send_alert "🐢 Atuin 모니터" "atuin 명령어를 찾을 수 없음 [$HOSTNAME]" "true"
    exit 1
fi

DOCTOR_OUTPUT=$(atuin doctor 2>&1)
LAST_SYNC_RAW=$(echo "$DOCTOR_OUTPUT" | grep -o '"last_sync": "[^"]*"' | cut -d'"' -f4)

if [[ -z "$LAST_SYNC_RAW" ]]; then
    echo "Error: Failed to get last_sync from atuin doctor"
    update_menubar "error"
    send_alert "🐢❌ Atuin 모니터 오류" "last_sync 값을 가져올 수 없음 [$HOSTNAME]" "true"
    exit 1
fi

# UTC 시간을 epoch로 변환 (밀리초 및 타임존 제거)
LAST_SYNC_CLEAN=$(echo "$LAST_SYNC_RAW" | sed 's/\.[0-9]*//; s/ +00:00:00//')
LAST_SYNC_EPOCH=$(TZ=UTC date -j -f "%Y-%m-%d %H:%M:%S" "$LAST_SYNC_CLEAN" "+%s" 2>/dev/null || echo "0")
CURRENT_EPOCH=$(date "+%s")

if [[ "$LAST_SYNC_EPOCH" == "0" ]]; then
    echo "Error: Failed to parse last_sync: $LAST_SYNC_RAW"
    update_menubar "error"
    send_alert "🐢❌ Atuin 모니터 오류" "last_sync 파싱 실패 [$HOSTNAME]" "true"
    exit 1
fi

# KST로 변환해서 표시
LAST_SYNC_KST=$(date -r "$LAST_SYNC_EPOCH" "+%Y-%m-%d %H:%M:%S")
DIFF_MINUTES=$(( (CURRENT_EPOCH - LAST_SYNC_EPOCH) / 60 ))
echo "Last sync: $LAST_SYNC_KST KST ($DIFF_MINUTES minutes ago)"

# 임계값 초과 시 daemon 재시작 시도
if [[ $DIFF_MINUTES -ge $THRESHOLD_MINUTES ]]; then
    echo "Warning: Atuin sync is stale ($DIFF_MINUTES minutes)"
    update_menubar "warning"

    # daemon 재시작 시도
    echo "Attempting to restart atuin daemon..."
    if launchctl kickstart -k "gui/$(id -u)/com.green.atuin-daemon" 2>/dev/null; then
        echo "Daemon restart requested"
        sleep 3
    else
        echo "Warning: Failed to restart daemon via launchctl"
    fi

    # 재시작 후 sync 강제 실행
    echo "Forcing sync..."
    atuin sync 2>/dev/null || echo "Warning: sync command failed"
    sleep 2

    # 재시작 후 상태 확인
    DOCTOR_OUTPUT_AFTER=$(atuin doctor 2>&1)
    LAST_SYNC_AFTER=$(echo "$DOCTOR_OUTPUT_AFTER" | grep -o '"last_sync": "[^"]*"' | cut -d'"' -f4)
    LAST_SYNC_CLEAN_AFTER=$(echo "$LAST_SYNC_AFTER" | sed 's/\.[0-9]*//; s/ +00:00:00//')
    LAST_SYNC_EPOCH_AFTER=$(TZ=UTC date -j -f "%Y-%m-%d %H:%M:%S" "$LAST_SYNC_CLEAN_AFTER" "+%s" 2>/dev/null || echo "0")
    CURRENT_EPOCH_AFTER=$(date "+%s")
    DIFF_MINUTES_AFTER=$(( (CURRENT_EPOCH_AFTER - LAST_SYNC_EPOCH_AFTER) / 60 ))

    if [[ $DIFF_MINUTES_AFTER -lt $THRESHOLD_MINUTES ]]; then
        echo "OK: Daemon restart fixed the sync issue ($DIFF_MINUTES_AFTER minutes ago)"
        update_menubar "ok"
        send_alert "🐢✅ Atuin 복구됨" "daemon 재시작으로 동기화 복구됨 [$HOSTNAME]" "false"
    else
        echo "Error: Sync still stale after daemon restart ($DIFF_MINUTES_AFTER minutes)"
        send_alert "🐢❌ Atuin 동기화 실패" "daemon 재시작 후에도 ${DIFF_MINUTES_AFTER}분 동안 동기화 안됨 [$HOSTNAME]" "true"
    fi
else
    echo "OK: Sync is within threshold ($DIFF_MINUTES < $THRESHOLD_MINUTES minutes)"
    update_menubar "ok"
fi
