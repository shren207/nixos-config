# shellcheck shell=bash
# Folder Actions 공유 헬퍼 — 4개 스크립트(compress-video, convert-video-to-gif,
# rename-asset, compress-rar)의 실패 격리 + 실패 전용 Pushover 알림 전용.
# upload-immich.sh의 send_notification은 별도 owner를 유지한다 (성공 알림 + 자체 token).
#
# 사용 호출 측 컨트랙트 (source 시점에 정의되어 있어야 함):
#   - log_info / log_warn / log_error
#   - verify_path_security <path> <expected_mode> <label>
#   - WATCH_DIR, CURRENT_UID, CURRENT_PID
#   - set -euo pipefail (호출부는 move_to_failed "$f" || true 로 비치명 흡수)

# Pushover credential 경로는 agenix 고정 path로 hard-code (override 금지).
PUSHOVER_CREDENTIALS="$HOME/.config/pushover/folder-actions"

# 실패 격리 sibling 경로 — watch root 밖이므로 launchd WatchPaths 추가 wakeup 없음.
_FA_LIB_FAILED_ROOT="$HOME/FolderActions/.failed"

notify_failure() {
    local title="$1"
    local message="$2"
    local priority="${3:-0}"

    [ -f "$PUSHOVER_CREDENTIALS" ] || return 0
    # shellcheck disable=SC1090
    source "$PUSHOVER_CREDENTIALS" 2>/dev/null || return 0
    [ -n "${PUSHOVER_TOKEN:-}" ] && [ -n "${PUSHOVER_USER:-}" ] || return 0

    /usr/bin/curl -sf --max-time 10 \
        --form-string "token=${PUSHOVER_TOKEN}" \
        --form-string "user=${PUSHOVER_USER}" \
        --form-string "title=${title}" \
        --form-string "message=${message}" \
        --form-string "priority=${priority}" \
        https://api.pushover.net/1/messages.json > /dev/null 2>&1 || true
}

ensure_failed_dir() {
    local script_name failed_dir

    script_name=$(basename "$WATCH_DIR")
    failed_dir="${_FA_LIB_FAILED_ROOT}/${script_name}"

    if [ -L "${_FA_LIB_FAILED_ROOT}" ]; then
        log_error "failed root is symlink: ${_FA_LIB_FAILED_ROOT}"
        return 1
    fi
    if [ -L "$failed_dir" ]; then
        log_error "failed dir is symlink: $failed_dir"
        return 1
    fi

    /bin/mkdir -p "$failed_dir" || {
        log_error "mkdir failed: $failed_dir"
        return 1
    }
    /bin/chmod 700 "$failed_dir" || {
        log_error "chmod failed: $failed_dir"
        return 1
    }

    # 기존 스크립트의 verify_path_security와 동일 수준 검증.
    verify_path_security "$failed_dir" "0700" "failed dir" || return 1

    printf '%s\n' "$failed_dir"
}

move_to_failed() {
    local src="$1"
    local failed_dir basename_f target stamp

    [ -f "$src" ] || return 0

    failed_dir=$(ensure_failed_dir) || {
        notify_failure "FolderActions 오류" "실패 격리 디렉토리 준비 실패: $(basename "$src")" 1
        return 1
    }

    basename_f=$(basename "$src")
    # 타임스탬프(밀리초) + PID + RANDOM 으로 동일 초/동일 basename 충돌 회피.
    stamp=$(/bin/date +%Y%m%dT%H%M%S 2>/dev/null) || stamp="unknown"
    target="${failed_dir}/${stamp}_${CURRENT_PID}_${RANDOM}_${basename_f}"

    if /bin/mv -- "$src" "$target"; then
        log_warn "실패 파일 격리: ${basename_f} -> .failed/$(basename "$failed_dir")/"
        notify_failure "FolderActions 실패" "처리 실패 격리: ${basename_f}" 0
        return 0
    else
        log_error "실패 파일 격리 mv 실패: ${basename_f}"
        notify_failure "FolderActions 오류" "실패 파일 mv 실패: ${basename_f}" 1
        return 1
    fi
}
