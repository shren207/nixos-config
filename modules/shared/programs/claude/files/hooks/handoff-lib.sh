#!/usr/bin/env bash
# handoff-lib.sh — Session handoff automation 공통 helper.
#
# 본 helper는 Claude Code (~/.claude/hooks/handoff-lib.sh)와 Codex CLI
# (~/.codex/hooks/handoff-lib.sh) 양쪽에서 source된다. nix module이 단일 source인 본
# 파일을 양쪽 hook 디렉토리에 mkOutOfStoreSymlink하므로 두 path가 같은 inode를 가리킨다
# (`pinning-patterns.sh`와 동일 패턴). Codex 사본은 별도 source가 아니라 본 파일에 대한
# symlink — drift는 구조적으로 차단된다 (DEC-S9 refined: epic #584 Claude SoT 정책 +
# 단일 SoT helper).
#
# 환경변수 (Phase 1 Discovery에서 결정):
#   HANDOFF_IDLE_TIMEOUT_SECONDS  (default 300) — transcript_path mtime 기반 idle 임계
#   HANDOFF_TURN_THRESHOLD        (default 20)  — turn-counter 임계 (외부 state file 누적)
#
# Local SoT (Maintainability — 본 파일 안에서만 조정):
#   - branch hash 길이: 6자 (handoff_compute_slug, handoff_full_snapshot_commit 양쪽 동일)
#   - redaction regex token length floor:
#       GitHub PAT 36자 / OpenAI sk- 20자 / AWS AKIA 16자 / Stripe 24자 / JWT 10자
#     thresholds는 각 token format의 공식 minimum length에 기반한다. gitleaks rule 길이가
#     변경되면 본 파일의 redaction sed expression도 함께 조정한다.
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
# session-id/cwd/hostname은 보안상 frontmatter에 쓰지 않으므로 (FR-5 allowlist 준수)
# noise 비교 대상에서도 빠진다. timestamp 같은 ephemeral 정보만 noise로 취급한다.
HANDOFF_NOISE_FIELDS=("last-updated")

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
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  # FR-5 allowlist 준수: session-id/cwd/hostname/env 등 환경 정보는 git-tracked snapshot에
  # 절대 포함하지 않는다. transcript 원문/env vars/절대경로는 `handoff_redact` Layer 1에서
  # 추가 차단된다. 만약 machine-local 진단 정보가 필요하면 별도 untracked state 파일로 분리
  # (본 함수가 아닌 별도 helper에서 다룸).
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
    printf -- '---\n\n'
    printf '## Summary\n%s\n\n' "$summary"
    printf '## Pending Decisions\n%s\n\n' "$pending"
    printf '## Active Files\n%s\n\n' "$active_files"
    printf '## Next Action\n%s\n' "$next_action"
  } > "$target"
  printf '%s\n' "$target"
}

# frontmatter field reader — SessionStart wrapper가 사용 (Maintainability: 단일 SoT).
# stdout: field 값 (없으면 빈 문자열, exit 0)
# args: <file> <key>
handoff_read_frontmatter_field() {
  local file="${1:-}"
  local key="${2:-}"
  if [ -z "$file" ] || [ -z "$key" ] || [ ! -f "$file" ]; then
    return 0
  fi
  awk -v key="$key" '
    BEGIN { c=0 }
    /^---$/ { c++; next }
    c==1 {
      pat = "^" key ":[ \t]*"
      if (match($0, pat)) {
        print substr($0, RSTART + RLENGTH)
        exit
      }
    }
  ' "$file" 2>/dev/null || true
}

# full snapshot + redaction + git add + gitleaks --staged + commit. Claude SessionEnd와
# Codex Stop heuristic-trigger가 공유한다 (DEC-S9 + handoff-lib SoT).
# args: <runtime>  -- "claude-code" or "codex"
# 항상 exit 0 반환 (non-blocking 보장).
handoff_full_snapshot_commit() {
  local runtime="${1:-unknown}"
  local repo_root branch branch_hash last_commit slug_full target diff is_tracked
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
  # tracked 여부를 작성 전에 결정한다 — 신규 파일은 git diff가 빈 결과를 반환하므로
  # 별도 분기가 필요하다.
  if git -C "$repo_root" ls-files --error-unmatch -- ".claude/handoffs/${slug_full}.md" >/dev/null 2>&1; then
    is_tracked=yes
  else
    is_tracked=no
  fi
  target=$(handoff_write_snapshot "$slug_full" "$branch" "$branch_hash" "$last_commit" "$runtime" "" "" 2>/dev/null || printf '')
  if [ -z "$target" ] || [ ! -f "$target" ]; then
    return 0
  fi
  if [ "$is_tracked" = "yes" ]; then
    # tracked 파일은 noise field 제외 diff로 의미 있는 변경을 판정한다 (DEC-S7 idempotent).
    diff=$(handoff_compute_diff "$target" 2>/dev/null || printf '')
    if [ -z "$diff" ]; then
      # 의미 없는 변경 — working tree를 원복해 상태가 dirty로 남지 않게 한다.
      git -C "$repo_root" checkout -- "$target" >/dev/null 2>&1 || true
      return 0
    fi
  fi
  # DEC-S13 staged ordering: add → gitleaks --staged → commit
  # (untracked 신규 파일도 여기까지 도달하여 의미 있는 변경으로 처리된다.)
  if ! git -C "$repo_root" add -- "$target" 2>/dev/null; then
    # add 실패 시 working tree에 남은 untracked 파일은 quarantine한다.
    if [ "$is_tracked" = "no" ]; then
      rm -f -- "$target" 2>/dev/null || true
    fi
    return 0
  fi
  if ! handoff_run_gitleaks "$target"; then
    # handoff_run_gitleaks 내부에서 unstage + working tree quarantine 처리됨.
    return 0
  fi
  # DEC-S14: chore(handoff): prefix 강제
  if ! git -C "$repo_root" commit -m "chore(handoff): session-end snapshot for ${branch}" -- "$target" >/dev/null 2>&1; then
    # commit 실패 — staged 상태를 되돌려 working tree가 일관 상태를 유지한다.
    git -C "$repo_root" restore --staged -- "$target" 2>/dev/null || true
    if [ "$is_tracked" = "no" ]; then
      rm -f -- "$target" 2>/dev/null || true
    fi
  fi
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
