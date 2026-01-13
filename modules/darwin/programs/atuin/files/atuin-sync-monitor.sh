#!/usr/bin/env bash
# Atuin 동기화 상태 모니터링
# 동기화 성공/실패 시 Hammerspoon + Pushover 알림 전송

set -euo pipefail

THRESHOLD_HOURS="${ATUIN_SYNC_THRESHOLD_HOURS:-24}"
LAST_SYNC_FILE="$HOME/.local/share/atuin/last_sync_time"
CREDENTIALS_FILE="$HOME/.config/pushover/credentials"
LOG_DIR="$HOME/Library/Logs/atuin"
HOSTNAME=$(scutil --get LocalHostName 2>/dev/null || hostname -s)

# 테스트 모드: --test 또는 ATUIN_MONITOR_TEST=1
TEST_MODE=false
if [[ "${1:-}" == "--test" ]] || [[ "${ATUIN_MONITOR_TEST:-}" == "1" ]]; then
    TEST_MODE=true
    echo "=== TEST MODE ==="
fi

# 로그 로테이션 (기본 30일 이상 된 로그 삭제)
LOG_RETENTION_DAYS="${ATUIN_LOG_RETENTION_DAYS:-30}"
if [[ -d "$LOG_DIR" ]]; then
    find "$LOG_DIR" -name "*.log" -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true
fi

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

    # 3. Pushover 알림 (에러 또는 테스트 모드일 때만)
    if [[ -f "$CREDENTIALS_FILE" ]] && { [[ "$is_error" == "true" ]] || [[ "$TEST_MODE" == "true" ]]; }; then
        # 권한 체크 (600 권장)
        PERMS=$(stat -f %A "$CREDENTIALS_FILE" 2>/dev/null || echo "unknown")
        if [[ "$PERMS" != "600" && "$PERMS" != "400" ]]; then
            echo "Warning: credentials file permission is $PERMS (recommended: 600)"
        fi

        source "$CREDENTIALS_FILE"
        local priority=0
        [[ "$is_error" == "true" ]] && priority=1
        curl -s \
            --form-string "token=$PUSHOVER_TOKEN" \
            --form-string "user=$PUSHOVER_USER" \
            --form-string "priority=$priority" \
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

echo "=== Atuin Sync Monitor ==="
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Host: $HOSTNAME"

# 메뉴바에 동기화 중 표시
update_menubar "syncing"

# 네트워크 연결 확인
if ! ping -c 1 -t 3 api.atuin.sh >/dev/null 2>&1; then
    echo "Network unreachable, skipping check"
    update_menubar "error"
    send_alert "🐢 Atuin 모니터" "네트워크 연결 불가 [$HOSTNAME]" "true"
    exit 0
fi

# atuin sync 시도
SYNC_RESULT=""
if command -v atuin >/dev/null 2>&1; then
    echo "Attempting sync..."
    if SYNC_RESULT=$(atuin sync 2>&1); then
        echo "$SYNC_RESULT"
    else
        echo "Sync failed: $SYNC_RESULT"
        update_menubar "error"
        send_alert "🐢❌ Atuin 동기화 실패" "동기화 오류 발생 [$HOSTNAME]" "true"
        exit 1
    fi
fi

# last_sync_time 확인
if [[ ! -f "$LAST_SYNC_FILE" ]]; then
    echo "Warning: last_sync_time file not found"
    update_menubar "error"
    send_alert "🐢 Atuin 모니터" "last_sync_time 파일 없음 [$HOSTNAME]" "true"
    exit 0
fi

LAST_SYNC_RAW=$(cat "$LAST_SYNC_FILE")
LAST_SYNC_UTC=$(echo "$LAST_SYNC_RAW" | sed 's/T/ /;s/\..*//')

# UTC 시간을 epoch으로 변환 (TZ=UTC 필수)
LAST_SYNC_EPOCH=$(TZ=UTC date -j -f "%Y-%m-%d %H:%M:%S" "$LAST_SYNC_UTC" "+%s" 2>/dev/null || echo "0")
CURRENT_EPOCH=$(date "+%s")

if [[ "$LAST_SYNC_EPOCH" == "0" ]]; then
    echo "Error: Failed to parse last_sync_time: $LAST_SYNC_RAW"
    update_menubar "error"
    send_alert "🐢❌ Atuin 모니터 오류" "last_sync_time 파싱 실패 [$HOSTNAME]" "true"
    exit 1
fi

# KST로 변환해서 표시
LAST_SYNC_KST=$(date -r "$LAST_SYNC_EPOCH" "+%Y-%m-%d %H:%M:%S")
DIFF_HOURS=$(( (CURRENT_EPOCH - LAST_SYNC_EPOCH) / 3600 ))
DIFF_MINUTES=$(( (CURRENT_EPOCH - LAST_SYNC_EPOCH) / 60 ))
echo "Last sync: $LAST_SYNC_KST KST ($DIFF_HOURS hours / $DIFF_MINUTES minutes ago)"

# 테스트 모드면 무조건 알림
if [[ "$TEST_MODE" == "true" ]]; then
    update_menubar "ok"
    send_alert "🐢🧪 Atuin 테스트" "테스트 알림 - 마지막 동기화: ${DIFF_MINUTES}분 전 [$HOSTNAME]" "false"
    echo "Test alert sent"
    exit 0
fi

# 임계값 초과 시 알림
if [[ $DIFF_HOURS -ge $THRESHOLD_HOURS ]]; then
    echo "Warning: Atuin sync is stale ($DIFF_HOURS hours)"
    update_menubar "warning"
    send_alert "🐢⚠️ Atuin 동기화 경고" "${DIFF_HOURS}시간 동안 동기화되지 않음 [$HOSTNAME]" "true"
else
    echo "OK: Sync is within threshold ($DIFF_HOURS < $THRESHOLD_HOURS hours)"
    update_menubar "ok"
    # 성공 알림은 Hammerspoon으로만 (Pushover는 에러일 때만)
    if command -v hs >/dev/null 2>&1; then
        hs -c "hs.notify.new({title='🐢✅ Atuin 동기화 OK', informativeText='마지막 동기화: ${DIFF_MINUTES}분 전'}):send()" 2>/dev/null || true
        echo "Success notification sent via Hammerspoon"
    fi
fi
