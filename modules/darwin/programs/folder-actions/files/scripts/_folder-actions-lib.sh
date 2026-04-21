# shellcheck shell=bash
# Folder Actions 공유 헬퍼 — 4개 스크립트(compress-video, convert-video-to-gif,
# rename-asset, compress-rar)의 큐 처리/안정화 대기/실패 격리/실패 전용
# Pushover 알림 전용. upload-immich.sh의 send_notification과 wait_all_stable는
# 별도 owner를 유지한다 (디렉토리 전체 snapshot 기반, 다른 입력 도메인).
#
# 사용 호출 측 컨트랙트 (source 시점에 정의되어 있어야 함):
#   - log_info / log_warn / log_error
#   - verify_path_security <path> <expected_mode> <label>
#   - find_candidates  — 처리 대상 파일을 한 줄씩 stdout으로 출력
#   - process_one <file>  — drain_queue가 호출하는 단일 파일 processor
#   - WATCH_DIR, CURRENT_UID, CURRENT_PID
#   - set -euo pipefail

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

# 단일 파일 안정화 대기 — size+mtime이 짧은 시간 동안 변하지 않으면 stable로 간주.
# 복사 중 파일/일시적 쓰기를 ffmpeg 등이 incomplete read하여 영구 격리되는 회귀
# (즉시 quarantine) 방지용. timeout이면 false → drain_queue가 deferred 처리.
wait_file_stable() {
    local file="$1"
    local max_wait="${2:-30}"
    local check_interval="${3:-2}"
    local prev_sig="" cur_sig
    local waited=0

    [ -f "$file" ] || return 1

    while [ "$waited" -le "$max_wait" ]; do
        cur_sig=$(/usr/bin/stat -f '%z:%m' "$file" 2>/dev/null) || return 1
        if [ -n "$prev_sig" ] && [ "$cur_sig" = "$prev_sig" ]; then
            return 0
        fi
        prev_sig="$cur_sig"
        sleep "$check_interval"
        waited=$((waited + check_interval))
    done
    return 1
}

# 큐 비우기: find_candidates 결과를 process_one으로 처리하며,
# 처리 중 도착한 파일도 같은 락 하에서 재스캔으로 회수한다 (#374 핵심 로직).
# - wait_file_stable로 복사 중 파일은 지연시켜 다음 launchd wakeup에 재시도
# - process_one에서 quarantine 실패 시 exit 1로 무한 루프 차단 (호출부 책임)
# - process substitution 사용으로 outer shell 변수(예: rename-asset의 i)가 유지됨
drain_queue() {
    local processor="$1"
    local has_unstable remaining

    while true; do
        has_unstable=0
        while IFS= read -r f; do
            [ -f "$f" ] || continue
            if ! wait_file_stable "$f"; then
                log_warn "unstable; deferred to next wakeup: $(basename "$f")"
                has_unstable=1
                continue
            fi
            "$processor" "$f"
        done < <(find_candidates)

        remaining=$(find_candidates 2>/dev/null | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]')
        if [ "$remaining" -eq 0 ]; then
            return 0
        fi
        if [ "$has_unstable" -eq 1 ]; then
            log_info "unstable 파일 잔존; run 종료 (다음 launchd wakeup 재시도)"
            return 0
        fi
        log_info "재스캔: ${remaining}개 파일 남음"
    done
}
