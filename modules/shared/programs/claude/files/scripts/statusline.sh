#!/usr/bin/env bash
# Claude Code custom statusline
#   plan 파일, status icons, cwd/branch/session-id, Cache TTL, rate limits 출력
#   stdin으로 JSON 세션 데이터를 받아 statusbar 내용을 stdout으로 출력
#
# 라인 구조 (3-way 분기):
#   L1: /set-icons (Jira/Slack/Figma/Memo) — 조건부, 미설정 시 라인 생략
#   L2:
#     - 비-git cwd: cwd + session-id (branch 생략)
#     - git main repo: cwd + branch + session-id
#     - git worktree: cwd 단독
#   L3 (worktree만): branch + session-id
#   L_M: Plan/Memory/Cache TTL + hit%
#   L_N: Rate Limits (5h/7d)

input=$(cat)

# ============================================================
# Helper: 입력 검증 + sanitize
# ============================================================

# URL 인자에 C0/DEL control 문자 포함 시 빈 문자열 반환 (universal sanitize)
sanitize_osc8_url() {
  local url=$1
  [ -z "$url" ] && return
  if printf '%s' "$url" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    return
  fi
  printf '%s' "$url"
}

# path segment 내부 공백/control/예약 문자만 percent-encode (`/` separator 유지)
percent_encode_segment() {
  local input=$1
  local i char hex
  local output=""
  local len=${#input}
  for (( i=0; i<len; i++ )); do
    char="${input:$i:1}"
    case "$char" in
      [a-zA-Z0-9._~/-])
        output+="$char"
        ;;
      *)
        printf -v hex '%%%02X' "'$char"
        output+="$hex"
        ;;
    esac
  done
  printf '%s' "$output"
}

# 디렉토리를 canonical absolute path로 변환. 미존재 시 빈 문자열
canonicalize_dir() {
  local dir=$1
  [ -z "$dir" ] && return
  (cd "$dir" 2>/dev/null && pwd -P) 2>/dev/null
}

# transcript_path validation (D-10: 진입 직후, file I/O 전체 신뢰 경계)
#   (a) 절대경로 (b) symlink 거부 (c) .jsonl 확장자
#   (d) dirname canonical 변환 + $HOME/.claude/projects/ canonical 경계 포함 prefix
#   (e) file canonical (realpath) 도 같은 root 하위
# 통과 시 canonical transcript dir 반환, 미통과 시 빈 문자열
validate_transcript_path() {
  local transcript=$1
  [ -z "$transcript" ] && return
  case "$transcript" in /*) ;; *) return ;; esac
  [ -L "$transcript" ] && return
  case "$transcript" in *.jsonl) ;; *) return ;; esac
  local dir canonical_dir canonical_root canonical_file
  dir=$(dirname "$transcript")
  canonical_dir=$(canonicalize_dir "$dir")
  [ -z "$canonical_dir" ] && return
  canonical_root=$(canonicalize_dir "$HOME/.claude/projects")
  [ -z "$canonical_root" ] && return
  case "$canonical_dir" in
    "$canonical_root"|"$canonical_root"/*) ;;
    *) return ;;
  esac
  # file 자체 realpath
  if command -v realpath >/dev/null 2>&1; then
    canonical_file=$(realpath "$transcript" 2>/dev/null)
  else
    canonical_file="$canonical_dir/$(basename "$transcript")"
  fi
  [ -z "$canonical_file" ] && return
  case "$canonical_file" in
    "$canonical_root"/*) ;;
    *) return ;;
  esac
  printf '%s' "$canonical_dir"
}

# session_id 패턴 검증 (UUID 또는 safe filename pattern)
# 통과: exit 0 / 실패: exit 1
validate_session_id() {
  local sid=$1
  [ -z "$sid" ] && return 1
  case "$sid" in
    *[!A-Za-z0-9._-]*) return 1 ;;
  esac
  return 0
}

# cwd validation (D-2 보강: 절대경로 + control 문자 없음 + canonical 디렉토리)
# 통과 시 canonical cwd 반환, 미통과 시 빈 문자열
canonicalize_cwd_check() {
  local cwd=$1
  [ -z "$cwd" ] && return
  case "$cwd" in /*) ;; *) return ;; esac
  if printf '%s' "$cwd" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    return
  fi
  canonicalize_dir "$cwd"
}

# $HOME 접두사를 `~`로 치환
tilde_shorten() {
  local p=$1
  if [ -n "$HOME" ] && [ "${p#"$HOME"}" != "$p" ]; then
    printf '~%s' "${p#"$HOME"}"
  else
    printf '%s' "$p"
  fi
}

# ============================================================
# Section 1: transcript_path 추출 + canonical validation (D-10 진입 직후)
# ============================================================

TRANSCRIPT=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null) || true
if [ -z "$TRANSCRIPT" ]; then
  exit 0
fi

CANONICAL_TRANSCRIPT_DIR=$(validate_transcript_path "$TRANSCRIPT")
TRANSCRIPT_VALID=false
if [ -n "$CANONICAL_TRANSCRIPT_DIR" ]; then
  TRANSCRIPT_VALID=true
fi

# ============================================================
# Section 2: session_id resolution (D-8)
#   Single resolution: stdin.session_id // basename(transcript .jsonl)
#   + pattern validation. statusline과 SessionStart hook 동일 resolution
# ============================================================

SESSION_ID=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || true
if [ -z "$SESSION_ID" ]; then
  SESSION_ID=$(basename "$TRANSCRIPT" .jsonl)
fi
if ! validate_session_id "$SESSION_ID"; then
  SESSION_ID=""
fi

SESSION_ID_SHORT=""
[ -n "$SESSION_ID" ] && SESSION_ID_SHORT="${SESSION_ID:0:8}"

# ============================================================
# Section 3: HEAVY cache setup (D-15: CACHED_CWD invalidate)
# ============================================================

NOW=$(date +%s)
HEAVY_CACHE_DIR="${XDG_RUNTIME_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/claude-statusline}"
mkdir -p "$HEAVY_CACHE_DIR"
HEAVY_STATE=""
[ -n "$SESSION_ID" ] && HEAVY_STATE="${HEAVY_CACHE_DIR}/heavy-${SESSION_ID}"
HEAVY_INTERVAL=10
DO_HEAVY=true

# cwd 추출 (DO_HEAVY 판정에 필요)
CWD=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || true
CWD=${CWD:-$PWD}

# Cached CWD 비교 → cwd 변경 시 timestamp 무관 DO_HEAVY=true
if [ -n "$HEAVY_STATE" ] && [ -f "$HEAVY_STATE" ]; then
  last_heavy=$(head -1 "$HEAVY_STATE" 2>/dev/null || echo 0)
  CACHED_CWD=""
  if [ -f "${HEAVY_STATE}.vars" ]; then
    eval "$(grep '^CACHED_CWD=' "${HEAVY_STATE}.vars" 2>/dev/null)" 2>/dev/null || true
  fi
  if [ "$CACHED_CWD" = "$CWD" ] && [ "$((NOW - last_heavy))" -lt "$HEAVY_INTERVAL" ]; then
    DO_HEAVY=false
  fi
fi

# ============================================================
# Section 4: SSH 감지
#   SSH 세션에서는 OSC 8 hyperlink 클릭 불가 → URL 비활성, 텍스트만
# ============================================================
IS_SSH=false
[ -n "$SSH_CONNECTION" ] && IS_SSH=true

CACHE_GUIDE_URL="https://github.com/greenheadHQ/nixos-config/blob/main/modules/shared/programs/claude/files/docs/cache-guide.md"
$IS_SSH && CACHE_GUIDE_URL=""

# 256-color 고정 그레이
MUTED="38;5;242"

# ============================================================
# Section 5: HEAVY 연산 (Plan/Memory/Cache TTL/Worktree/Branch)
# ============================================================
PLAN_FILE=""
MEMORY_LINK=""
MEMORY_LABEL=""
CACHE_TTL=300
IS_WORKTREE=false
GIT_BRANCH=""

if $DO_HEAVY; then

# -- Plan 파일 감지 (transcript valid 시에만)
PLAN_STATE_FILE=""
PROJECT_PLAN_STATE=""
if $TRANSCRIPT_VALID; then
  PLAN_STATE_FILE="$CANONICAL_TRANSCRIPT_DIR/.statusline-plan-${SESSION_ID:-unknown}"
  PROJECT_PLAN_STATE="$CANONICAL_TRANSCRIPT_DIR/.statusline-plan-current"
fi

if $TRANSCRIPT_VALID && [ -f "$TRANSCRIPT" ]; then
  # agent_progress 이벤트 제외, agent plan 파일명 제외
  PLAN_FILE=$(grep -v '"type":"agent_progress"' "$TRANSCRIPT" 2>/dev/null \
    | grep -oE '"(filePath|file_path|planFilePath)":"[^"]*\.claude/plans/[^"]*\.md"' \
    | grep -v 'plans/[^"]*-agent-' \
    | tail -1 | sed 's/^"[^"]*":"//;s/"$//')
fi

if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ] && [ -n "$PLAN_STATE_FILE" ]; then
  printf '%s' "$PLAN_FILE" > "$PLAN_STATE_FILE" 2>/dev/null
  [ -n "$PROJECT_PLAN_STATE" ] && printf '%s' "$PLAN_FILE" > "$PROJECT_PLAN_STATE" 2>/dev/null
elif [ -z "$PLAN_FILE" ] && [ -n "$PLAN_STATE_FILE" ] && [ -f "$PLAN_STATE_FILE" ]; then
  PLAN_FILE=$(cat "$PLAN_STATE_FILE" 2>/dev/null)
elif [ -z "$PLAN_FILE" ] && [ -n "$PROJECT_PLAN_STATE" ] && [ -f "$PROJECT_PLAN_STATE" ]; then
  ORIGINAL_PLAN=$(cat "$PROJECT_PLAN_STATE" 2>/dev/null)
  if [ -n "$ORIGINAL_PLAN" ] && [ -f "$ORIGINAL_PLAN" ]; then
    PLAN_COPY="$(dirname "$ORIGINAL_PLAN")/$(basename "$ORIGINAL_PLAN" .md)-${SESSION_ID:0:8}.md"
    if [ ! -f "$PLAN_COPY" ]; then
      cp "$ORIGINAL_PLAN" "$PLAN_COPY"
      find "$(dirname "$ORIGINAL_PLAN")" -name "*-????????.md" -mtime +30 -delete 2>/dev/null || true
    fi
    PLAN_FILE="$PLAN_COPY"
    [ -n "$PLAN_STATE_FILE" ] && printf '%s' "$PLAN_FILE" > "$PLAN_STATE_FILE" 2>/dev/null
  fi
fi

# -- Memory 감지 (canonical transcript dir 기반)
if $TRANSCRIPT_VALID; then
  PROJECT_MEMORY_DIR="$CANONICAL_TRANSCRIPT_DIR/memory"
  GLOBAL_MEMORY_DIR="$HOME/.claude/memory"
  MEMORY_COUNT=0
  MEMORY_INDEX=""

  # worktree 보정: canonical transcript dir에 memory/가 없으면 cwd → canonical git root
  if [ ! -d "$PROJECT_MEMORY_DIR" ] && [ -n "$CWD" ] && [ -d "$CWD" ]; then
    GIT_COMMON=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null) || true
    if [ -n "$GIT_COMMON" ]; then
      if [[ "$GIT_COMMON" != /* ]]; then
        GIT_DIR=$(git -C "$CWD" rev-parse --git-dir 2>/dev/null) || true
        if [ -n "$GIT_DIR" ]; then
          [[ "$GIT_DIR" != /* ]] && GIT_DIR="$CWD/$GIT_DIR"
          GIT_COMMON=$(cd "$GIT_DIR" && cd "$GIT_COMMON" && pwd 2>/dev/null) || true
        fi
      fi
      if [ -n "$GIT_COMMON" ]; then
        MAIN_REPO=$(dirname "$GIT_COMMON")
        ENCODED=$(echo "$MAIN_REPO" | sed 's/[^a-zA-Z0-9]/-/g')
        CANONICAL_MEMORY="$HOME/.claude/projects/$ENCODED/memory"
        [ -d "$CANONICAL_MEMORY" ] && PROJECT_MEMORY_DIR="$CANONICAL_MEMORY"
      fi
    fi
  fi

  if [ -d "$PROJECT_MEMORY_DIR" ]; then
    MEMORY_INDEX="$PROJECT_MEMORY_DIR/MEMORY.md"
    MEMORY_COUNT=$(find "$PROJECT_MEMORY_DIR" -maxdepth 1 -name "*.md" ! -name "MEMORY.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  fi

  if [ -d "$GLOBAL_MEMORY_DIR" ]; then
    GLOBAL_COUNT=$(find "$GLOBAL_MEMORY_DIR" -maxdepth 1 -name "*.md" ! -name "MEMORY.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    MEMORY_COUNT=$((MEMORY_COUNT + GLOBAL_COUNT))
    [ -z "$MEMORY_INDEX" ] && MEMORY_INDEX="$GLOBAL_MEMORY_DIR/MEMORY.md"
  fi

  if [ "$MEMORY_COUNT" -gt 0 ] && [ -n "$MEMORY_INDEX" ] && [ -f "$MEMORY_INDEX" ]; then
    REFERENCED=$(grep -cE '^[[:space:]]*-[[:space:]]*\[.*\.md\]' "$MEMORY_INDEX" 2>/dev/null) || REFERENCED=0
    MEMORY_WARN=""
    [ "$MEMORY_COUNT" -gt "$REFERENCED" ] && MEMORY_WARN=$'\xe2\x9a\xa0'
    MEMORY_LINK="file://$(dirname "$MEMORY_INDEX")"
    MEMORY_LABEL="Memory (${MEMORY_COUNT}${MEMORY_WARN})"
  fi
fi

# -- Cache TTL detection (기존 로직 유지, transcript valid 시에만)
if [ -f "${HEAVY_STATE}.vars" ]; then
  eval "$(grep '^CACHE_TTL=' "${HEAVY_STATE}.vars" 2>/dev/null)" 2>/dev/null || true
fi
if $TRANSCRIPT_VALID && [ -f "$TRANSCRIPT" ]; then
  _detected=$(jq -r '
    select(.message.usage.cache_creation)
    | if .message.usage.cache_creation.ephemeral_1h_input_tokens > 0 then "3600"
      elif .message.usage.cache_creation.ephemeral_5m_input_tokens > 0 then "300"
      else empty end
  ' "$TRANSCRIPT" 2>/dev/null | tail -1)
  [ -n "$_detected" ] && CACHE_TTL="$_detected"
fi

# -- Worktree detection (D-14)
#    Primary: stdin.workspace.git_worktree (linked worktree에만 제공)
#    Fallback: git rev-parse --path-format=absolute --git-dir/--git-common-dir
WS_WORKTREE=$(printf '%s' "$input" | jq -r '.workspace.git_worktree // empty' 2>/dev/null) || true
if [ -n "$WS_WORKTREE" ]; then
  IS_WORKTREE=true
elif [ -d "$CWD" ]; then
  GIT_DIR_ABS=$(git -C "$CWD" rev-parse --path-format=absolute --git-dir 2>/dev/null) || true
  GIT_COMMON_ABS=$(git -C "$CWD" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || true
  if [ -n "$GIT_DIR_ABS" ] && [ -n "$GIT_COMMON_ABS" ] && [ "$GIT_DIR_ABS" != "$GIT_COMMON_ABS" ]; then
    IS_WORKTREE=true
  fi
fi

# -- Branch 추출 (D-14: worktree.branch || git branch --show-current)
GIT_BRANCH=$(printf '%s' "$input" | jq -r '.worktree.branch // empty' 2>/dev/null) || true
if [ -z "$GIT_BRANCH" ] && [ -d "$CWD" ]; then
  GIT_BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null) || true
fi

# -- Heavy 결과 저장 (D-15: CACHED_CWD 포함)
printf 'PLAN_FILE=%q\nMEMORY_LINK=%q\nMEMORY_LABEL=%q\nCACHE_TTL=%q\nIS_WORKTREE=%q\nGIT_BRANCH=%q\nCACHED_CWD=%q\n' \
  "$PLAN_FILE" "$MEMORY_LINK" "$MEMORY_LABEL" "$CACHE_TTL" "$IS_WORKTREE" "$GIT_BRANCH" "$CWD" \
  > "${HEAVY_STATE}.vars"
echo "$NOW" > "$HEAVY_STATE"

else
  # Light run: 캐시된 변수 복원
  # shellcheck source=/dev/null
  source "${HEAVY_STATE}.vars" 2>/dev/null || true
  # bash bool 변수 복원 (eval 결과 string이라 '$IS_WORKTREE' 평가가 문자열일 수 있음)
  [ "$IS_WORKTREE" = "true" ] && IS_WORKTREE=true || IS_WORKTREE=false
fi

# CLAUDE_CACHE_TTL override
if [ -n "${CLAUDE_CACHE_TTL:-}" ] && [ "$CLAUDE_CACHE_TTL" -gt 0 ] 2>/dev/null; then
  CACHE_TTL=$CLAUDE_CACHE_TTL
fi

# ============================================================
# Section 6: Status icons 읽기 (Jira/Slack/Figma/Memo)
#   SESSION_ID 검증 통과 시에만 sidecar I/O
# ============================================================
ICONS_FILE=""
[ -n "$SESSION_ID" ] && ICONS_FILE="$HOME/.claude/status-icons/$SESSION_ID.json"

JIRA_URL="" JIRA_LABEL=""
SLACK_URL="" SLACK_LABEL=""
FIGMA_URL="" FIGMA_LABEL=""
MEMO_PATH="" MEMO_LABEL=""

if [ -n "$ICONS_FILE" ] && [ -f "$ICONS_FILE" ] && command -v jq >/dev/null 2>&1; then
  eval "$(jq -r '
    @sh "JIRA_URL=\(.jira.url // "")",
    @sh "JIRA_LABEL=\(.jira.label // "")",
    @sh "SLACK_URL=\(.slack.url // "")",
    @sh "SLACK_LABEL=\(.slack.label // "")",
    @sh "FIGMA_URL=\(.figma.url // "")",
    @sh "FIGMA_LABEL=\(.figma.label // "")",
    @sh "MEMO_PATH=\(.memo.path // "")",
    @sh "MEMO_LABEL=\(.memo.label // "")"
  ' "$ICONS_FILE" 2>/dev/null)" 2>/dev/null || true
fi

# ============================================================
# Section 7: Rate Limits + cache hit %
# ============================================================
RATE_5H="" RATE_5H_RESET=""
RATE_7D="" RATE_7D_RESET=""
CACHE_READ=0
CACHE_CREATE=0

if command -v jq >/dev/null 2>&1; then
  eval "$(printf '%s' "$input" | jq -r '
    @sh "RATE_5H=\(.rate_limits.five_hour.used_percentage // "")",
    @sh "RATE_5H_RESET=\(.rate_limits.five_hour.resets_at // "")",
    @sh "RATE_7D=\(.rate_limits.seven_day.used_percentage // "")",
    @sh "RATE_7D_RESET=\(.rate_limits.seven_day.resets_at // "")",
    @sh "CACHE_READ=\(.context_window.current_usage.cache_read_input_tokens // 0)",
    @sh "CACHE_CREATE=\(.context_window.current_usage.cache_creation_input_tokens // 0)"
  ' 2>/dev/null)" 2>/dev/null || true
fi

CACHE_HIT_PCT=""
_cache_total=$((${CACHE_READ:-0} + ${CACHE_CREATE:-0}))
if [ "$_cache_total" -gt 0 ] 2>/dev/null; then
  CACHE_HIT_PCT=$((${CACHE_READ:-0} * 100 / _cache_total))
fi

# ============================================================
# Section 8: 폭/임계값 + display values (D-5: 정적 threshold)
# ============================================================

COLS=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
[ "${COLS:-0}" -gt 0 ] 2>/dev/null || COLS=80
if [ "$COLS" -lt 80 ]; then
  EFF_COLS=$COLS
else
  EFF_COLS=$((COLS - 40))
fi

# session-id display: EFF_COLS >= 100 ? full : short
SESSION_ID_DISPLAY=""
if [ -n "$SESSION_ID" ]; then
  if [ "$EFF_COLS" -ge 100 ] 2>/dev/null; then
    SESSION_ID_DISPLAY="$SESSION_ID"
  else
    SESSION_ID_DISPLAY="$SESSION_ID_SHORT"
  fi
fi

# cwd canonical 검증 + display + URL
CWD_CANONICAL=$(canonicalize_cwd_check "$CWD")
if [ -n "$CWD_CANONICAL" ]; then
  CWD_DISPLAY=$(tilde_shorten "$CWD_CANONICAL")
  CWD_URL=""
  if ! $IS_SSH; then
    CWD_URL_PATH=$(percent_encode_segment "$CWD_CANONICAL")
    CWD_URL="vscode://file${CWD_URL_PATH}/"
  fi
else
  # 검증 실패: 텍스트만 표시
  CWD_DISPLAY=$(tilde_shorten "$CWD")
  CWD_URL=""
fi

# session-id URL: transcript valid + SSH 아닐 때만
SESSION_URL=""
if [ -n "$SESSION_ID_DISPLAY" ] && $TRANSCRIPT_VALID && ! $IS_SSH; then
  SESSION_URL_PATH=$(percent_encode_segment "$CANONICAL_TRANSCRIPT_DIR")
  SESSION_URL="file://${SESSION_URL_PATH}"
fi

# ============================================================
# Section 9: Render helpers (D-11: 라인별 상태 격리)
# ============================================================

LINE_HAS_OUTPUT=false

begin_line() {
  LINE_HAS_OUTPUT=false
}

end_line() {
  $LINE_HAS_OUTPUT && printf '\n'
}

# print_icon: 아이콘 + 라벨 + 선택적 OSC 8 hyperlink 출력
#   D-9: URL 인자는 universal sanitize 후 %s로 출력 (escape 문자 분리)
#   $1=ansi_color $2=url $3=emoji_bytes $4=label
print_icon() {
  local color=$1
  local url=$2
  local emoji=$3
  local label=$4
  url=$(sanitize_osc8_url "$url")
  $LINE_HAS_OUTPUT && printf '  '
  if [ -n "$url" ]; then
    # OSC 8 hyperlink: escape sequence는 %b, URL은 %s, label은 %s
    printf '%b' "\e[4;${color}m\e]8;;"
    printf '%s' "$url"
    printf '%b' "\a${emoji} "
    printf '%s' "$label"
    printf '%b' "\e]8;;\a\e[0m"
  else
    printf '%b' "\e[${color}m${emoji} "
    printf '%s' "$label"
    printf '%b' "\e[0m"
  fi
  LINE_HAS_OUTPUT=true
}

# 캐시 히트율 suffix (render_cache_ttl 내부 호출)
_render_cache_hit() {
  [ -z "$CACHE_HIT_PCT" ] && return
  local sym color
  if [ "$CACHE_HIT_PCT" -ge 80 ] 2>/dev/null; then
    sym=$'\xe2\x9c\x93'; color="32"
  elif [ "$CACHE_HIT_PCT" -ge 50 ] 2>/dev/null; then
    sym=$'\xe2\x96\xb3'; color="33"
  else
    sym=$'\xe2\x9c\x97'; color="31"
  fi
  printf ' %b' "\e[${color}m${sym}"
  printf '%s%%' "$CACHE_HIT_PCT"
  printf '%b' "\e[0m"
}

# Cache TTL 렌더 + hit% suffix
render_cache_ttl() {
  local remaining=$1
  if [ "$remaining" -le 0 ]; then
    print_icon "$MUTED" "$CACHE_GUIDE_URL" "\xf0\x9f\x92\xa4" "expired"
    _render_cache_hit
    return
  fi
  local minutes=$((remaining / 60))
  local seconds=$((remaining % 60))
  local cache_label
  cache_label=$(printf '%d:%02d' "$minutes" "$seconds")
  local green_th=$((CACHE_TTL * 40 / 100))
  local yellow_th=$((CACHE_TTL * 20 / 100))
  local cache_color
  if [ "$remaining" -ge "$green_th" ]; then cache_color="32"
  elif [ "$remaining" -ge "$yellow_th" ]; then cache_color="33"
  else cache_color="31"
  fi
  print_icon "$cache_color" "$CACHE_GUIDE_URL" "\xe2\x8f\xb1\xef\xb8\x8f" "$cache_label"
  _render_cache_hit
}

rate_color() {
  if [ "${1:-0}" -ge 80 ] 2>/dev/null; then echo "31"
  elif [ "${1:-0}" -ge 50 ] 2>/dev/null; then echo "33"
  else echo "32"
  fi
}

format_remaining() {
  local secs=${1:-0}
  if [ "$secs" -le 0 ] 2>/dev/null; then echo "0m"; return; fi
  local d=$((secs / 86400)) h=$(((secs % 86400) / 3600)) m=$(((secs % 3600) / 60))
  if [ "$d" -gt 0 ]; then printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%dh%02dm' "$h" "$m"
  else printf '%dm' "$m"
  fi
}

render_rate_window() {
  local pct=${1:-0} window=$2 resets_at=$3 now=$4 detail=${5:-4}
  pct=${pct%%.*}
  pct=${pct:-0}
  [ "$pct" -lt 0 ] 2>/dev/null && pct=0
  [ "$pct" -gt 100 ] 2>/dev/null && pct=100
  local color
  color=$(rate_color "$pct")

  if [ "$detail" -ge 2 ]; then
    local filled=$((pct / 10)) empty
    [ "$pct" -gt 0 ] 2>/dev/null && [ "$filled" -eq 0 ] && filled=1
    empty=$((10 - filled))
    local i bar_filled="" bar_empty=""
    for ((i=0; i<filled; i++)); do bar_filled+="█"; done
    for ((i=0; i<empty; i++)); do bar_empty+="░"; done
    printf '%b%s%b%s%b ' "\e[${color}m" "$bar_filled" "\e[${MUTED}m" "$bar_empty" "\e[0m"
  fi

  printf '%b%s%b %s' "\e[${color}m" "${pct}%" "\e[0m" "$window"

  if [ -n "$resets_at" ] && [ "$resets_at" -gt 0 ] 2>/dev/null; then
    if [ "$detail" -ge 3 ]; then
      local remaining=$((resets_at - now))
      if [ "$remaining" -gt 0 ]; then
        printf ' %b%s%b %s' "\e[${MUTED}m" "→" "\e[0m" "$(format_remaining "$remaining")"
      fi
    fi
    if [ "$detail" -ge 4 ]; then
      local reset_fmt
      reset_fmt=$(date -r "$resets_at" "+%m/%d %H:%M" 2>/dev/null \
               || date -d "@$resets_at" "+%m/%d %H:%M" 2>/dev/null)
      [ -n "$reset_fmt" ] && printf ' %b(%s)%b' "\e[${MUTED}m" "$reset_fmt" "\e[0m"
    fi
  fi
}

# ============================================================
# Output: 라인별 출력 (D-13: render_line 헬퍼만, context_lines 추상화 없음)
# ============================================================

# L1: /set-icons (Jira → Slack → Figma → Memo) — 조건부 라인
begin_line
if [ -n "$JIRA_URL" ] && [ -n "$JIRA_LABEL" ] && ! $IS_SSH; then
  print_icon "33" "$JIRA_URL" "\xe2\x9a\xa1" "$JIRA_LABEL"
fi
if [ -n "$SLACK_URL" ] && [ -n "$SLACK_LABEL" ] && ! $IS_SSH; then
  print_icon "35" "$SLACK_URL" "\xf0\x9f\x92\xac" "$SLACK_LABEL"
fi
if [ -n "$FIGMA_URL" ] && [ -n "$FIGMA_LABEL" ] && ! $IS_SSH; then
  print_icon "31" "$FIGMA_URL" "\xf0\x9f\x8e\xa8" "$FIGMA_LABEL"
fi
if [ -n "$MEMO_PATH" ] && [ -f "$MEMO_PATH" ]; then
  MEMO_URL="file://${MEMO_PATH}"; $IS_SSH && MEMO_URL=""
  print_icon "32" "$MEMO_URL" "\xf0\x9f\x93\x93" "${MEMO_LABEL:-Memo}"
fi
end_line

# L2: cwd + (워크트리가 아니면 branch + session-id 같은 라인)
begin_line
if [ -n "$CWD_DISPLAY" ]; then
  # cwd 아이콘: 📁 (folder)
  print_icon "36" "$CWD_URL" "\xf0\x9f\x93\x81" "$CWD_DISPLAY"
fi
if ! $IS_WORKTREE; then
  if [ -n "$GIT_BRANCH" ]; then
    # branch 아이콘: 🌿 (no link)
    print_icon "32" "" "\xf0\x9f\x8c\xbf" "$GIT_BRANCH"
  fi
  if [ -n "$SESSION_ID_DISPLAY" ]; then
    # session-id 아이콘: 🆔
    print_icon "34" "$SESSION_URL" "\xf0\x9f\x86\x94" "$SESSION_ID_DISPLAY"
  fi
fi
end_line

# L3 (worktree만): branch + session-id
if $IS_WORKTREE; then
  begin_line
  if [ -n "$GIT_BRANCH" ]; then
    print_icon "32" "" "\xf0\x9f\x8c\xbf" "$GIT_BRANCH"
  fi
  if [ -n "$SESSION_ID_DISPLAY" ]; then
    print_icon "34" "$SESSION_URL" "\xf0\x9f\x86\x94" "$SESSION_ID_DISPLAY"
  fi
  end_line
fi

# L_M: Plan/Memory/Cache TTL + hit%
begin_line
if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
  PLAN_URL="file://${PLAN_FILE}"; $IS_SSH && PLAN_URL=""
  print_icon "36" "$PLAN_URL" "\xf0\x9f\x93\x9d" "Plan"
fi
if [ -n "$MEMORY_LINK" ]; then
  MEMORY_URL="$MEMORY_LINK"; $IS_SSH && MEMORY_URL=""
  print_icon "34" "$MEMORY_URL" "\xf0\x9f\xa7\xa0" "$MEMORY_LABEL"
fi

# Cache TTL (기존 로직 유지, SESSION_ID 검증 통과 시에만)
CACHE_TTL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/claude-hooks"
LAST_STOP_FILE=""
[ -n "$SESSION_ID" ] && LAST_STOP_FILE="${CACHE_TTL_DIR}/last-stop-${SESSION_ID}"
if [ -n "$LAST_STOP_FILE" ] && [ -f "$LAST_STOP_FILE" ]; then
  last_stop=$(cat "$LAST_STOP_FILE" 2>/dev/null)
  if [ -n "$last_stop" ] 2>/dev/null; then
    if [ "$last_stop" = "0" ]; then
      file_mtime=$(stat -c %Y "$LAST_STOP_FILE" 2>/dev/null \
                || stat -f %m "$LAST_STOP_FILE" 2>/dev/null || echo 0)
      elapsed=$((NOW - file_mtime))
      remaining=$((CACHE_TTL - elapsed))
      render_cache_ttl "$remaining"
    elif [ "$last_stop" -gt 0 ] 2>/dev/null; then
      elapsed=$((NOW - last_stop))
      remaining=$((CACHE_TTL - elapsed))
      render_cache_ttl "$remaining"
    fi
  fi
fi
end_line

# L_N: Rate Limits (5h/7d) — 폭에 따라 progressive disclosure
if [ -n "$RATE_5H" ] || [ -n "$RATE_7D" ]; then
  if   [ "$EFF_COLS" -ge 88 ]; then RATE_DETAIL=4
  elif [ "$EFF_COLS" -ge 58 ]; then RATE_DETAIL=3
  elif [ "$EFF_COLS" -ge 40 ]; then RATE_DETAIL=2
  else RATE_DETAIL=1
  fi

  if [ -n "$RATE_5H" ]; then
    render_rate_window "$RATE_5H" "5h" "$RATE_5H_RESET" "$NOW" "$RATE_DETAIL"
  fi
  if [ -n "$RATE_5H" ] && [ -n "$RATE_7D" ]; then
    printf ' %b%s%b ' "\e[${MUTED}m" "|" "\e[0m"
  fi
  if [ -n "$RATE_7D" ]; then
    render_rate_window "$RATE_7D" "7d" "$RATE_7D_RESET" "$NOW" "$RATE_DETAIL"
  fi
  printf '\n'
fi
