#!/usr/bin/env bash
# darwin-rebuild preview-only script
# 빌드 후 변경사항만 미리보기 (switch 없이)
#
# 사용법:
#   nrp           # 일반 미리보기
#   nrp --offline # 오프라인 미리보기

set -euo pipefail

FLAKE_PATH="$HOME/IdeaProjects/nixos-config"
OFFLINE_FLAG=""

# 인수 파싱
[[ "${1:-}" == "--offline" ]] && OFFLINE_FLAG="--offline"

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}$1${NC}"; }
log_warn() { echo -e "${YELLOW}$1${NC}"; }
log_error() { echo -e "${RED}$1${NC}"; }

#───────────────────────────────────────────────────────────────────────────────
# 메인
#───────────────────────────────────────────────────────────────────────────────
main() {
    cd "$FLAKE_PATH" || exit 1

    if [[ -n "$OFFLINE_FLAG" ]]; then
        log_info "🔨 Building (offline, preview only)..."
    else
        log_info "🔨 Building (preview only)..."
    fi

    # shellcheck disable=SC2086
    if ! sudo darwin-rebuild build --flake "$FLAKE_PATH" $OFFLINE_FLAG; then
        log_error "❌ Build failed!"
        exit 1
    fi

    echo ""
    log_info "📋 Changes (preview only, not applied):"
    # nvd diff 출력 안내:
    # - <none> 버전: home-manager 관리 파일(files, hm_*)은 버전 접미사가 없어 정상적으로 <none> 표시
    # - nvd diff는 동일 결과 시 non-zero 반환 가능
    if ! nvd diff /run/current-system ./result; then
        log_warn "⚠️  nvd diff returned non-zero (possibly identical results)"
    fi
    echo ""
    log_info "💡 Run 'nrs' to apply these changes."
}

main
