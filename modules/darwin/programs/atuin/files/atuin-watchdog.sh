#!/usr/bin/env bash
# Atuin Watchdog
# 동기화 상태를 감시하고 지연 시 복구 시도 + 알림 전송

set -euo pipefail

# PATH 설정 (Hammerspoon 등 다양한 환경에서 실행 가능하도록)
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$HOME/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# 환경변수에서 설정 읽기 (default.nix에서 주입)
THRESHOLD_MINUTES="${ATUIN_SYNC_THRESHOLD_MINUTES:-5}"
MAX_RETRY_COUNT="${ATUIN_MAX_RETRY_COUNT:-3}"
INITIAL_BACKOFF="${ATUIN_INITIAL_BACKOFF:-5}"
DAEMON_STARTUP_WAIT="${ATUIN_DAEMON_STARTUP_WAIT:-5}"
NETWORK_CHECK_TIMEOUT="${ATUIN_NETWORK_CHECK_TIMEOUT:-5}"
ATUIN_SYNC_SERVER="${ATUIN_SYNC_SERVER:-api.atuin.sh}"

CREDENTIALS_FILE="$HOME/.config/pushover/credentials"
HOSTNAME=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
LOG_FILE="${HOME}/.local/share/atuin/watchdog.log"
LAST_SUCCESS_FILE="${HOME}/.local/share/atuin/watchdog_last_success"

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

    # 로그 파일 크기 제한 (최근 1000줄)
    if [[ -f "$LOG_FILE" ]]; then
        tail -1000 "$LOG_FILE" > "${LOG_FILE}.tmp" 2>/dev/null && mv "${LOG_FILE}.tmp" "$LOG_FILE" || true
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
        log_info "Alert sent via Hammerspoon"
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

# 네트워크 연결 확인 함수
check_network_connectivity() {
    log_info "Checking network to $ATUIN_SYNC_SERVER..."

    # 1. DNS 확인
    if ! host "$ATUIN_SYNC_SERVER" >/dev/null 2>&1; then
        log_error "DNS resolution failed for $ATUIN_SYNC_SERVER"
        return 1
    fi

    # 2. HTTPS 연결 확인
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout "$NETWORK_CHECK_TIMEOUT" \
        --max-time "$NETWORK_CHECK_TIMEOUT" \
        "https://$ATUIN_SYNC_SERVER" 2>/dev/null) || true

    # 404도 서버 응답이므로 네트워크는 정상으로 간주
    if [[ -n "$http_code" && "$http_code" != "000" ]]; then
        log_info "Network OK (HTTP $http_code)"
        return 0
    fi

    log_error "No response from server (HTTP code: ${http_code:-empty})"
    return 1
}

# 에러 로깅이 포함된 sync 실행
execute_sync() {
    local sync_output
    local sync_exit_code

    log_info "Executing atuin sync..."

    sync_output=$(atuin sync 2>&1)
    sync_exit_code=$?

    if [[ $sync_exit_code -eq 0 ]]; then
        log_info "Sync completed successfully"
        return 0
    else
        log_error "Sync failed (exit code: $sync_exit_code)"
        log_error "Sync output: $sync_output"
        return 1
    fi
}

# 지수 백오프 재시도 로직
sync_with_retry() {
    local attempt=1
    local backoff="$INITIAL_BACKOFF"

    while [[ $attempt -le $MAX_RETRY_COUNT ]]; do
        log_info "Sync attempt $attempt/$MAX_RETRY_COUNT"

        if execute_sync; then
            return 0
        fi

        if [[ $attempt -lt $MAX_RETRY_COUNT ]]; then
            log_warn "Retry in ${backoff}s..."
            sleep "$backoff"
            backoff=$((backoff * 2))  # 지수 백오프
            [[ $backoff -gt 60 ]] && backoff=60
        fi
        ((attempt++))
    done

    log_error "All $MAX_RETRY_COUNT sync attempts failed"
    return 1
}

# Daemon 재시작
restart_daemon() {
    log_info "Restarting atuin daemon..."

    if launchctl kickstart -k "gui/$(id -u)/com.green.atuin-daemon" 2>/dev/null; then
        log_info "Daemon restart requested, waiting ${DAEMON_STARTUP_WAIT}s..."
        sleep "$DAEMON_STARTUP_WAIT"
        return 0
    else
        log_error "Failed to restart daemon via launchctl"
        return 1
    fi
}

# 마지막 성공 시간 저장 (sync 명령 성공 시)
save_last_success() {
    date "+%s" > "$LAST_SUCCESS_FILE"
    log_info "Saved last success time to $LAST_SUCCESS_FILE"
}

# 마지막 성공 시간 조회 (분 단위)
get_minutes_since_last_success() {
    if [[ -f "$LAST_SUCCESS_FILE" ]]; then
        local last_success_epoch
        last_success_epoch=$(cat "$LAST_SUCCESS_FILE")
        local current_epoch
        current_epoch=$(date "+%s")
        echo $(( (current_epoch - last_success_epoch) / 60 ))
    else
        echo "999999"  # 파일 없으면 매우 큰 값 반환
    fi
}

# last_sync 시간 조회 (atuin doctor에서)
get_last_sync_info() {
    local doctor_output
    local last_sync_raw
    local last_sync_clean
    local last_sync_epoch
    local current_epoch
    local diff_minutes

    doctor_output=$(atuin doctor 2>&1)
    last_sync_raw=$(echo "$doctor_output" | grep -o '"last_sync": "[^"]*"' | cut -d'"' -f4)

    if [[ -z "$last_sync_raw" ]]; then
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

    diff_minutes=$(( (current_epoch - last_sync_epoch) / 60 ))
    echo "$diff_minutes"
    return 0
}

# ===== 메인 로직 =====

log_info "=== Atuin Watchdog ==="
log_info "Host: $HOSTNAME"
log_info "Threshold: $THRESHOLD_MINUTES minutes, Max retries: $MAX_RETRY_COUNT"

# atuin 명령어 확인
if ! command -v atuin >/dev/null 2>&1; then
    log_error "atuin not found"
    update_menubar "error"
    send_alert "🐢 Atuin 모니터" "atuin 명령어를 찾을 수 없음 [$HOSTNAME]" "true"
    exit 1
fi

# 현재 동기화 상태 확인
# 1. atuin doctor의 last_sync 값
DIFF_MINUTES_DOCTOR=$(get_last_sync_info)

# 2. watchdog의 마지막 성공 시간
DIFF_MINUTES_SUCCESS=$(get_minutes_since_last_success)

# 두 값 중 더 최근 것을 사용 (더 작은 값)
if [[ "$DIFF_MINUTES_DOCTOR" == "error" ]]; then
    # doctor 실패 시 last_success만 사용
    DIFF_MINUTES="$DIFF_MINUTES_SUCCESS"
    log_warn "Failed to get last_sync from doctor, using last_success: $DIFF_MINUTES minutes ago"
elif [[ $DIFF_MINUTES_SUCCESS -lt $DIFF_MINUTES_DOCTOR ]]; then
    # watchdog이 더 최근에 성공한 경우
    DIFF_MINUTES="$DIFF_MINUTES_SUCCESS"
    log_info "Using watchdog last_success: $DIFF_MINUTES minutes ago (doctor: $DIFF_MINUTES_DOCTOR)"
else
    DIFF_MINUTES="$DIFF_MINUTES_DOCTOR"
    log_info "Using doctor last_sync: $DIFF_MINUTES minutes ago (watchdog: $DIFF_MINUTES_SUCCESS)"
fi

# 임계값 초과 시 복구 시도
if [[ $DIFF_MINUTES -ge $THRESHOLD_MINUTES ]]; then
    log_warn "Sync is stale ($DIFF_MINUTES >= $THRESHOLD_MINUTES minutes)"
    update_menubar "warning"

    # 1. 네트워크 확인 먼저
    if ! check_network_connectivity; then
        log_error "Network issue detected - skipping recovery"
        update_menubar "error"
        send_alert "🐢⚠️ Atuin 네트워크 오류" "네트워크 연결 문제로 동기화 불가 [$HOSTNAME]" "true"
        exit 1
    fi

    # 2. 먼저 sync만 재시도 (daemon 문제가 아닐 수 있음)
    log_info "Attempting sync without daemon restart..."
    if sync_with_retry; then
        # sync 명령이 성공하면 (exit code 0), 동기화 완료로 간주
        # 참고: "0/0 up/down"인 경우 last_sync가 업데이트되지 않을 수 있음
        save_last_success
        log_info "Sync command succeeded - considering sync recovered"
        update_menubar "ok"
        send_alert "🐢✅ Atuin 복구됨" "동기화 복구됨 (daemon 재시작 없이) [$HOSTNAME]" "false"
        exit 0
    fi

    # 3. sync 실패 시 daemon 재시작
    log_warn "Sync retry failed, attempting daemon restart..."
    if restart_daemon; then
        # daemon 재시작 후 다시 sync 시도
        if sync_with_retry; then
            # sync 명령이 성공하면 동기화 완료로 간주
            save_last_success
            log_info "Sync command succeeded after daemon restart"
            update_menubar "ok"
            send_alert "🐢✅ Atuin 복구됨" "daemon 재시작으로 동기화 복구됨 [$HOSTNAME]" "false"
            exit 0
        fi
    fi

    # 4. 모든 시도 실패
    log_error "All recovery attempts failed"
    update_menubar "error"
    send_alert "🐢❌ Atuin 동기화 실패" "모든 복구 시도 실패 [$HOSTNAME]" "true"
    exit 1
else
    log_info "Sync is within threshold ($DIFF_MINUTES < $THRESHOLD_MINUTES minutes)"
    update_menubar "ok"
fi
