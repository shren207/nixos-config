#!/usr/bin/env bash
# commit-msg-pinning.sh
# 목적: commit message에서 LLM 박제(pinning) 패턴을 감지하고 경고한다.
# 정책:
# - warn-only: 매치 시 stderr 경고만 출력하고 exit 0.
# - revert 예외: commit msg 첫 줄이 "revert" 또는 "Revert"로 시작하면 partial hash 검사 skip.
# 작동 범위: 신규 commit message만 검사한다. 과거 commit / PR · 이슈 본문 잔존 박제는 범위 밖이다.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034  # Read by sourced pinning-common.sh.
PINNING_WARN_PREFIX="pinning"
# shellcheck source=scripts/ai/lib/pinning-common.sh
source "$SCRIPT_DIR/lib/pinning-common.sh"

# 검사 대상 commit msg 파일 (lefthook이 {1}로 전달)
COMMIT_MSG_FILE="${1:-.git/COMMIT_EDITMSG}"

if [ ! -f "$COMMIT_MSG_FILE" ]; then
  exit 0
fi

if ! pinning_init_rules; then
  exit 0
fi

# commit msg 본문을 임시 파일에 정제 저장 (verbose diff 라인 `#` 주석 제거).
# 모든 grep은 파일 직접 읽기로 처리한다. `echo "$VAR" | grep -q`는 큰 메시지에서 SIGPIPE와
# pipefail 조합으로 경고가 silent fail 할 수 있다.
CLEAN_MSG=$(mktemp)
trap 'rm -f "$CLEAN_MSG"' EXIT
sed -e '/^#/d' "$COMMIT_MSG_FILE" > "$CLEAN_MSG"

read -r FIRST_LINE < "$CLEAN_MSG" || FIRST_LINE=""

found=0

check_ere() {
  local pattern="$1" message="$2"
  if grep -qE "$pattern" "$CLEAN_MSG"; then
    pinning_warn "$message"
    grep -nE "$pattern" "$CLEAN_MSG" | sed 's/^/         /' >&2
    found=1
  fi
}

check_bare_issue_refs() {
  local pattern="$1" message="$2"
  local scrubbed_msg report
  scrubbed_msg=$(mktemp)
  pinning_scrub_allowed_refs_file "$CLEAN_MSG" > "$scrubbed_msg"

  report="$(grep -nE "$pattern" "$scrubbed_msg" | sed 's/^/         /' || true)"

  if [ -n "$report" ]; then
    pinning_warn "$message"
    echo "$report" >&2
    found=1
  fi
  rm -f "$scrubbed_msg"
}

check_partial_hashes() {
  local pattern="$1" message="$2"
  local pinning_hash_report
  pinning_hash_report="$(pinning_partial_hash_report_file "$pattern" "$CLEAN_MSG")"
  if [ -n "$pinning_hash_report" ]; then
    pinning_warn "$message"
    echo "$pinning_hash_report" >&2
    found=1
  fi
}

while IFS= read -r rule_id; do
  [ -n "$rule_id" ] || continue
  message="$(pinning_jq_rule "$rule_id" '.message')"
  pattern="$(pinning_jq_rule "$rule_id" '.matchers.grep_ere')"
  kind="$(pinning_jq_rule "$rule_id" '.kind')"

  case "$kind" in
    partial_hash)
      if [[ ! "$FIRST_LINE" =~ ^[Rr]evert ]]; then
        check_partial_hashes "$pattern" "$message"
      fi
      ;;
    bare_issue_ref)
      check_bare_issue_refs "$pattern" "$message"
      ;;
    *)
      check_ere "$pattern" "$message"
      ;;
  esac
done < <(pinning_rule_ids_for_context commit_msg)

if [ "$found" -eq 1 ]; then
  pinning_warn "위 경고는 차단하지 않습니다 (warn-only). 검토 후 amend로 정정하거나 의도적 사용이면 무시하세요."
fi

exit 0
