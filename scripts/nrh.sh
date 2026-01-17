#!/usr/bin/env bash
# NixOS/darwin 세대 히스토리 조회
#
# 사용법:
#   nrh           # 최근 10개 세대 (기본)
#   nrh -n 20     # 최근 20개 세대
#   nrh -a        # 전체 세대 (느림)

set -euo pipefail

PROFILE_PATH="/nix/var/nix/profiles/system"
DEFAULT_LIMIT=10

show_usage() {
    echo "Usage: nrh [-a|--all] [-n|--limit N]"
    echo "  -a, --all     Show all generations (slow)"
    echo "  -n, --limit N Show last N generations (default: $DEFAULT_LIMIT)"
}

SHOW_ALL=false
LIMIT=$DEFAULT_LIMIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--all) SHOW_ALL=true; shift ;;
        -n|--limit) LIMIT="$2"; shift 2 ;;
        -h|--help) show_usage; exit 0 ;;
        *) show_usage; exit 1 ;;
    esac
done

if [[ "$SHOW_ALL" == "true" ]]; then
    echo "Showing all generations (this may take a while)..."
    nvd history -p "$PROFILE_PATH"
else
    # 현재 세대 번호 추출
    CURRENT_GEN=$(readlink "$PROFILE_PATH" | grep -o '[0-9]*')
    MIN_GEN=$((CURRENT_GEN - LIMIT))
    [[ $MIN_GEN -lt 1 ]] && MIN_GEN=1

    echo "Showing generations $MIN_GEN to $CURRENT_GEN..."
    nvd history -p "$PROFILE_PATH" -m "$MIN_GEN"
fi
