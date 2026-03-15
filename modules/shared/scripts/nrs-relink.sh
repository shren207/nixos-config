#!/usr/bin/env bash
# nrs-relink: worktree 심링크 전환/복원 CLI
# standalone 스크립트 — rebuild-common.sh를 source하지 않음
#
# 사용법:
#   nrs-relink.sh relink   # ~/.claude/* 등을 현재 worktree로 전환
#   nrs-relink.sh restore  # nix store 체인으로 복원
#   nrs-relink.sh status   # 현재 심링크 상태 표시

set -euo pipefail

MAIN_REPO="@flakePath@"
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

#───────────────────────────────────────────────────────────────────────────────
# Discovery: home-manager-files nix store 경로 추출
#───────────────────────────────────────────────────────────────────────────────
_discover_hmf() {
    local probe="$HOME/.claude/settings.json"
    [[ -L "$probe" ]] || return 1
    local hmf
    hmf=$(readlink "$probe")
    # /nix/store/<hash>-home-manager-files/.claude/settings.json → 디렉토리 부분만
    hmf="${hmf%/.claude/settings.json}"
    [[ "$hmf" == /nix/store/*-home-manager-files ]] || return 1
    echo "$hmf"
}

#───────────────────────────────────────────────────────────────────────────────
# HMF 내의 모든 out-of-store 심링크 발견
# 출력: home_rel|repo_rel (파이프 구분)
#───────────────────────────────────────────────────────────────────────────────
_discover_oos_entries() {
    local hmf="$1" main_repo="$2"
    find "$hmf" -type l -print0 2>/dev/null | while IFS= read -r -d '' link; do
        local final_target
        final_target=$(readlink -f "$link" 2>/dev/null) || continue
        # main repo 하위 파일만 (nix store 내부 심링크는 제외)
        [[ "$final_target" == "$main_repo"/* ]] || continue
        local home_rel="${link#"$hmf"/}"
        local repo_rel="${final_target#"$main_repo"/}"
        echo "${home_rel}|${repo_rel}"
    done
}

#───────────────────────────────────────────────────────────────────────────────
# relink: worktree 경로로 심링크 전환
#───────────────────────────────────────────────────────────────────────────────
cmd_relink() {
    # worktree 여부 검증
    local git_toplevel
    git_toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || {
        echo -e "${YELLOW}Git repository not found${NC}" >&2
        exit 1
    }

    if [[ "$git_toplevel" == "$MAIN_REPO" ]]; then
        echo -e "${YELLOW}Not in a worktree (main repo). Nothing to relink.${NC}"
        return 0
    fi

    local worktree="$git_toplevel"

    local hmf
    hmf=$(_discover_hmf) || {
        echo -e "${YELLOW}Could not discover home-manager-files store path${NC}" >&2
        exit 1
    }

    local relinked=0 skipped=0
    while IFS='|' read -r home_rel repo_rel; do
        [[ -z "$home_rel" ]] && continue
        local wt_target="$worktree/$repo_rel"
        if [[ -e "$wt_target" || -L "$wt_target" ]]; then
            ln -sfn "$wt_target" "$HOME/$home_rel"
            ((++relinked))
        else
            echo -e "${YELLOW}  skip: $home_rel (not in worktree)${NC}"
            ((++skipped))
        fi
    done < <(_discover_oos_entries "$hmf" "$MAIN_REPO")

    echo -e "${GREEN}Relinked $relinked symlink(s) to worktree${NC}"
    if [[ $skipped -gt 0 ]]; then
        echo -e "${YELLOW}  ($skipped skipped — not present in worktree)${NC}"
    fi
}

#───────────────────────────────────────────────────────────────────────────────
# restore: nix store 체인으로 복원
#───────────────────────────────────────────────────────────────────────────────
cmd_restore() {
    local hmf
    hmf=$(_discover_hmf) || {
        echo -e "${YELLOW}Could not discover home-manager-files store path${NC}" >&2
        exit 1
    }

    local restored=0
    while IFS='|' read -r home_rel repo_rel; do
        [[ -z "$home_rel" ]] && continue
        ln -sfn "$hmf/$home_rel" "$HOME/$home_rel"
        ((++restored))
    done < <(_discover_oos_entries "$hmf" "$MAIN_REPO")

    echo -e "${GREEN}Restored $restored symlink(s) to nix store chain${NC}"
}

#───────────────────────────────────────────────────────────────────────────────
# status: 현재 심링크 상태 표시
#───────────────────────────────────────────────────────────────────────────────
cmd_status() {
    local hmf
    hmf=$(_discover_hmf) || {
        echo -e "${YELLOW}Could not discover home-manager-files store path${NC}" >&2
        exit 1
    }

    local count=0
    while IFS='|' read -r home_rel repo_rel; do
        [[ -z "$home_rel" ]] && continue
        local home_path="$HOME/$home_rel"

        if [[ ! -L "$home_path" ]]; then
            echo -e "  ${YELLOW}[NOT SYMLINK]${NC} $home_rel"
        elif [[ ! -e "$home_path" ]]; then
            echo -e "  ${YELLOW}[DANGLING]${NC}    $home_rel"
        else
            local current_target
            current_target=$(readlink -f "$home_path" 2>/dev/null) || current_target=""

            if [[ "$current_target" == "$MAIN_REPO"/* ]]; then
                echo -e "  ${GREEN}[main]${NC}        $home_rel"
            else
                # worktree 경로인지 확인
                local direct_target
                direct_target=$(readlink "$home_path" 2>/dev/null) || direct_target=""
                echo -e "  ${YELLOW}[worktree]${NC}    $home_rel → $direct_target"
            fi
        fi
        ((++count))
    done < <(_discover_oos_entries "$hmf" "$MAIN_REPO")

    if [[ $count -eq 0 ]]; then
        echo -e "${YELLOW}No out-of-store symlinks found${NC}"
    else
        echo -e "\n  Total: $count entries"
    fi
}

#───────────────────────────────────────────────────────────────────────────────
# Entry point
#───────────────────────────────────────────────────────────────────────────────
case "${1:-}" in
    relink)  cmd_relink ;;
    restore) cmd_restore ;;
    status)  cmd_status ;;
    *)
        echo "Usage: nrs-relink.sh {relink|restore|status}" >&2
        exit 1
        ;;
esac
