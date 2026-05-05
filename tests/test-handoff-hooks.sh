#!/usr/bin/env bash
# tests/test-handoff-hooks.sh
# Session handoff automation hook fixture runner.
#
# 검증 항목 (Phase 2 base):
#   1. drift sha — Claude/Codex handoff-lib.sh 동일 content 검증 (DEC-S9 G2)
#   2. handoff_compute_slug — slug 정규화 + hash + 충돌 회피 + hard fail
#   3. handoff_redact — 이메일/전화/주민번호/$HOME/env-var redaction
#   4. handoff_compute_diff — noise field 제외 idempotent diff
#   5. handoff_should_trigger_full — turn-counter threshold + transcript mtime
#   6. handoff_run_gitleaks — 미설치 fallback (commit 차단 + quarantine)
#   7. branch-slug exact match — handoff-session-start.sh가 다른 branch handoff를 차단
#   8. non-blocking — 모든 hook entry가 실패 경로에서 exit 0
#
# Phase 4에서 fixture 확장: secret/PII corpus 광범위 + 3 layer 통합.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_CLAUDE="${REPO_ROOT}/modules/shared/programs/claude/files/hooks"
HOOKS_CODEX="${REPO_ROOT}/modules/shared/programs/codex/files/hooks"

PASS=0
FAIL=0
FAILED_NAMES=()

note() { printf '  - %s\n' "$1" >&2; }
ok() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1"); printf 'FAIL: %s\n' "$1" >&2; }

# 1. handoff-lib SoT — Claude SoT 단일 file이 Codex hook 디렉토리에 mkOutOfStoreSymlink로
#    노출되는 single-source 정책을 검증한다 (pinning-patterns.sh와 동일 패턴). repo source
#    레벨에서는 Codex 사본 file이 없어야 한다 — drift surface 자체를 차단.
test_handoff_lib_single_sot() {
  local name="handoff-lib SoT — Claude만 source file, Codex 사본 file은 없다"
  if [ -f "${HOOKS_CLAUDE}/handoff-lib.sh" ] && [ ! -e "${HOOKS_CODEX}/handoff-lib.sh" ]; then
    ok "$name"
  else
    note "claude=$([ -f "${HOOKS_CLAUDE}/handoff-lib.sh" ] && echo yes || echo no) codex_repo_copy=$([ -e "${HOOKS_CODEX}/handoff-lib.sh" ] && echo yes || echo no)"
    fail "$name"
  fi
}

# helper: lib을 source하여 함수 호출 가능 환경 준비.
load_lib() {
  # shellcheck source=/dev/null
  . "${HOOKS_CLAUDE}/handoff-lib.sh"
}

# 2. handoff_compute_slug.
test_compute_slug() {
  local name out

  load_lib

  name="compute_slug: 단순 branch가 slug-hash 형식 반환"
  out=$(handoff_compute_slug "main" 2>/dev/null)
  # slug 부분이 'main', hash 부분이 16진수 6자
  if [ "${out%%-*}" = "main" ] && [ ${#out} -eq $((4 + 1 + 6)) ]; then
    ok "$name"
  else
    note "got '$out'"
    fail "$name"
  fi

  name="compute_slug: slash → hyphen 변환"
  out=$(handoff_compute_slug "issue/614" 2>/dev/null)
  case "$out" in
    issue-614-?*)
      if [ ${#out} -eq $((9 + 1 + 6)) ]; then
        ok "$name"
      else
        note "got '$out' (len=${#out})"
        fail "$name"
      fi
      ;;
    *)
      note "got '$out'"
      fail "$name"
      ;;
  esac

  name="compute_slug: 같은 slug여도 다른 raw branch는 다른 hash"
  local s1 s2
  s1=$(handoff_compute_slug "foo/bar" 2>/dev/null)
  s2=$(handoff_compute_slug "foo-bar" 2>/dev/null)
  if [ "$s1" != "$s2" ] && [ "${s1%-*}" = "foo-bar" ] && [ "${s2%-*}" = "foo-bar" ]; then
    ok "$name"
  else
    note "s1=$s1 s2=$s2"
    fail "$name"
  fi

  name="compute_slug: 빈 raw branch hard fail"
  if handoff_compute_slug "" 2>/dev/null; then
    fail "$name"
  else
    ok "$name"
  fi

  name="compute_slug: 정규화 후 빈 slug hard fail"
  if handoff_compute_slug "///" 2>/dev/null; then
    fail "$name"
  else
    ok "$name"
  fi

  name="compute_slug: path traversal 후보 hard fail"
  if handoff_compute_slug "../etc" 2>/dev/null; then
    fail "$name"
  else
    ok "$name"
  fi
}

# 3. handoff_redact.
test_redact() {
  local name out

  load_lib

  contains() { case "$2" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

  name="redact: 이메일"
  out=$(handoff_redact "contact me at user@example.com please")
  if contains "<email-redacted>" "$out" && ! contains "user@example.com" "$out"; then
    ok "$name"
  else
    note "got '$out'"
    fail "$name"
  fi

  name="redact: 한국 전화번호"
  out=$(handoff_redact "phone 010-1234-5678 here")
  if contains "<phone-redacted>" "$out" && ! contains "010-1234-5678" "$out"; then
    ok "$name"
  else
    note "got '$out'"
    fail "$name"
  fi

  name="redact: 주민번호 형태"
  out=$(handoff_redact "rrn 901231-1234567 here")
  if contains "<rrn-redacted>" "$out" && ! contains "901231-1234567" "$out"; then
    ok "$name"
  else
    note "got '$out'"
    fail "$name"
  fi

  name="redact: HOME 절대경로"
  out=$(HOME=/home/test handoff_redact "log /home/test/secret.txt opened")
  # shellcheck disable=SC2088
  if contains "~/secret.txt" "$out" && ! contains "/home/test/secret.txt" "$out"; then
    ok "$name"
  else
    note "got '$out'"
    fail "$name"
  fi

  name="redact: env var 값 (API_KEY)"
  local input_value="placeholder_secret_value_blob"
  out=$(handoff_redact "API_KEY=${input_value} in log")
  if contains "API_KEY=<redacted>" "$out" && ! contains "$input_value" "$out"; then
    ok "$name"
  else
    note "got '$out'"
    fail "$name"
  fi

  # Phase 4 secret corpus: GitHub Personal Access Token, OpenAI key, AWS access key,
  # Stripe secret, JWT 모두 redaction 후 잔존 토큰 0건 확인.
  name="redact: GitHub PAT (ghp_)"
  local gh_token="ghp_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  out=$(handoff_redact "leaked $gh_token")
  if contains "<github-token-redacted>" "$out" && ! contains "$gh_token" "$out"; then
    ok "$name"
  else
    note "got '$out'"
    fail "$name"
  fi

  name="redact: OpenAI API key (sk-)"
  local openai_key="sk-AAAAAAAAAAAAAAAAAAAAAAAA"
  out=$(handoff_redact "config has $openai_key")
  if contains "<openai-key-redacted>" "$out" && ! contains "$openai_key" "$out"; then
    ok "$name"
  else
    note "got '$out'"
    fail "$name"
  fi

  name="redact: AWS access key (AKIA)"
  local aws_key="AKIAAAAAAAAAAAAAAAAA"
  out=$(handoff_redact "$aws_key in env")
  if contains "<aws-access-key-redacted>" "$out" && ! contains "$aws_key" "$out"; then
    ok "$name"
  else
    note "got '$out'"
    fail "$name"
  fi

  name="redact: Stripe secret key (sk_live_)"
  local stripe_key="sk_live_AAAAAAAAAAAAAAAAAAAAAAAA"
  out=$(handoff_redact "stripe ${stripe_key} dump")
  if contains "<stripe-key-redacted>" "$out" && ! contains "$stripe_key" "$out"; then
    ok "$name"
  else
    note "got '$out'"
    fail "$name"
  fi

  name="redact: JWT token"
  local jwt_token="eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.placeholder_signature_blob"
  out=$(handoff_redact "auth $jwt_token here")
  if contains "<jwt-redacted>" "$out" && ! contains "$jwt_token" "$out"; then
    ok "$name"
  else
    note "got '$out'"
    fail "$name"
  fi
}

# 4. handoff_compute_diff — noise field 제외 idempotent diff.
test_compute_diff_idempotent() {
  local name sandbox

  load_lib

  sandbox=$(mktemp -d)
  cd "$sandbox" >/dev/null
  git init --quiet
  git config user.email test@example
  git config user.name test
  mkdir -p .claude/handoffs
  local target="$sandbox/.claude/handoffs/sample.md"

  # 초기 commit (의미 있는 변경)
  cat > "$target" <<TARGETEOF
---
branch: main
last-commit: 1111111
runtime: claude-code
last-updated: 2026-05-05T00:00:00Z
---
TARGETEOF
  git add "$target"
  git commit --quiet -m "init"

  name="compute_diff: noise field(last-updated)만 변경된 경우 빈 diff"
  cat > "$target" <<TARGETEOF
---
branch: main
last-commit: 1111111
runtime: claude-code
last-updated: 2026-05-05T11:11:11Z
---
TARGETEOF
  local diff_out
  diff_out=$(handoff_compute_diff "$target" 2>/dev/null)
  if [ -z "$diff_out" ]; then
    ok "$name"
  else
    note "got non-empty: '$diff_out'"
    fail "$name"
  fi

  name="compute_diff: 의미 있는 필드(last-commit) 변경 시 non-empty diff"
  cat > "$target" <<TARGETEOF
---
branch: main
last-commit: 2222222
runtime: claude-code
last-updated: 2026-05-05T22:22:22Z
---
TARGETEOF
  diff_out=$(handoff_compute_diff "$target" 2>/dev/null)
  if [ -n "$diff_out" ] && contains "last-commit: 2222222" "$diff_out"; then
    ok "$name"
  else
    note "got: '$diff_out'"
    fail "$name"
  fi

  cd "$REPO_ROOT" >/dev/null
  rm -rf "$sandbox"
}

# 회귀 fixture: handoff_full_snapshot_commit이 untracked 신규 snapshot도 의미 있는 변경
# 으로 처리해 commit하는지 검증한다. 이전 구현은 git diff가 untracked 파일을 빈 결과로
# 보고하므로 첫 SessionEnd가 commit을 생략하던 회귀가 있었다.
test_full_snapshot_commit_new_file() {
  local name="full_snapshot_commit: untracked 신규 파일도 commit 발생"
  local sandbox

  load_lib

  sandbox=$(mktemp -d)
  cd "$sandbox" >/dev/null
  git init --quiet --initial-branch=main
  git config user.email test@example
  git config user.name test
  echo "init" > README.md
  git add README.md
  git commit --quiet -m "init"

  HANDOFF_SUMMARY="snapshot fixture summary" handoff_full_snapshot_commit "claude-code" >/dev/null 2>&1 || true

  local commit_count
  commit_count=$(git log --oneline -- .claude/handoffs/ 2>/dev/null | wc -l)
  if [ "$commit_count" -ge 1 ]; then
    ok "$name"
  else
    note "no commit was created for new untracked snapshot"
    fail "$name"
  fi

  cd "$REPO_ROOT" >/dev/null
  rm -rf "$sandbox"
}

# 회귀 fixture: tracked 파일에 noise field만 변경된 경우, commit skip 후 working tree가
# dirty로 남지 않아야 한다 (이전에는 commit skip 후에도 working tree에 noise 변경이 잔존
# 하여 PR/status 흐름을 오염시킬 수 있었다).
test_full_snapshot_commit_idempotent_cleanup() {
  local name="full_snapshot_commit: idempotent skip 시 working tree 정리"
  local sandbox

  load_lib

  sandbox=$(mktemp -d)
  cd "$sandbox" >/dev/null
  git init --quiet --initial-branch=main
  git config user.email test@example
  git config user.name test
  echo "init" > README.md
  git add README.md
  git commit --quiet -m "init"

  # 첫 호출 — untracked → commit 생성
  HANDOFF_SUMMARY="first run" handoff_full_snapshot_commit "claude-code" >/dev/null 2>&1 || true

  # 두 번째 호출 — last-updated만 새 timestamp이라 noise → commit skip + working tree 원복
  HANDOFF_SUMMARY="first run" handoff_full_snapshot_commit "claude-code" >/dev/null 2>&1 || true

  local porcelain
  porcelain=$(git status --porcelain 2>/dev/null)
  if [ -z "$porcelain" ]; then
    ok "$name"
  else
    note "working tree dirty after idempotent skip: '$porcelain'"
    fail "$name"
  fi

  cd "$REPO_ROOT" >/dev/null
  rm -rf "$sandbox"
}

# 5. handoff_should_trigger_full — turn-counter threshold.
test_trigger_turn_counter() {
  local name session_id

  load_lib

  session_id="test-trigger-turn-$$"
  XDG_DATA_HOME=$(mktemp -d)
  export XDG_DATA_HOME
  HANDOFF_TURN_THRESHOLD=3
  HANDOFF_IDLE_TIMEOUT_SECONDS=99999
  export HANDOFF_TURN_THRESHOLD HANDOFF_IDLE_TIMEOUT_SECONDS

  name="should_trigger_full: turn 1, 2 → skip / turn 3 → trigger"
  local r1 r2 r3
  if handoff_should_trigger_full "$session_id" "" 2>/dev/null; then r1=trigger; else r1=skip; fi
  if handoff_should_trigger_full "$session_id" "" 2>/dev/null; then r2=trigger; else r2=skip; fi
  if handoff_should_trigger_full "$session_id" "" 2>/dev/null; then r3=trigger; else r3=skip; fi
  if [ "$r1" = "skip" ] && [ "$r2" = "skip" ] && [ "$r3" = "trigger" ]; then
    ok "$name"
  else
    note "r1=$r1 r2=$r2 r3=$r3"
    fail "$name"
  fi

  name="reset_turn 후 카운터 초기화"
  handoff_reset_turn "$session_id"
  if handoff_should_trigger_full "$session_id" "" 2>/dev/null; then
    fail "$name"
  else
    ok "$name"
  fi

  rm -rf "$XDG_DATA_HOME"
}

# 6. handoff_run_gitleaks — 미설치 fallback.
test_gitleaks_missing() {
  local name="run_gitleaks: gitleaks 미설치 시 commit 차단 + quarantine"

  load_lib

  local sandbox staged
  sandbox=$(mktemp -d)
  cd "$sandbox" >/dev/null
  git init --quiet
  git config user.email test@example
  git config user.name test
  staged="${sandbox}/payload.txt"
  echo "harmless" > "$staged"
  git add "$staged"

  # gitleaks만 PATH에서 제거. git/rm 같은 core tool은 wrapper script로 보존.
  local stub_path
  stub_path=$(mktemp -d)
  # gitleaks가 stub_path에 없으면 command -v가 실패. core tool은 system path fallback으로 helper가 자체 resolve.
  local rc=0
  PATH="$stub_path" handoff_run_gitleaks "$staged" >/dev/null 2>&1 || rc=$?

  cd "$REPO_ROOT" >/dev/null
  if [ "$rc" -ne 0 ] && [ ! -f "$staged" ]; then
    ok "$name"
  else
    note "rc=$rc staged_exists=$([ -f "$staged" ] && echo yes || echo no)"
    fail "$name"
  fi
  rm -rf "$sandbox" "$stub_path"
}

# 8. non-blocking — handoff-stop entry가 lib 부재 시에도 exit 0.
test_non_blocking_lib_missing() {
  local name="non-blocking: handoff-stop.sh가 lib 부재 시 exit 0"
  local sandbox
  sandbox=$(mktemp -d)
  cp "${HOOKS_CLAUDE}/handoff-stop.sh" "$sandbox/handoff-stop.sh"
  # lib 미존재
  local rc=0
  bash "$sandbox/handoff-stop.sh" </dev/null >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "$name"
  else
    note "rc=$rc"
    fail "$name"
  fi
  rm -rf "$sandbox"
}

# Run all tests
test_handoff_lib_single_sot
test_compute_slug
test_redact
test_compute_diff_idempotent
test_full_snapshot_commit_new_file
test_full_snapshot_commit_idempotent_cleanup
test_trigger_turn_counter
test_gitleaks_missing
test_non_blocking_lib_missing

printf '\n=== Result: %d pass / %d fail ===\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'Failed:\n'
  for n in "${FAILED_NAMES[@]}"; do
    printf '  - %s\n' "$n"
  done
  exit 1
fi
exit 0
