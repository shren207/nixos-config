# shellcheck shell=bash
# rebuild 스크립트 공통 함수 라이브러리 (source 전용, 직접 실행 불가)
# 사용법: REBUILD_CMD="darwin-rebuild" 설정 후 source
#
# 필수 변수:
#   REBUILD_CMD - "darwin-rebuild" 또는 "nixos-rebuild"
#
# 제공 함수:
#   parse_args, log_info, log_warn, log_error,
#   preflight_source_build_check, preflight_cask_conflict_check,
#   worktree_symlink_guard, preview_changes, cleanup_build_artifacts
#
# 출력 변수:
#   NO_CHANGES - preview_changes() 실행 후 true/false (store 경로 비교)
#   MAIN_FLAKE_PATH - detect_worktree 전 경로 보존 (worktree 여부 판별용)
#   FORCE_FLAG - --force 전달 시 true
#   CORES_FLAG - --cores N 전달 시 "--cores N"
#   UNINSTALLED_CASKS - preflight_cask_conflict_check에서 제거한 cask 목록 (복구용)

# fail-fast: REBUILD_CMD 미설정 시 즉시 실패
if [[ -z "${REBUILD_CMD:-}" ]]; then
    echo "ERROR: REBUILD_CMD must be set before sourcing rebuild-common.sh" >&2
    exit 1
fi

FLAKE_PATH="@flakePath@"
# shellcheck disable=SC2034  # Helper modules consume this global.
MAIN_FLAKE_PATH="$FLAKE_PATH"   # detect_worktree 전 경로 보존 (worktree 여부 판별용)
# shellcheck disable=SC2034  # NO_CHANGES는 source한 nrs.sh에서 사용
NO_CHANGES=false
# shellcheck disable=SC2034  # UNINSTALLED_CASKS는 nrs.sh의 run_darwin_rebuild에서 참조
UNINSTALLED_CASKS=""

# 색상 정의
# shellcheck disable=SC2034  # Helper modules consume these globals.
GREEN='\033[0;32m'
# shellcheck disable=SC2034  # Helper modules consume these globals.
YELLOW='\033[0;33m'
# shellcheck disable=SC2034  # Helper modules consume these globals.
RED='\033[0;31m'
# shellcheck disable=SC2034  # Helper modules consume these globals.
NC='\033[0m' # No Color

REBUILD_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REBUILD_COMMON_LIB_DIR=""

for candidate in "$REBUILD_COMMON_DIR/lib/rebuild" "$REBUILD_COMMON_DIR/rebuild"; do
    if [[ -d "$candidate" ]]; then
        REBUILD_COMMON_LIB_DIR="$candidate"
        break
    fi
done

[[ -n "$REBUILD_COMMON_LIB_DIR" ]] || {
    echo "ERROR: rebuild helper directory not found" >&2
    exit 1
}

for helper in common worktree locks preflight relink preview; do
    # shellcheck source=/dev/null
    source "$REBUILD_COMMON_LIB_DIR/$helper.sh"
done

detect_worktree
