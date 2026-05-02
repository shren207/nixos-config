# shellcheck shell=bash
log_info() { echo -e "${GREEN}$1${NC}"; }
log_warn() { echo -e "${YELLOW}$1${NC}"; }
log_error() { echo -e "${RED}$1${NC}"; }

#───────────────────────────────────────────────────────────────────────────────
# Worktree 감지: 현재 디렉토리가 FLAKE_PATH 저장소의 worktree이면 FLAKE_PATH 전환
# source 시점에 실행 (main()의 cd "$FLAKE_PATH"보다 먼저)
# 심링크 타깃(nixosConfigPath)은 항상 메인 레포 — 여기서는 flake 빌드 경로만 전환
#───────────────────────────────────────────────────────────────────────────────
detect_worktree() {
    local git_toplevel
    git_toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
    [[ "$git_toplevel" == "$FLAKE_PATH" ]] && return 0

    # worktree의 git-common-dir이 메인 레포의 .git을 가리키는지 검증
    local git_common_dir
    git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || return 0
    local abs_common_dir
    abs_common_dir=$(cd "$git_common_dir" 2>/dev/null && pwd) || return 0
    [[ "$abs_common_dir" != "${FLAKE_PATH}/.git" ]] && return 0

    log_warn "⚠️  Worktree detected: $git_toplevel"
    FLAKE_PATH="$git_toplevel"
}

#───────────────────────────────────────────────────────────────────────────────
# Retired Codex hooks cleanup: 기존 worktree/checkout에 남은 repo-local hook
# 산출물과 알려진 user-level legacy hook entry를 rebuild 전에 정리한다.
#───────────────────────────────────────────────────────────────────────────────
_prune_legacy_user_codex_hooks_json() {
    local hooks_json="$HOME/.codex/hooks.json"
    [[ -f "$hooks_json" ]] || return 0

    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required to safely inspect $hooks_json"
        return 1
    fi

    local stale_count
    if ! stale_count=$(jq -r '
        def stale_names: [
            "session-init-icons.sh",
            "worktree-path-guard.sh",
            "fragile-hardcoding-guard.sh",
            "system-bash-guard.sh"
        ];
        def is_stale:
            (.command? // "") as $cmd
            | [stale_names[] | . as $name | select($cmd | contains("/.codex/hooks/" + $name))]
            | length > 0;
        [(.hooks // {}) | to_entries[]? | .value[]? | .hooks[]? | select(is_stale)] | length
    ' "$hooks_json"); then
        log_warn "⚠️  Could not parse $hooks_json; leaving user-owned hook file unchanged."
        return 0
    fi

    [[ "$stale_count" =~ ^[0-9]+$ ]] || {
        log_warn "⚠️  Could not count stale entries in $hooks_json; leaving it unchanged."
        return 0
    }
    (( stale_count > 0 )) || return 0

    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/codex-hooks-json.XXXXXX")
    if ! jq '
        def stale_names: [
            "session-init-icons.sh",
            "worktree-path-guard.sh",
            "fragile-hardcoding-guard.sh",
            "system-bash-guard.sh"
        ];
        def is_stale:
            (.command? // "") as $cmd
            | [stale_names[] | . as $name | select($cmd | contains("/.codex/hooks/" + $name))]
            | length > 0;
        if (.hooks? | type) == "object" then
            .hooks |= with_entries(
                .value = (
                    .value
                    | map(
                        if (.hooks? | type) == "array" then
                            .hooks = (.hooks | map(select(is_stale | not)))
                        else
                            .
                        end
                    )
                    | map(select((.hooks? | type != "array") or ((.hooks | length) > 0)))
                )
                | select(.value | length > 0)
            )
        else
            .
        end
    ' "$hooks_json" > "$tmp"; then
        rm -f "$tmp"
        log_error "Failed to prune stale Codex hook entries from $hooks_json"
        return 1
    fi

    mv "$tmp" "$hooks_json"
    log_info "🧹 Pruned $stale_count stale Codex hook entr$( (( stale_count == 1 )) && printf 'y' || printf 'ies' ) from user-level hooks.json."
}

_clear_retired_codex_hook_artifacts() {
    local hooks_json="$FLAKE_PATH/.codex/hooks.json"
    local hooks_report="$FLAKE_PATH/.codex/hooks.compatibility.json"
    local user_hooks_report="$HOME/.codex/hooks.compatibility.json"

    if [[ -e "$hooks_json" || -e "$hooks_report" ]]; then
        rm -f "$hooks_json" "$hooks_report"
        log_info "🧹 Removed retired Codex hook artifacts."
    fi

    if [[ -e "$user_hooks_report" ]]; then
        rm -f "$user_hooks_report"
        log_info "🧹 Removed retired user-level Codex hooks.compatibility.json."
    fi

    _prune_legacy_user_codex_hooks_json
}

#───────────────────────────────────────────────────────────────────────────────
# mkOutOfStoreSymlink 엔트리 추출 (awk 단일 파서, 매치 없어도 항상 exit 0)
# 사용: extract_oos_entries "main:path/to.nix"  (git show)
#       extract_oos_entries "/abs/path/to.nix"   (파일시스템)
# DA Fix #1: grep|grep 파이프라인은 매치 없을 때 exit 1 → set -euo pipefail 하에서 nrs abort.
#            awk 단일 파서로 전환하여 항상 exit 0 보장.
# DA Fix R2-2: .mkOutOfStoreSymlink 패턴으로 문자열 리터럴 내 오탐 방지 + trailing comment strip.
#───────────────────────────────────────────────────────────────────────────────
extract_oos_entries() {
    local source="$1"
    local content

    if [[ "$source" == *:* ]]; then
        content=$(git -C "$FLAKE_PATH" show "$source" 2>/dev/null) || return 0
    else
        [[ -f "$source" ]] || return 0
        content=$(cat "$source") || return 0
    fi

    printf '%s\n' "$content" | awk '
        /^[[:space:]]*#/ { next }
        /\.mkOutOfStoreSymlink[[:space:]]/ {
            sub(/;[[:space:]]*#.*$/, "")
            sub(/.*\.mkOutOfStoreSymlink[[:space:]]*/, "")
            sub(/;[[:space:]]*$/, "")
            if ($0 != "") print
        }
    ' | sort -u
}

#───────────────────────────────────────────────────────────────────────────────
# 인수 파싱 (OFFLINE_FLAG, FORCE_FLAG, CORES_FLAG 설정)
#───────────────────────────────────────────────────────────────────────────────
# shellcheck disable=SC2034  # Public flags are consumed by callers/helpers after parse_args.
parse_args() {
    OFFLINE_FLAG=""
    FORCE_FLAG=false
    CORES_FLAG=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --offline) OFFLINE_FLAG="--offline" ;;
            --force)   FORCE_FLAG=true ;;
            --cores)
                [[ -z "${2:-}" || "$2" =~ ^-- ]] && { log_error "--cores requires a number"; exit 1; }
                [[ ! "$2" =~ ^[0-9]+$ ]] && { log_error "--cores: positive integer required"; exit 1; }
                (( 10#$2 < 1 )) && { log_error "--cores: positive integer required"; exit 1; }
                CORES_FLAG="--cores $2"; shift ;;
            *) log_error "Unknown argument: $1"; exit 1 ;;
        esac
        shift
    done
}
