#!/usr/bin/env bash
# Atuin Watchdog
# 동기화 상태를 감시하고 지연 시 알림 전송
# 참고: 실제 sync는 atuin 내장 auto_sync가 담당

set -euo pipefail

# PATH 설정 (Hammerspoon 등 다양한 환경에서 실행 가능하도록)
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$HOME/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# 환경변수에서 설정 읽기 (default.nix에서 주입)
THRESHOLD_MINUTES="${ATUIN_SYNC_THRESHOLD_MINUTES:-5}"

CREDENTIALS_FILE="$HOME/.config/pushover/credentials"
HOSTNAME=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
LOG_FILE="${HOME}/.local/share/atuin/watchdog.log"

# 로그 디렉토리 생성
mkdir -p "$(dirname "$LOG_FILE")"

# 로깅 함수
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # 콘솔 출력
    echo "[$timestamp] [$level] $message"

    # 파일 로깅
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # 로그 파일 크기 제한 (최근 500줄)
    if [[ -f "$LOG_FILE" ]]; then
        tail -500 "$LOG_FILE" > "${LOG_FILE}.tmp" 2>/dev/null && mv "${LOG_FILE}.tmp" "$LOG_FILE" || true
    fi
}

log_info() { log_message "INFO" "$1"; }
log_warn() { log_message "WARN" "$1"; }
log_error() { log_message "ERROR" "$1"; }

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
    fi

    # 3. Pushover 알림 (에러일 때만)
    if [[ -f "$CREDENTIALS_FILE" ]] && [[ "$is_error" == "true" ]]; then
        # 권한 체크 (600 권장)
        PERMS=$(stat -f %A "$CREDENTIALS_FILE" 2>/dev/null || echo "unknown")
        if [[ "$PERMS" != "600" && "$PERMS" != "400" ]]; then
            log_warn "credentials file permission is $PERMS (recommended: 600)"
        fi

        source "$CREDENTIALS_FILE"
        curl -s \
            --form-string "token=$PUSHOVER_TOKEN" \
            --form-string "user=$PUSHOVER_USER" \
            --form-string "priority=1" \
            -F "sound=falling" \
            --form-string "message=$message" \
            https://api.pushover.net/1/messages.json > /dev/null
        log_info "Alert sent via Pushover"
    fi
}

# 메뉴바 상태 업데이트 함수
update_menubar() {
    local status="$1"
    if command -v hs >/dev/null 2>&1; then
        hs -c "if atuinMenubar then atuinMenubar:setStatus('$status') end" 2>/dev/null || true
    fi
}

# last_sync 시간 조회 (atuin doctor에서)
get_last_sync_minutes() {
    local doctor_output
    local last_sync_raw
    local last_sync_clean
    local last_sync_epoch
    local current_epoch

    doctor_output=$(atuin doctor 2>&1)
    last_sync_raw=$(echo "$doctor_output" | grep -o '"last_sync": "[^"]*"' | cut -d'"' -f4)

    if [[ -z "$last_sync_raw" || "$last_sync_raw" == "no last sync" ]]; then
        echo "error"
        return 1
    fi

    # UTC 시간을 epoch로 변환 (밀리초 및 타임존 제거)
    last_sync_clean=$(echo "$last_sync_raw" | sed 's/\.[0-9]*//; s/ +00:00:00//')
    last_sync_epoch=$(TZ=UTC date -j -f "%Y-%m-%d %H:%M:%S" "$last_sync_clean" "+%s" 2>/dev/null || echo "0")
    current_epoch=$(date "+%s")

    if [[ "$last_sync_epoch" == "0" ]]; then
        echo "error"
        return 1
    fi

    echo $(( (current_epoch - last_sync_epoch) / 60 ))
    return 0
}

# ===== 메인 로직 =====

log_info "=== Atuin Watchdog ==="
log_info "Host: $HOSTNAME, Threshold: ${THRESHOLD_MINUTES}m"

# atuin 명령어 확인
if ! command -v atuin >/dev/null 2>&1; then
    log_error "atuin not found"
    update_menubar "error"
    send_alert "🐢 Atuin 모니터" "atuin 명령어를 찾을 수 없음 [$HOSTNAME]" "true"
    exit 1
fi

# 동기화 상태 확인
DIFF_MINUTES=$(get_last_sync_minutes)

if [[ "$DIFF_MINUTES" == "error" ]]; then
    log_error "Failed to get last_sync from atuin doctor"
    update_menubar "error"
    send_alert "🐢❌ Atuin 모니터 오류" "last_sync 값을 가져올 수 없음 [$HOSTNAME]" "true"
    exit 1
fi

log_info "Last sync: ${DIFF_MINUTES} minutes ago"

# 상태 판단 및 알림
if [[ $DIFF_MINUTES -ge $THRESHOLD_MINUTES ]]; then
    log_warn "Sync is stale ($DIFF_MINUTES >= $THRESHOLD_MINUTES minutes)"
    update_menubar "warning"

    # 경고 알림 (Pushover는 30분 초과 시에만)
    if [[ $DIFF_MINUTES -ge 30 ]]; then
        send_alert "🐢⚠️ Atuin 동기화 지연" "${DIFF_MINUTES}분 동안 동기화 안됨 [$HOSTNAME]" "true"
    else
        send_alert "🐢⚠️ Atuin 동기화 지연" "${DIFF_MINUTES}분 동안 동기화 안됨 [$HOSTNAME]" "false"
    fi
else
    log_info "Sync is within threshold ($DIFF_MINUTES < $THRESHOLD_MINUTES minutes)"
    update_menubar "ok"
fi
