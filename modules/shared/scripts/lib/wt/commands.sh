# shellcheck shell=bash
# ── Bootstrap ────────────────────────────────────────────────────────────────

_bootstrap_worktree() {
  local wt_path="$1"
  local git_root="$2"

  # 중첩 회귀 가드
  if [[ -d "$wt_path/.claude/.claude" ]] || [[ -d "$wt_path/.codex/.codex" ]]; then
    _die "중첩 .claude/.claude 또는 .codex/.codex 감지 — bootstrap 중단"
  fi

  # .claude/settings.local.json 복사 (파일 단위)
  local src_settings="$git_root/.claude/settings.local.json"
  local dst_claude_dir="$wt_path/.claude"
  if [[ -f "$src_settings" ]]; then
    mkdir -p "$dst_claude_dir"
    cp "$src_settings" "$dst_claude_dir/settings.local.json"
  fi

  # .codex/ 디렉토리 복사 (기존 제거 후 복사 — 중첩 방지)
  local src_codex="$git_root/.codex"
  if [[ -d "$src_codex" ]]; then
    rm -rf "$wt_path/.codex"
    cp -r "$src_codex" "$wt_path/.codex"
  fi

  # .claude/plans/ 제거 (worktree에서는 불필요)
  rm -rf "$wt_path/.claude/plans"

  # Claude → Codex projection 재실행 (plugin-aware worktree bootstrap 복구)
  local script_dir codex_sync_sh=""
  script_dir="${WT_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
  local repo_local_sync_sh="$script_dir/codex-sync.sh"
  local deployed_sync_bin="$script_dir/codex-sync"

  if [[ -x "$deployed_sync_bin" ]]; then
    codex_sync_sh="$deployed_sync_bin"
  elif [[ -f "$repo_local_sync_sh" ]]; then
    codex_sync_sh="$repo_local_sync_sh"
  else
    codex_sync_sh="$(command -v codex-sync 2>/dev/null || true)"
  fi

  if [[ -n "$codex_sync_sh" ]]; then
    if ! bash "$codex_sync_sh" "$wt_path"; then
      _warn "codex-sync 실패 — 수동으로 'codex-sync $wt_path'를 실행하세요"
    fi
  else
    _warn "codex-sync 스크립트를 찾지 못해 Codex projection을 건너뜁니다"
  fi
}

# ── worktree 열기 (tmux 또는 stdout) ─────────────────────────────────────────

_open_worktree() {
  local wt_path="$1" window_name="$2" stay="$3" run_claude="$4" use_tmux_session="${5:-false}"

  # --tmux: tmux 밖에서만 세션 모드 활성화 (tmux 안이면 윈도우 모드로 fallback — 의도적 정책)
  if [[ "$use_tmux_session" == "true" ]] && [[ -z "${TMUX:-}" ]]; then
    local session_name
    session_name=$(_wt_session_name "$window_name")
    _wt_tmux_session_open "$wt_path" "$session_name" "$stay" "$run_claude"
    return
  fi

  if [[ -n "${TMUX:-}" ]]; then
    local window_id open_rc=0
    window_id=$(_wt_tmux_open "$wt_path" "$window_name" "$stay") || open_rc=$?

    # tmux 연결 실패 (stale TMUX 환경변수 등) → fallback: 경로 stdout 출력
    if (( open_rc == 1 )); then
      _info "경고: tmux 윈도우 생성 실패 — 경로로 fallback합니다"
      [[ "$run_claude" == "true" ]] && _info "경고: --claude는 tmux 윈도우가 필요합니다"
      echo "$wt_path"
      return
    fi

    # --claude: 새 윈도우에서만 claude 실행 (open_rc == 0)
    # 기존 윈도우(open_rc == 2)에는 send-keys 하지 않음 — 실행 중인 프로세스에 주입 방지
    # send-keys로 큐잉 — 셸 초기화 완료 후 버퍼에서 읽어 실행 (레이스 안전)
    if [[ "$run_claude" == "true" ]] && [[ -n "${window_id:-}" ]]; then
      if (( open_rc == 0 )); then
        tmux send-keys -t "$window_id" \
          "claude --dangerously-skip-permissions --mcp-config ~/.claude/mcp.json" Enter
      else
        _info "기존 윈도우 — --claude 스킵 (실행 중인 프로세스 보호)"
      fi
    fi
  else
    # tmux 밖: 경로 stdout 출력 (래퍼가 cd)
    [[ "$run_claude" == "true" ]] && _info "경고: --claude는 tmux 세션 안에서만 동작합니다"
    if [[ "$stay" == "true" ]]; then
      # --stay: 현재 디렉토리 유지, 경로만 안내
      _info "worktree 경로: $wt_path"
    else
      echo "$wt_path"
    fi
  fi
}

# ── worktree 제거 (tmux 윈도우 포함) ─────────────────────────────────────────

_remove_worktree() {
  local wt_path="$1" branch="$2" git_root="$3"
  local name
  name=$(basename "$wt_path")

  # cwd 가드: 현재 셸이 삭제 대상 worktree 안에 있으면 중단
  local current_dir
  current_dir=$(pwd -P)
  if [[ "$current_dir" == "$wt_path" || "$current_dir" == "$wt_path/"* ]]; then
    _info "스킵: $name — 현재 작업 디렉토리가 이 worktree 안에 있습니다"
    return 1
  fi

  # 활성 프로세스 가드: tmux 윈도우에 실행 중인 프로세스(nvim, claude 등)가 있으면 중단
  if _wt_has_active_process "$wt_path"; then
    return 1
  fi

  # tmux 윈도우 닫기 (실패해도 worktree는 삭제)
  _wt_tmux_close "$wt_path" || true

  # tmux 세션 정리 (wt- 접두사 세션, 연결된 클라이언트 있으면 삭제 중단)
  local session_name
  session_name=$(_wt_session_name "$name")
  _wt_tmux_session_close "$session_name" || {
    _info "스킵: $name — 연결된 tmux 세션이 있어 삭제하지 않습니다"
    return 1
  }

  # worktree 제거
  git -C "$git_root" worktree remove --force "$wt_path" 2>/dev/null || rm -rf "$wt_path"

  # 브랜치 삭제 (detached가 아닌 경우)
  if [[ "$branch" != "detached" ]]; then
    git -C "$git_root" branch -D "$branch" 2>/dev/null || true
  fi

  _info "삭제: $name ($branch)"

  # worktree 삭제 후 dangling 심링크 자동 복원 (#294)
  "$HOME/.local/bin/nrs-relink" fix-dangling >/dev/null 2>&1 || \
      _info "⚠️  심링크 복원 실패 (치명적이지 않음, 수동 nrs 필요)"
}

# ── 서브커맨드: create ───────────────────────────────────────────────────────

cmd_create() {
  local stay=false
  local run_claude=false
  local use_tmux_session=false
  local branch_name=""

  # 옵션 파싱
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stay)   stay=true ;;
      --claude) run_claude=true ;;
      --tmux)   use_tmux_session=true ;;
      -h|--help) show_help; return 0 ;;
      -*)       _die "알 수 없는 옵션: $1" ;;
      *)
        [[ -n "$branch_name" ]] && _die "브랜치명이 이미 지정됨: $branch_name (추가: $1)"
        branch_name="$1"
        ;;
    esac
    shift
  done

  [[ -z "$branch_name" ]] && _die "브랜치명을 지정하세요. 사용법: wt [--stay] [--claude] <branch>"

  local git_root
  git_root=$(_get_repo_root) || _die "Git 저장소가 아닙니다"

  # 현재 브랜치 기록 (.wt-parent용)
  local parent_branch
  parent_branch=$(git branch --show-current 2>/dev/null)
  if [[ -z "$parent_branch" ]]; then
    parent_branch=$(git rev-parse --short HEAD 2>/dev/null) || parent_branch="unknown"
  fi

  # 디렉토리명 결정
  local dir_name
  dir_name=$(_sanitize_name "$branch_name")
  # shellcheck disable=SC2153  # WORKTREE_DIR is set by wt.sh before sourcing helpers.
  local worktree_dir="$git_root/$WORKTREE_DIR/$dir_name"

  # 슬래시 포함 브랜치: 디렉토리명 매핑 안내 (슬래시→언더스코어 변환 인지용)
  if [[ "$dir_name" != "$branch_name" ]]; then
    _info "디렉토리명: $dir_name (← $branch_name)"
  fi

  # 기존 디렉토리 처리
  if [[ -d "$worktree_dir" ]]; then
    if [[ -f "$worktree_dir/.git" ]]; then
      _handle_existing_worktree "$worktree_dir" "$branch_name" "$git_root" "$parent_branch" "$stay" "$run_claude" "$use_tmux_session"
      return $?
    fi
    # 디렉토리는 있지만 유효한 worktree가 아님 → 정리 후 새로 생성
    rm -rf "$worktree_dir"
  fi

  # 기존 브랜치 존재 확인
  if git show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
    _handle_existing_branch "$worktree_dir" "$branch_name" "$git_root" "$parent_branch" "$stay" "$run_claude" "$use_tmux_session"
    return $?
  fi

  # 새 worktree 생성 (현재 HEAD 기준)
  mkdir -p "$(dirname "$worktree_dir")"
  git worktree add -b "$branch_name" "$worktree_dir" >&2 || _die "worktree 생성 실패"

  echo "$parent_branch" > "$worktree_dir/.wt-parent"
  _bootstrap_worktree "$worktree_dir" "$git_root"

  _info "worktree 생성: $branch_name (from $parent_branch)"

  _open_worktree "$worktree_dir" "$dir_name" "$stay" "$run_claude" "$use_tmux_session"
}

# 기존 worktree 처리
_handle_existing_worktree() {
  local worktree_dir="$1" branch_name="$2" git_root="$3" parent_branch="$4" stay="$5" run_claude="$6" use_tmux_session="${7:-false}"
  local dir_name
  dir_name=$(basename "$worktree_dir")

  local choice
  choice=$(_choose "worktree '$branch_name'이(가) 이미 존재합니다" "기존 열기" "재생성" "취소") || return 1

  case "$choice" in
    "기존 열기")
      _open_worktree "$worktree_dir" "$dir_name" "$stay" "$run_claude" "$use_tmux_session"
      ;;
    "재생성")
      # unpushed/dirty 경고
      local warnings=()
      _wt_is_dirty "$worktree_dir" && warnings+=("uncommitted 변경사항이 있습니다")
      _wt_has_unpushed "$worktree_dir" && warnings+=("push하지 않은 커밋이 있습니다")

      if (( ${#warnings[@]} > 0 )); then
        echo "경고:" >&2
        for w in "${warnings[@]}"; do
          echo "  - $w" >&2
        done
        _confirm "정말 재생성하시겠습니까? (모든 변경사항 삭제)" || { _info "취소됨"; return 1; }
      fi

      # cwd 가드: 현재 셸이 대상 worktree 안에 있으면 재생성 불가
      local current_dir
      current_dir=$(pwd -P)
      if [[ "$current_dir" == "$worktree_dir" || "$current_dir" == "$worktree_dir/"* ]]; then
        _info "재생성 불가: 현재 작업 디렉토리가 이 worktree 안에 있습니다"
        _info "다른 디렉토리에서 다시 시도하세요"
        return 1
      fi

      # 활성 프로세스 가드: tmux 윈도우에 실행 중인 프로세스가 있으면 재생성 불가
      if _wt_has_active_process "$worktree_dir"; then
        _info "다른 프로세스를 종료한 뒤 다시 시도하세요"
        return 1
      fi

      _wt_tmux_close "$worktree_dir" || true
      # tmux 세션 정리 (연결된 클라이언트 있으면 재생성 중단)
      local _recreate_session
      _recreate_session=$(_wt_session_name "$dir_name")
      _wt_tmux_session_close "$_recreate_session" || {
        _info "재생성 불가: tmux 세션에 연결된 클라이언트가 있습니다"
        _info "세션을 종료한 뒤 다시 시도하세요"
        return 1
      }
      git worktree remove --force "$worktree_dir" 2>/dev/null || rm -rf "$worktree_dir"
      git worktree prune 2>/dev/null || true
      git branch -D "$branch_name" >&2 2>/dev/null || true

      git worktree add -b "$branch_name" "$worktree_dir" >&2 || _die "worktree 재생성 실패"
      echo "$parent_branch" > "$worktree_dir/.wt-parent"
      _bootstrap_worktree "$worktree_dir" "$git_root"
      _info "worktree 재생성: $branch_name (from $parent_branch)"
      _open_worktree "$worktree_dir" "$dir_name" "$stay" "$run_claude" "$use_tmux_session"
      ;;
    *)
      _info "취소됨"
      return 1
      ;;
  esac
}

# 기존 브랜치 처리 (worktree 없음)
_handle_existing_branch() {
  local worktree_dir="$1" branch_name="$2" git_root="$3" parent_branch="$4" stay="$5" run_claude="$6" use_tmux_session="${7:-false}"
  local dir_name
  dir_name=$(basename "$worktree_dir")

  # 브랜치가 다른 worktree에 이미 checkout되어 있는지 확인
  # (checkout된 브랜치는 worktree add/branch -D 모두 실패)
  local branch_ref="refs/heads/$branch_name"
  local checked_out_at
  checked_out_at=$(git worktree list --porcelain 2>/dev/null | awk -v ref="$branch_ref" '
    /^worktree / { wt = substr($0, 10) }
    /^branch / && substr($0, 8) == ref { print wt; exit }
  ')
  if [[ -n "$checked_out_at" ]]; then
    _info "브랜치 '$branch_name'이(가) 이미 checkout되어 있습니다: $checked_out_at"
    _info "다른 브랜치로 전환 후 다시 시도하세요"
    return 1
  fi

  local choice
  choice=$(_choose "브랜치 '$branch_name'이(가) 이미 존재합니다 (worktree 없음)" "기존 브랜치 사용" "새로 생성" "취소") || return 1

  case "$choice" in
    "기존 브랜치 사용")
      mkdir -p "$(dirname "$worktree_dir")"
      git worktree add "$worktree_dir" "$branch_name" >&2 || _die "worktree 생성 실패"
      echo "$parent_branch" > "$worktree_dir/.wt-parent"
      _bootstrap_worktree "$worktree_dir" "$git_root"
      _info "worktree 생성 (기존 브랜치): $branch_name"
      _open_worktree "$worktree_dir" "$dir_name" "$stay" "$run_claude" "$use_tmux_session"
      ;;
    "새로 생성")
      # 커밋 유실 경고: 현재 HEAD에서 도달 불가능한 커밋이 있으면 확인
      local ahead_count
      ahead_count=$(git rev-list --count "HEAD..$branch_name" 2>/dev/null) || true
      if (( ${ahead_count:-0} > 0 )); then
        _info "경고: '$branch_name'에 현재 HEAD에 없는 커밋 ${ahead_count}개가 있습니다"
        _confirm "브랜치를 삭제하고 새로 생성하시겠습니까?" || { _info "취소됨"; return 1; }
      fi
      git branch -D "$branch_name" >&2 2>/dev/null || true
      mkdir -p "$(dirname "$worktree_dir")"
      git worktree add -b "$branch_name" "$worktree_dir" >&2 || _die "worktree 생성 실패"
      echo "$parent_branch" > "$worktree_dir/.wt-parent"
      _bootstrap_worktree "$worktree_dir" "$git_root"
      _info "worktree 생성 (브랜치 재생성): $branch_name (from $parent_branch)"
      _open_worktree "$worktree_dir" "$dir_name" "$stay" "$run_claude" "$use_tmux_session"
      ;;
    *)
      _info "취소됨"
      return 1
      ;;
  esac
}

# ── 서브커맨드: cd ───────────────────────────────────────────────────────────

cmd_cd() {
  local git_root
  git_root=$(_get_repo_root) || _die "Git 저장소가 아닙니다"

  local wt_base="$git_root/$WORKTREE_DIR"
  [[ -d "$wt_base" ]] || _die "worktree가 없습니다: $wt_base"

  # worktree 목록 수집
  local worktrees=()
  while IFS= read -r wt; do
    [[ -n "$wt" ]] && worktrees+=("$wt")
  done < <(_collect_worktrees "$git_root")

  (( ${#worktrees[@]} == 0 )) && _die "활성 worktree가 없습니다"

  local target_path=""
  local use_tmux_session=false
  local search=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tmux) use_tmux_session=true ;;
      -)      search="-" ;;
      -*)     _die "알 수 없는 옵션: $1" ;;
      *)
        [[ -n "$search" ]] && _die "검색어가 이미 지정됨: $search (추가: $1)"
        search="$1"
        ;;
    esac
    shift
  done

  # wt cd - : 이전 worktree로 이동 (cd -, git checkout - 와 동일 패턴)
  if [[ "$search" == "-" ]]; then
    local last_file="$git_root/$WT_LAST_FILE"
    [[ -f "$last_file" ]] || _die "이전 worktree 기록이 없습니다"
    local last_path
    last_path=$(cat "$last_file")
    if [[ ! -d "$last_path" ]]; then
      _info "이전 worktree가 삭제됨: $(basename "$last_path") → main repo로 이동"
      last_path="$git_root"
    fi
    # 현재 위치 저장 후 이동
    local current_dir
    current_dir=$(pwd -P)
    echo "$current_dir" > "$last_file"

    # --tmux: 세션 모드 (tmux 밖에서만)
    if [[ "$use_tmux_session" == "true" ]] && [[ -z "${TMUX:-}" ]]; then
      local session_name
      session_name=$(_wt_session_name "$(basename "$last_path")")
      _wt_tmux_session_open "$last_path" "$session_name" "false" "false"
      return 0
    fi

    echo "$last_path"
    return 0
  fi

  if [[ -n "$search" ]]; then
    # substring 매치: 디렉토리명 + 브랜치명 + sanitized 검색어 모두 시도
    local sanitized_search
    sanitized_search=$(_sanitize_name "$search")
    for wt in "${worktrees[@]}"; do
      local name branch
      name=$(basename "$wt")
      branch=$(_wt_branch "$wt")
      if [[ "$name" == *"$search"* ]] || [[ "$name" == *"$sanitized_search"* ]] \
        || [[ "$branch" == *"$search"* ]]; then
        target_path="$wt"
        break
      fi
    done
    [[ -z "$target_path" ]] && _die "매치하는 worktree 없음: $search"
  else
    # 인터랙티브 선택 (fzf + preview)
    local names=()
    for wt in "${worktrees[@]}"; do
      names+=("$(basename "$wt")")
    done

    local selected
    if _has_fzf; then
      selected=$(printf '%s\n' "${names[@]}" | fzf --no-multi \
        --header "worktree 선택" --prompt "cd> " \
        --preview "git -C '$wt_base/{}' log --oneline -5 2>/dev/null; echo '---'; git -C '$wt_base/{}' status --short 2>/dev/null" \
        --preview-window right,75% --preview-label "worktree 상태") || return 1
    else
      echo "worktree 선택:" >&2
      local i=1
      for n in "${names[@]}"; do
        echo "  $i) $n" >&2
        ((i++))
      done
      printf "번호: " >&2
      local choice_num
      read -r choice_num
      if ! [[ "$choice_num" =~ ^[0-9]+$ ]] || (( choice_num < 1 || choice_num > ${#names[@]} )); then
        _die "잘못된 선택"
      fi
      selected="${names[$((choice_num - 1))]}"
    fi

    target_path="$wt_base/$selected"
  fi

  # 이전 worktree 경로 저장 (wt cd - 용)
  local current_dir
  current_dir=$(pwd -P)
  echo "$current_dir" > "$git_root/$WT_LAST_FILE"

  # --tmux: 세션 attach/생성 (tmux 밖에서만)
  if [[ "$use_tmux_session" == "true" ]] && [[ -z "${TMUX:-}" ]]; then
    local session_name
    session_name=$(_wt_session_name "$(basename "$target_path")")
    _wt_tmux_session_open "$target_path" "$session_name" "false" "false"
    return 0
  fi

  # tmux 안이면 윈도우 전환 시도
  if [[ -n "${TMUX:-}" ]]; then
    local window_id
    if window_id=$(_wt_find_tmux_window "$target_path"); then
      tmux select-window -t "$window_id"
      return 0
    fi
  fi

  # stdout으로 경로 출력 (래퍼 함수가 cd)
  echo "$target_path"
}

# ── 서브커맨드: ls ───────────────────────────────────────────────────────────

cmd_ls() {
  local git_root
  git_root=$(_get_repo_root) || _die "Git 저장소가 아닙니다"

  # worktree 수집
  local worktrees=()
  while IFS= read -r wt; do
    [[ -n "$wt" ]] && worktrees+=("$wt")
  done < <(_collect_worktrees "$git_root")

  if (( ${#worktrees[@]} == 0 )); then
    _info "활성 worktree가 없습니다"
    return 0
  fi

  # 현재 worktree 경로 (있으면)
  local current_wt=""
  local current_dir
  current_dir=$(pwd -P)
  for wt in "${worktrees[@]}"; do
    if [[ "$current_dir" == "$wt" || "$current_dir" == "$wt/"* ]]; then
      current_wt="$wt"
      break
    fi
  done

  # 임시 디렉토리 (PR 상태 병렬 조회)
  # global 변수: EXIT trap은 함수 종료 후 실행되므로 local은 set -u에서 unbound
  _wt_ls_tmp=$(mktemp -d)
  trap 'jobs -p | xargs -r kill 2>/dev/null || true; rm -rf "${_wt_ls_tmp:-}"' EXIT

  # PR 상태 병렬 조회
  _fetch_pr_statuses "$git_root" "$_wt_ls_tmp" "${worktrees[@]}"

  # 데이터 수집 + 정렬 (age 기준, 최신 우선)
  local entries=()
  for wt in "${worktrees[@]}"; do
    local name branch ts age pr_status dirty_mark current_mark
    name=$(basename "$wt")
    branch=$(_wt_branch "$wt")
    ts=$(_wt_last_commit_ts "$wt")
    age=$(_relative_age "$ts")

    pr_status="NONE"
    [[ -f "$_wt_ls_tmp/$name.pr" ]] && pr_status=$(cat "$_wt_ls_tmp/$name.pr")

    dirty_mark=""
    _wt_is_dirty "$wt" && dirty_mark="●"

    current_mark=""
    [[ "$wt" == "$current_wt" ]] && current_mark="*"

    # PR 상태 표시 (이모지 + 텍스트 통합)
    local pr_display
    case "$pr_status" in
      MERGED) pr_display="✅ MERGED" ;;
      OPEN)   pr_display="🔵 OPEN" ;;
      CLOSED) pr_display="🔴 CLOSED" ;;
      *)      pr_display="⚪ NONE" ;;
    esac

    # 현재 worktree 표시: name (*) 접미사
    local display_name="$name"
    [[ -n "$current_mark" ]] && display_name="$name (*)"

    # timestamp|name|branch|age|pr_display|dirty 형식으로 저장
    entries+=("$ts|$display_name|$branch|$age|$pr_display|$dirty_mark")
  done

  # age 기준 정렬 (최신 우선 = timestamp 내림차순)
  IFS=$'\n' read -r -d '' -a sorted < <(printf '%s\n' "${entries[@]}" | sort -t'|' -k1 -rn && printf '\0') || true

  # 출력
  if _has_gum; then
    local header="NAME,BRANCH,AGE,PR,DIRTY"
    local rows=""
    for entry in "${sorted[@]}"; do
      IFS='|' read -r _ name branch age pr dirty <<< "$entry"
      (( ${#branch} > 25 )) && branch="${branch:0:22}..."
      rows+="$name,$branch,$age,$pr,$dirty"$'\n'
    done
    gum style --bold --border double --padding "0 1" "Worktrees (${#sorted[@]})" >&2
    echo "${header}"$'\n'"${rows%$'\n'}" | gum table --print >&2
  else
    _info "Worktrees (${#sorted[@]})"
    printf "  %-30s %-25s %-5s %-12s %s\n" "NAME" "BRANCH" "AGE" "PR" "DIRTY" >&2
    printf "  " >&2; printf '%.0s─' {1..78} >&2; echo >&2
    for entry in "${sorted[@]}"; do
      IFS='|' read -r _ name branch age pr dirty <<< "$entry"
      (( ${#branch} > 25 )) && branch="${branch:0:22}..."
      printf "  %-30s %-25s %-5s %-12s %s\n" "$name" "$branch" "$age" "$pr" "$dirty" >&2
    done
  fi
}

# ── 서브커맨드: cleanup ──────────────────────────────────────────────────────

cmd_cleanup() {
  local auto=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --auto) auto=true ;;
      -h|--help) show_help; return 0 ;;
      *) _die "알 수 없는 옵션: $1" ;;
    esac
    shift
  done

  local git_root
  git_root=$(_get_repo_root) || _die "Git 저장소가 아닙니다"

  # worktree 수집
  local worktrees=()
  while IFS= read -r wt; do
    [[ -n "$wt" ]] && worktrees+=("$wt")
  done < <(_collect_worktrees "$git_root")

  if (( ${#worktrees[@]} == 0 )); then
    _info "정리할 worktree가 없습니다"
    return 0
  fi

  # 임시 디렉토리 (PR 상태 병렬 조회)
  # global 변수: EXIT trap은 함수 종료 후 실행되므로 local은 set -u에서 unbound
  _wt_cleanup_tmp=$(mktemp -d)
  trap 'jobs -p | xargs -r kill 2>/dev/null || true; rm -rf "${_wt_cleanup_tmp:-}"' EXIT

  # PR 상태 병렬 조회
  _fetch_pr_statuses "$git_root" "$_wt_cleanup_tmp" "${worktrees[@]}"

  # 현재 worktree 감지 (cleanup 목록에서 제외)
  local current_wt=""
  local current_dir
  current_dir=$(pwd -P)
  for wt in "${worktrees[@]}"; do
    if [[ "$current_dir" == "$wt" || "$current_dir" == "$wt/"* ]]; then
      current_wt="$wt"
      break
    fi
  done

  # 데이터 수집
  local items=()        # fzf 라벨
  local item_paths=()   # worktree 경로
  local item_branches=() # 브랜치명
  local item_pr=()      # PR 상태
  local item_dirty=()   # dirty 여부
  local item_unpushed=() # unpushed 여부
  local merged_indices=() # MERGED 항목 인덱스

  local idx=0
  for wt in "${worktrees[@]}"; do
    # 현재 worktree는 cleanup 대상에서 제외
    [[ "$wt" == "$current_wt" ]] && continue

    local name branch ts age pr_status dirty_flag unpushed_flag last_msg
    name=$(basename "$wt")
    branch=$(_wt_branch "$wt")
    ts=$(_wt_last_commit_ts "$wt")
    age=$(_relative_age "$ts")

    pr_status="NONE"
    [[ -f "$_wt_cleanup_tmp/$name.pr" ]] && pr_status=$(cat "$_wt_cleanup_tmp/$name.pr")

    dirty_flag=false
    _wt_is_dirty "$wt" && dirty_flag=true

    unpushed_flag=false
    _wt_has_unpushed "$wt" && unpushed_flag=true

    last_msg=$(_wt_last_commit_msg "$wt")

    # 상태 아이콘
    local st_icon
    case "$pr_status" in
      MERGED) st_icon="✅" ;;
      OPEN)   st_icon="🔵" ;;
      CLOSED) st_icon="🔴" ;;
      *)      st_icon="⚪" ;;
    esac

    local dirty_mark=""
    [[ "$dirty_flag" == "true" ]] && dirty_mark=" ●dirty"
    local unpushed_mark=""
    [[ "$unpushed_flag" == "true" ]] && unpushed_mark=" ↑unpushed"

    # 라벨: "ICON NAME [age PR dirty unpushed] — msg\tPATH"
    # fzf --with-nth 1로 라벨만 표시, --delimiter '\t'로 PATH 분리
    local label="$st_icon $name [$age $pr_status${dirty_mark}${unpushed_mark}] — $last_msg"

    items+=("$label")
    item_paths+=("$wt")
    item_branches+=("$branch")
    item_pr+=("$pr_status")
    item_dirty+=("$dirty_flag")
    item_unpushed+=("$unpushed_flag")

    [[ "$pr_status" == "MERGED" ]] && merged_indices+=("$idx")

    idx=$((idx + 1))
  done

  if [[ "$auto" == "true" ]]; then
    # --auto: MERGED 상태 자동 정리
    if (( ${#merged_indices[@]} == 0 )); then
      _info "자동 정리 대상 (MERGED)이 없습니다"
      return 0
    fi

    _info "자동 정리 대상: ${#merged_indices[@]}개 (MERGED)"
    for i in "${merged_indices[@]}"; do
      local wt_path="${item_paths[$i]}"
      local branch="${item_branches[$i]}"
      local name
      name=$(basename "$wt_path")

      # dirty → 스킵
      if [[ "${item_dirty[$i]}" == "true" ]]; then
        _info "스킵: $name (dirty 있음)"
        continue
      fi

      # unpushed 체크: upstream이 존재하는 경우에만 (merge 후 추가 커밋 보호)
      # upstream 삭제(GitHub auto-delete + git fetch -p) 시 false positive이므로 스킵
      if [[ "${item_unpushed[$i]}" == "true" ]]; then
        if git -C "$wt_path" rev-parse --abbrev-ref "@{upstream}" &>/dev/null; then
          _info "스킵: $name (merge 후 추가 커밋 있음)"
          continue
        fi
      fi

      _remove_worktree "$wt_path" "$branch" "$git_root" || _info "경고: $name 삭제 실패"
    done

    git worktree prune 2>/dev/null || true
    _info "자동 정리 완료"
    return 0
  fi

  # 인터랙티브 모드
  local selected_names=()

  if _has_fzf; then
    # fzf 멀티 선택 + preview
    # 라벨\t경로 형식으로 전달, --with-nth 1로 라벨만 표시
    local fzf_input=""
    for ((i=0; i<${#items[@]}; i++)); do
      fzf_input+="${items[$i]}"$'\t'"${item_paths[$i]}"$'\n'
    done

    local chosen
    chosen=$(printf '%s' "$fzf_input" | fzf --multi --delimiter $'\t' --with-nth 1 \
      --header "정리할 worktree 선택 (Tab 토글, Enter 확인)" \
      --prompt "cleanup> " \
      --preview 'git -C {2} log --oneline -5 2>/dev/null; echo "---"; git -C {2} status --short 2>/dev/null' \
      --preview-window right,75% --preview-label "worktree 상태") || { _info "취소됨"; return 0; }

    # 선택된 항목에서 worktree 이름 추출
    while IFS=$'\t' read -r label path; do
      [[ -n "$path" ]] && selected_names+=("$(basename "$path")")
    done <<< "$chosen"
  else
    # fallback: 번호 선택
    echo "정리할 worktree 선택 (쉼표로 구분, 빈 입력=취소):" >&2
    local i=1
    for label in "${items[@]}"; do
      echo "  $i) $label" >&2
      ((i++))
    done
    printf "번호: " >&2
    local nums_str
    read -r nums_str
    [[ -z "$nums_str" ]] && { _info "취소됨"; return 0; }

    IFS=',' read -ra nums <<< "$nums_str"
    for num in "${nums[@]}"; do
      num=$(echo "$num" | tr -d ' ')
      local idx=$((num - 1))
      if (( idx >= 0 && idx < ${#items[@]} )); then
        selected_names+=("$(basename "${item_paths[$idx]}")")
      fi
    done
  fi

  if (( ${#selected_names[@]} == 0 )); then
    _info "선택한 항목이 없습니다"
    return 0
  fi

  # 선택된 항목 처리
  local removed=0
  for sel_name in "${selected_names[@]}"; do
    local found_idx=-1
    for ((i=0; i<${#item_paths[@]}; i++)); do
      if [[ "$(basename "${item_paths[$i]}")" == "$sel_name" ]]; then
        found_idx=$i
        break
      fi
    done
    (( found_idx < 0 )) && continue

    local wt_path="${item_paths[$found_idx]}"
    local branch="${item_branches[$found_idx]}"
    local name
    name=$(basename "$wt_path")

    # dirty/unpushed → 개별 확인
    if [[ "${item_dirty[$found_idx]}" == "true" ]] || [[ "${item_unpushed[$found_idx]}" == "true" ]]; then
      local warn_msg="$name:"
      [[ "${item_dirty[$found_idx]}" == "true" ]] && warn_msg+=" uncommitted 변경사항"
      [[ "${item_unpushed[$found_idx]}" == "true" ]] && warn_msg+=" push하지 않은 커밋"

      _info "$warn_msg"
      _confirm "정말 삭제하시겠습니까?" || { _info "스킵: $name"; continue; }
    fi

    if _remove_worktree "$wt_path" "$branch" "$git_root"; then
      removed=$((removed + 1))
    fi
  done

  git worktree prune 2>/dev/null || true
  _info "정리 완료: ${removed}개 삭제"
}
