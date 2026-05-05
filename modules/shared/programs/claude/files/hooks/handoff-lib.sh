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
#   - branch hash 길이: HANDOFF_BRANCH_HASH_LEN 상수로 정의. 변경하려면 본 파일의 상수만
#     수정하고 모든 호출자(handoff_compute_slug, handoff_full_snapshot_commit)는 helper
#     handoff_compute_branch_hash를 사용한다.
#   - redaction regex token length floor:
#       GitHub PAT 36자 / OpenAI sk- 20자 / AWS AKIA/ASIA 16자 / Stripe 24자 / JWT 10자
#     thresholds는 각 token format의 공식 minimum length에 기반한다. gitleaks rule 길이가
#     변경되면 본 파일의 redaction sed expression도 함께 조정한다.
#   - redaction regex는 GNU sed `\b` extension을 사용하지 않는다. macOS 기본 BSD sed 호환을
#     위해 POSIX character class `[^[:alnum:]_]` 또는 줄 시작/끝 anchor로 경계를 표현한다.
#
# Public API:
#   handoff_compute_slug <raw_branch>            -> stdout: <slug>-<hash>
#   handoff_redact <input>                       -> stdout: redacted (이메일/전화/주민번호/$HOME/env-var)
#   handoff_increment_turn <session_id>          -> stdout: turn count
#   handoff_should_trigger_full <session_id> <transcript_path?> -> 0(trigger) / 1(skip)
#   handoff_compute_diff <file>                  -> stdout: noise-excluded diff (empty if idempotent)
#   handoff_run_gitleaks <staged_path> <is_tracked?> -> 0/1 (실패 시 staged unstage + working tree cleanup)
#   handoff_write_snapshot <slug> <branch> <branch_hash> <last_commit> <runtime> [issue_ref] [prd_link] -> stdout: target path

# 본 file은 source되어 호출되므로 set -euo pipefail은 호출 측 entrypoint에서 적용한다.

: "${HANDOFF_IDLE_TIMEOUT_SECONDS:=300}"
: "${HANDOFF_TURN_THRESHOLD:=20}"

# branch hash 길이 SoT — slug 충돌 방지용 짧은 sha1 prefix.
HANDOFF_BRANCH_HASH_LEN=6

# branch hash 계산 helper. handoff_compute_slug와 handoff_full_snapshot_commit 양쪽이 호출.
handoff_compute_branch_hash() {
  local raw="${1:-}"
  if [ -z "$raw" ]; then
    return 1
  fi
  if command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$raw" | sha1sum | head -c "$HANDOFF_BRANCH_HASH_LEN"
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$raw" | shasum | head -c "$HANDOFF_BRANCH_HASH_LEN"
  else
    return 1
  fi
}

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
  hash=$(handoff_compute_branch_hash "$raw" 2>/dev/null || printf '')
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
  # GitHub PAT prefix 자체가 unique signature이라 word-boundary 없이도 false positive 위험 낮다.
  out=$(printf '%s' "$out" | sed -E 's/gh[pousr]_[A-Za-z0-9]{36,}/<github-token-redacted>/g')
  # GitHub fine-grained PAT (`github_pat_<22>_<59>` 형식 — 두 segment underscore 분리)
  out=$(printf '%s' "$out" | sed -E 's/github_pat_[A-Za-z0-9_]{22,}/<github-token-redacted>/g')
  # OpenAI API 키 ('sk-' + 20자+) — POSIX 경계로 변경 (BSD sed 호환).
  out=$(printf '%s' "$out" | sed -E 's/(^|[^A-Za-z0-9_-])(sk-[A-Za-z0-9_-]{20,})/\1<openai-key-redacted>/g')
  # AWS access key ID (AKIA = 장기 credential / ASIA = STS temporary credential).
  out=$(printf '%s' "$out" | sed -E 's/(^|[^A-Za-z0-9_])((AKIA|ASIA)[0-9A-Z]{16})($|[^A-Za-z0-9_])/\1<aws-access-key-redacted>\4/g')
  # Stripe live/secret key (sk_live_ / sk_test_ / rk_live_ / rk_test_ + 24자+)
  out=$(printf '%s' "$out" | sed -E 's/(^|[^A-Za-z0-9_])((sk|rk)_(live|test)_[A-Za-z0-9]{24,})/\1<stripe-key-redacted>/g')
  # JWT (eyJ로 시작하는 base64url . base64url . base64url)
  out=$(printf '%s' "$out" | sed -E 's/(^|[^A-Za-z0-9_-])(eyJ[A-Za-z0-9_=-]{10,}\.eyJ[A-Za-z0-9_=-]{10,}\.[A-Za-z0-9_=-]{10,})/\1<jwt-redacted>/g')
  # $HOME 절대경로 → ~ (사용자 home 경로 노출 차단)
  if [ -n "${HOME:-}" ]; then
    out=$(printf '%s' "$out" | sed "s|${HOME}|~|g")
  fi
  # Unix 절대경로 — repo 외 경로 노출 차단. `~/`로 시작하지 않는 절대경로 path-like 토큰을
  # 가린다. capture group으로 단어 경계를 보존하여 BSD/GNU sed 양쪽 호환. delimiter는
  # path slash 충돌을 피하려고 `#`을 사용한다.
  out=$(printf '%s' "$out" | sed -E 's#(^|[^A-Za-z0-9_./~-])(/(home|Users|opt|var|etc|root)/[A-Za-z0-9._/-]+)#\1<abs-path-redacted>#g')
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

# gitleaks staged scan. 미설치 또는 scan 실패 시 staged unstage + working tree cleanup.
# 0 = pass, 1 = fail (commit 차단 + non-blocking exit 0은 호출 측 책임).
handoff_cleanup_after_gitleaks_failure() {
  local staged_path="${1:-}"
  local is_tracked="${2:-no}"
  if [ -z "$staged_path" ]; then
    return 0
  fi
  git restore --staged -- "$staged_path" 2>/dev/null || true
  if [ "$is_tracked" = "yes" ]; then
    git checkout -- "$staged_path" >/dev/null 2>&1 || true
  else
    rm -f -- "$staged_path" 2>/dev/null || true
  fi
}

handoff_run_gitleaks() {
  local staged_path="${1:-}"
  local is_tracked="${2:-no}"
  if [ -z "$staged_path" ]; then
    printf 'handoff: missing staged_path arg\n' >&2
    return 1
  fi
  if ! command -v gitleaks >/dev/null 2>&1; then
    printf 'handoff: gitleaks 미설치 — commit 차단 + working tree cleanup\n' >&2
    handoff_cleanup_after_gitleaks_failure "$staged_path" "$is_tracked"
    return 1
  fi
  if ! gitleaks protect --staged --no-banner --redact >/dev/null 2>&1; then
    printf 'handoff: gitleaks scan 차단 — unstage + working tree cleanup\n' >&2
    handoff_cleanup_after_gitleaks_failure "$staged_path" "$is_tracked"
    return 1
  fi
  return 0
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
  # repo opt-in gate (issue #614): hook은 user-scope로 배포되어 모든 git repo에서 작동
  # 가능하다. 의도하지 않은 repo에서 자동 commit이 발생하지 않도록, 본 함수는
  # `.claude/handoffs/.opt-in` marker 파일이 repo에 명시적으로 존재할 때만 진행한다.
  # marker 부재 시 silent exit으로 다른 repo의 작업 흐름에 영향 없음.
  if [ ! -f "$repo_root/.claude/handoffs/.opt-in" ]; then
    return 0
  fi
  branch=$(git -C "$repo_root" symbolic-ref --short HEAD 2>/dev/null || printf '')
  if [ -z "$branch" ]; then
    return 0
  fi
  # branch 원문이 secret-like(`feature/ghp_...`, `feature/user@example.com`)일 수 있으므로
  # snapshot frontmatter와 commit message에 들어가는 값을 redact한다 (Security+API).
  local branch_safe
  branch_safe=$(handoff_redact "$branch")
  branch_hash=$(handoff_compute_branch_hash "$branch" 2>/dev/null || printf '')
  # `last-commit`은 사용자 작업 이력의 anchor이다. handoff hook 자체가 만든
  # `chore(handoff):` commit은 제외하여 hook이 자신의 commit을 last-commit으로 박제하면
  # 다음 SessionEnd에서 `last-commit`이 매번 변경되어 idempotent 보장이 깨지는 회귀를
  # 차단한다.
  last_commit=$(git -C "$repo_root" log --invert-grep --grep='^chore(handoff):' \
    -n 1 --pretty=%h 2>/dev/null || printf '')
  if [ -z "$last_commit" ]; then
    last_commit=$(git -C "$repo_root" rev-parse --short=7 HEAD 2>/dev/null || printf '')
  fi
  slug_full=$(handoff_compute_slug "$branch" 2>/dev/null || printf '')
  if [ -z "$slug_full" ]; then
    return 0
  fi
  # tracked 여부를 작성 전에 결정한다 — 신규 파일은 git diff가 빈 결과를 반환하므로
  # 별도 분기가 필요하다.
  local target_rel=".claude/handoffs/${slug_full}.md"
  if git -C "$repo_root" ls-files --error-unmatch -- "$target_rel" >/dev/null 2>&1; then
    is_tracked=yes
  else
    is_tracked=no
  fi
  # 사용자가 수동 편집/merge conflict로 만든 dirty 변경이 있으면 hook이 그것을 silent로
  # 덮어쓰거나 원복하지 않게 한다 (기존 tracked snapshot이 있을 때만 검사).
  if [ "$is_tracked" = "yes" ]; then
    local dirty
    dirty=$(git -C "$repo_root" status --porcelain -- "$target_rel" 2>/dev/null || printf '')
    if [ -n "$dirty" ]; then
      printf 'handoff: 기존 snapshot에 dirty 변경 — hook skip (working tree 유지)\n' >&2
      return 0
    fi
  fi
  target=$(handoff_write_snapshot "$slug_full" "$branch_safe" "$branch_hash" "$last_commit" "$runtime" "" "" 2>/dev/null || printf '')
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
  if ! handoff_run_gitleaks "$target" "$is_tracked"; then
    # handoff_run_gitleaks 내부에서 unstage + tracked restore/untracked quarantine 처리됨.
    return 0
  fi
  # DEC-S14: chore(handoff): prefix 강제. `--no-verify`로 lefthook pre-commit 재진입을 차단한다
  # (Layer 2 gitleaks staged scan이 이미 위에서 통과했고, lefthook gitleaks는 다음 사용자 commit
  # 시점의 Layer 3로 보존된다. handoff hook이 SessionEnd마다 lefthook 전체(eval-tests/codex-hook
  # -fixtures/shellcheck/nixfmt 포함, 8.5초+)를 재실행하면 NFR-1 latency 한계를 초과한다).
  if ! git -C "$repo_root" commit --no-verify -m "chore(handoff): session-end snapshot for ${branch_safe}" -- "$target" >/dev/null 2>&1; then
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

# SessionStart wrapper의 공통 emit 흐름. Claude/Codex 양쪽 wrapper가 호출하여 본문 중복을
# 단일 SoT로 흡수한다 (Maintainability — wrapper drift 회피).
# args: <input_json>  -- stdin JSON (source field 추출용)
# stdout: I2 형식 ("[handoff resume] ..." + 안내 라인). emit 조건 미충족 시 silent (return 0).
handoff_session_start_emit_context() {
  local input="${1:-}"
  local repo_root branch slug_full target saved_branch last_commit rel_path source_field
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || printf '')
  if [ -z "$repo_root" ]; then
    return 0
  fi
  branch=$(git -C "$repo_root" symbolic-ref --short HEAD 2>/dev/null || printf '')
  if [ -z "$branch" ]; then
    return 0
  fi
  slug_full=$(handoff_compute_slug "$branch" 2>/dev/null || printf '')
  if [ -z "$slug_full" ]; then
    return 0
  fi
  target="${repo_root}/.claude/handoffs/${slug_full}.md"
  if [ ! -f "$target" ]; then
    return 0
  fi
  # branch-slug exact match: frontmatter branch와 현재 git branch 일치 검증.
  saved_branch=$(handoff_read_frontmatter_field "$target" "branch")
  if [ -n "$saved_branch" ] && [ "$saved_branch" != "$branch" ]; then
    return 0
  fi
  last_commit=$(handoff_read_frontmatter_field "$target" "last-commit")
  [ -z "$last_commit" ] && last_commit="(unknown)"
  rel_path=".claude/handoffs/${slug_full}.md"
  source_field=""
  if [ -n "$input" ] && command -v jq >/dev/null 2>&1; then
    source_field=$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null || printf '')
  fi
  if [ "$source_field" = "clear" ]; then
    printf '[handoff resume] branch=%s last-commit=%s file=%s [stale: source=clear]\n' "$branch" "$last_commit" "$rel_path"
  else
    printf '[handoff resume] branch=%s last-commit=%s file=%s\n' "$branch" "$last_commit" "$rel_path"
  fi
  printf '주: 상세는 위 file을 read하세요.\n'
  return 0
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
