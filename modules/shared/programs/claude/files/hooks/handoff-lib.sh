#!/usr/bin/env bash
# handoff-lib.sh — Session handoff automation 공통 helper.
#
# 본 helper는 Claude Code (~/.claude/hooks/handoff-lib.sh)와 Codex CLI
# (~/.codex/hooks/handoff-lib.sh) 양쪽에서 source된다. epic #584 Codex 사본 정책에 따라
# 양쪽이 별도 file이지만 동일 content를 유지한다 — drift는 tests/test-handoff-hooks.sh
# 의 fixture가 검증한다 (DEC-S9 G2 + sourced helper).
#
# 환경변수 (Phase 1 Discovery에서 결정):
#   HANDOFF_IDLE_TIMEOUT_SECONDS  (default 300) — transcript_path mtime 기반 idle 임계
#   HANDOFF_TURN_THRESHOLD        (default 20)  — turn-counter 임계 (외부 state file 누적)
#
# Public API:
#   handoff_compute_slug <raw_branch>            -> stdout: <slug>-<hash>
#   handoff_redact <input>                       -> stdout: redacted (이메일/전화/주민번호/$HOME/env-var)
#   handoff_increment_turn <session_id>          -> stdout: turn count
#   handoff_should_trigger_full <session_id> <transcript_path?> -> 0(trigger) / 1(skip)
#   handoff_compute_diff <file>                  -> stdout: noise-excluded diff (empty if idempotent)
#   handoff_run_gitleaks <staged_path>           -> 0/1 (실패 시 staged unstage + working tree quarantine)
#   handoff_write_snapshot <slug> <branch> <branch_hash> <last_commit> <runtime> [issue_ref] [prd_link] -> stdout: target path

# 본 file은 source되어 호출되므로 set -euo pipefail은 호출 측 entrypoint에서 적용한다.

: "${HANDOFF_IDLE_TIMEOUT_SECONDS:=300}"
: "${HANDOFF_TURN_THRESHOLD:=20}"

# noise field SoT (DEC-S15) — idempotent diff 비교에서 제외할 frontmatter 필드.
HANDOFF_NOISE_FIELDS=("last-updated" "session-id" "cwd" "hostname")

# slug + hash 생성. raw branch가 비거나 정규화 후 빈 slug면 hard fail.
handoff_compute_slug() {
  local raw="${1:-}"
  if [ -z "$raw" ]; then
    printf 'handoff: empty raw branch\n' >&2
    return 2
  fi
  # raw input safety: path traversal 후보 + 절대경로 prefix 차단 (정규화 후 합법 slug가 되더라도 raw 의도 차단)
  case "$raw" in
    *..*)
      printf 'handoff: raw branch traversal candidate=%s\n' "$raw" >&2
      return 2
      ;;
    /*|\\*)
      printf 'handoff: raw branch absolute prefix=%s\n' "$raw" >&2
      return 2
      ;;
  esac
  # 정규화: lowercase + slash → -, [^a-z0-9-] → -, 연속 - 정리, 양 끝 trim
  local slug
  slug=$(printf '%s' "$raw" \
    | tr 'A-Z' 'a-z' \
    | tr '/' '-' \
    | sed -E 's/[^a-z0-9-]+/-/g' \
    | sed -E 's/-+/-/g; s/^-+//; s/-+$//')
  if [ -z "$slug" ]; then
    printf 'handoff: empty slug for branch=%s\n' "$raw" >&2
    return 2
  fi
  case "$slug" in
    .|..|*..*|.git|.git*)
      printf 'handoff: invalid slug=%s\n' "$slug" >&2
      return 2
      ;;
  esac
  local hash
  if command -v sha1sum >/dev/null 2>&1; then
    hash=$(printf '%s' "$raw" | sha1sum | head -c 6)
  else
    hash=$(printf '%s' "$raw" | shasum | head -c 6)
  fi
  if [ -z "$hash" ]; then
    printf 'handoff: hash compute failure\n' >&2
    return 2
  fi
  printf '%s-%s\n' "$slug" "$hash"
}

# PII + secret redaction. handoff allowlist를 통과한 텍스트라도 추가 redaction layer로 잔존
# 패턴을 제거한다. 본 redaction은 gitleaks staged scan(Layer 2)/lefthook pre-commit gitleaks
# (Layer 3) 보다 앞서는 Layer 1이며, 세 layer는 defense-in-depth다.
handoff_redact() {
  local input="${1:-}"
  if [ -z "$input" ]; then
    printf '%s' ""
    return 0
  fi
  local out="$input"
  # 이메일
  out=$(printf '%s' "$out" | sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/<email-redacted>/g')
  # 한국 전화번호 (010-NNNN-NNNN, 011/016/017/018/019)
  out=$(printf '%s' "$out" | sed -E 's/(010|011|016|017|018|019)[-]?[0-9]{3,4}[-]?[0-9]{4}/<phone-redacted>/g')
  # 주민번호 (NNNNNN-NNNNNNN)
  out=$(printf '%s' "$out" | sed -E 's/[0-9]{6}-[0-9]{7}/<rrn-redacted>/g')
  # GitHub Personal Access Token (ghp_/gho_/ghu_/ghs_/ghr_ + 36자 base62)
  out=$(printf '%s' "$out" | sed -E 's/gh[pousr]_[A-Za-z0-9]{36,}/<github-token-redacted>/g')
  # OpenAI API 키 (sk-... 추정 패턴: 'sk-' + 20자+)
  out=$(printf '%s' "$out" | sed -E 's/\bsk-[A-Za-z0-9_-]{20,}/<openai-key-redacted>/g')
  # AWS access key ID (AKIA + 16자 대문자/숫자)
  out=$(printf '%s' "$out" | sed -E 's/\bAKIA[0-9A-Z]{16}\b/<aws-access-key-redacted>/g')
  # Stripe live/secret key (sk_live_ / rk_live_ + 24자+)
  out=$(printf '%s' "$out" | sed -E 's/\b(sk|rk)_(live|test)_[A-Za-z0-9]{24,}/<stripe-key-redacted>/g')
  # JWT (eyJ로 시작하는 base64url . base64url . base64url)
  out=$(printf '%s' "$out" | sed -E 's/\beyJ[A-Za-z0-9_=-]{10,}\.eyJ[A-Za-z0-9_=-]{10,}\.[A-Za-z0-9_=-]{10,}/<jwt-redacted>/g')
  # $HOME 절대경로 → ~
  if [ -n "${HOME:-}" ]; then
    out=$(printf '%s' "$out" | sed "s|${HOME}|~|g")
  fi
  # env var 값 (TOKEN/KEY/SECRET/PASSWORD/API_KEY/ACCESS_KEY/AUTH 변수 = 값)
  out=$(printf '%s' "$out" | sed -E 's/(TOKEN|API_KEY|SECRET|PASSWORD|ACCESS_KEY|AUTH_TOKEN|BEARER)[ \t]*=[ \t]*[^[:space:]]+/\1=<redacted>/g')
  printf '%s' "$out"
}

# turn count 증가 (외부 state file 누적). DEC-S6 B refined.
handoff_increment_turn() {
  local session_id="${1:-}"
  local datadir="${XDG_DATA_HOME:-$HOME/.local/share}/claude-hooks"
  mkdir -p "$datadir" 2>/dev/null || true
  if [ -z "$session_id" ]; then
    session_id="global"
  fi
  local cnt_file="$datadir/handoff-turn-count-${session_id}"
  local cnt=0
  if [ -f "$cnt_file" ]; then
    cnt=$(cat "$cnt_file" 2>/dev/null || printf '0')
    case "$cnt" in
      ''|*[!0-9]*) cnt=0 ;;
    esac
  fi
  cnt=$((cnt + 1))
  printf '%d' "$cnt" > "$cnt_file" 2>/dev/null || true
  printf '%d\n' "$cnt"
}

# turn count reset (full snapshot trigger 후 호출).
handoff_reset_turn() {
  local session_id="${1:-}"
  local datadir="${XDG_DATA_HOME:-$HOME/.local/share}/claude-hooks"
  if [ -z "$session_id" ]; then
    session_id="global"
  fi
  rm -f -- "$datadir/handoff-turn-count-${session_id}" 2>/dev/null || true
}

# turn-counter + transcript_path mtime 결합 trigger.
# 0 = trigger (full snapshot 필요), 1 = skip (metadata-only).
handoff_should_trigger_full() {
  local session_id="${1:-}"
  local transcript_path="${2:-}"
  local cnt
  cnt=$(handoff_increment_turn "$session_id")
  if [ "$cnt" -ge "$HANDOFF_TURN_THRESHOLD" ]; then
    return 0
  fi
  if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    local mtime now diff
    # GNU stat (Linux) → -c %Y; BSD stat (macOS) → -f %m
    mtime=$(stat -c %Y "$transcript_path" 2>/dev/null \
      || /usr/bin/stat -f %m "$transcript_path" 2>/dev/null \
      || printf '0')
    now=$(date +%s)
    diff=$((now - mtime))
    if [ "$diff" -ge "$HANDOFF_IDLE_TIMEOUT_SECONDS" ]; then
      return 0
    fi
  fi
  return 1
}

# noise field 제외한 idempotent diff. 변경 없으면 empty stdout.
handoff_compute_diff() {
  local file="${1:-}"
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    return 0
  fi
  local diff_raw
  diff_raw=$(git diff --no-color -- "$file" 2>/dev/null || printf '')
  if [ -z "$diff_raw" ]; then
    return 0
  fi
  local pattern=""
  local f
  for f in "${HANDOFF_NOISE_FIELDS[@]}"; do
    if [ -n "$pattern" ]; then
      pattern+="|"
    fi
    pattern+="^[+-]${f}:"
  done
  local non_noise
  non_noise=$(printf '%s\n' "$diff_raw" \
    | grep -E '^[+-]' \
    | grep -v '^\(+++ \|--- \)' \
    | { if [ -n "$pattern" ]; then grep -Ev "$pattern"; else cat; fi; } \
    || true)
  printf '%s' "$non_noise"
}

# gitleaks staged scan. 미설치 또는 scan 실패 시 staged unstage + working tree quarantine.
# 0 = pass, 1 = fail (commit 차단 + non-blocking exit 0은 호출 측 책임).
handoff_run_gitleaks() {
  local staged_path="${1:-}"
  if [ -z "$staged_path" ]; then
    printf 'handoff: missing staged_path arg\n' >&2
    return 1
  fi
  # 본 helper는 PATH 조작 환경(test의 미설치 시뮬레이션 포함)에서도 안전하게 동작하기 위해
  # git/rm 같은 핵심 명령을 절대경로로 resolve한다. handoff_resolve_bin이 PATH 우선 + fallback.
  local git_bin rm_bin
  git_bin=$(handoff_resolve_bin git)
  rm_bin=$(handoff_resolve_bin rm)
  if [ -z "$git_bin" ] || [ -z "$rm_bin" ]; then
    # core tool 자체가 없으면 quarantine 시도 자체 불가 — 호출 측 책임 (commit 미발생만 보장).
    printf 'handoff: core tool missing — commit 차단\n' >&2
    return 1
  fi
  if ! command -v gitleaks >/dev/null 2>&1; then
    printf 'handoff: gitleaks 미설치 — commit 차단 + quarantine\n' >&2
    "$git_bin" restore --staged -- "$staged_path" 2>/dev/null || true
    "$rm_bin" -f -- "$staged_path" 2>/dev/null || true
    return 1
  fi
  if ! gitleaks protect --staged --no-banner --redact >/dev/null 2>&1; then
    printf 'handoff: gitleaks scan 차단 — unstage + quarantine\n' >&2
    "$git_bin" restore --staged -- "$staged_path" 2>/dev/null || true
    "$rm_bin" -f -- "$staged_path" 2>/dev/null || true
    return 1
  fi
  return 0
}

# 핵심 tool resolve helper — PATH 우선, 미발견 시 일반적 system path fallback.
handoff_resolve_bin() {
  local name="${1:-}"
  if [ -z "$name" ]; then
    return 1
  fi
  local found
  found=$(command -v -- "$name" 2>/dev/null || printf '')
  if [ -n "$found" ]; then
    printf '%s' "$found"
    return 0
  fi
  local p
  for p in /usr/bin /bin /usr/local/bin /run/current-system/sw/bin; do
    if [ -x "$p/$name" ]; then
      printf '%s/%s' "$p" "$name"
      return 0
    fi
  done
  return 1
}

# snapshot 파일 작성. allowlist 필드만 (DEC-S12) + redaction.
# stdout: target file path.
# args: <slug> <branch> <branch_hash> <last_commit> <runtime> [issue_ref] [prd_link]
handoff_write_snapshot() {
  local slug="${1:-}"
  local branch="${2:-}"
  local branch_hash="${3:-}"
  local last_commit="${4:-}"
  local runtime="${5:-unknown}"
  local issue_ref="${6:-}"
  local prd_link="${7:-}"
  if [ -z "$slug" ] || [ -z "$branch" ]; then
    printf 'handoff: write_snapshot missing slug or branch\n' >&2
    return 2
  fi
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || printf '')
  if [ -z "$repo_root" ]; then
    printf 'handoff: not inside a git repo\n' >&2
    return 2
  fi
  local target_dir="${repo_root}/.claude/handoffs"
  mkdir -p "$target_dir"
  local target="${target_dir}/${slug}.md"
  local now session_id cwd_redacted host
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  session_id="${HANDOFF_SESSION_ID:-}"
  cwd_redacted=$(handoff_redact "$PWD")
  host=$(hostname -s 2>/dev/null || printf 'unknown')
  local summary pending active_files next_action
  summary=$(handoff_redact "${HANDOFF_SUMMARY:-}")
  pending=$(handoff_redact "${HANDOFF_PENDING_DECISIONS:-}")
  active_files=$(handoff_redact "${HANDOFF_ACTIVE_FILES:-}")
  next_action=$(handoff_redact "${HANDOFF_NEXT_ACTION:-}")
  umask 077
  {
    printf -- '---\n'
    printf 'branch: %s\n' "$branch"
    printf 'branch-hash: %s\n' "$branch_hash"
    printf 'last-commit: %s\n' "$last_commit"
    printf 'runtime: %s\n' "$runtime"
    printf "issue-ref: '%s'\n" "$issue_ref"
    printf "prd-link: '%s'\n" "$prd_link"
    printf 'last-updated: %s\n' "$now"
    printf 'session-id: %s\n' "$session_id"
    printf 'cwd: %s\n' "$cwd_redacted"
    printf 'hostname: %s\n' "$host"
    printf -- '---\n\n'
    printf '## Summary\n%s\n\n' "$summary"
    printf '## Pending Decisions\n%s\n\n' "$pending"
    printf '## Active Files\n%s\n\n' "$active_files"
    printf '## Next Action\n%s\n' "$next_action"
  } > "$target"
  printf '%s\n' "$target"
}

# full snapshot + redaction + git add + gitleaks --staged + commit. Claude SessionEnd와 Codex Stop heuristic-trigger가 공유한다 (DEC-S9 G2 + sourced helper).
# args: <runtime>  -- "claude-code" or "codex"
# 0 = success or idempotent skip, 0 = failure (non-blocking 보장).
handoff_full_snapshot_commit() {
  local runtime="${1:-unknown}"
  local repo_root branch branch_hash last_commit slug_full target diff
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || printf '')
  if [ -z "$repo_root" ]; then
    return 0
  fi
  branch=$(git -C "$repo_root" symbolic-ref --short HEAD 2>/dev/null || printf '')
  if [ -z "$branch" ]; then
    return 0
  fi
  if command -v sha1sum >/dev/null 2>&1; then
    branch_hash=$(printf '%s' "$branch" | sha1sum | head -c 6)
  else
    branch_hash=$(printf '%s' "$branch" | shasum | head -c 6)
  fi
  last_commit=$(git -C "$repo_root" rev-parse --short=7 HEAD 2>/dev/null || printf '')
  slug_full=$(handoff_compute_slug "$branch" 2>/dev/null || printf '')
  if [ -z "$slug_full" ]; then
    return 0
  fi
  target=$(handoff_write_snapshot "$slug_full" "$branch" "$branch_hash" "$last_commit" "$runtime" "" "" 2>/dev/null || printf '')
  if [ -z "$target" ] || [ ! -f "$target" ]; then
    return 0
  fi
  # idempotent diff check (DEC-S7 E2)
  diff=$(handoff_compute_diff "$target" 2>/dev/null || printf '')
  if [ -z "$diff" ]; then
    return 0
  fi
  # DEC-S13 staged ordering: add → gitleaks --staged → commit
  if ! git -C "$repo_root" add -- "$target" 2>/dev/null; then
    return 0
  fi
  if ! handoff_run_gitleaks "$target"; then
    return 0
  fi
  # DEC-S14: chore(handoff): prefix 강제
  git -C "$repo_root" commit -m "chore(handoff): session-end snapshot for ${branch}" -- "$target" >/dev/null 2>&1 || true
  return 0
}

# session_id parsing helper from stdin JSON (Codex 0.124+ schema, Claude same).
handoff_parse_session_id() {
  local input="${1:-}"
  if [ -z "$input" ]; then
    printf ''
    return 0
  fi
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true
  fi
}

# transcript_path parsing helper from stdin JSON.
handoff_parse_transcript_path() {
  local input="${1:-}"
  if [ -z "$input" ]; then
    printf ''
    return 0
  fi
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null || true
  fi
}
