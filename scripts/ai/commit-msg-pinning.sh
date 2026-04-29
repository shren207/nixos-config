#!/usr/bin/env bash
# commit-msg-pinning.sh
# 목적: commit message에서 LLM 박제(pinning) 패턴을 감지하고 경고한다.
# 정책:
# - warn-only: 매치 시 stderr 경고만 출력하고 exit 0.
# - revert 예외: commit msg 첫 줄이 "revert" 또는 "Revert"로 시작하면 partial hash 검사 skip.
# 작동 범위: 신규 commit message만 검사한다. 과거 commit / PR · 이슈 본문 잔존 박제는 범위 밖이다.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="${PINNING_RULES_FILE:-$SCRIPT_DIR/lib/pinning-rules.json}"
JQ_BIN="${PINNING_JQ_BIN:-jq}"

# 검사 대상 commit msg 파일 (lefthook이 {1}로 전달)
COMMIT_MSG_FILE="${1:-.git/COMMIT_EDITMSG}"

if [ ! -f "$COMMIT_MSG_FILE" ]; then
  exit 0
fi

warn() {
  echo "[WARN] pinning: $1" >&2
}

if ! command -v "$JQ_BIN" >/dev/null 2>&1; then
  warn "jq 미설치로 pinning 검사를 건너뜁니다 (warn-only). devShell 또는 PATH를 확인하세요."
  exit 0
fi

if [ ! -f "$RULES_FILE" ]; then
  warn "pinning rules 파일 없음: $RULES_FILE (warn-only skip)"
  exit 0
fi

if ! "$JQ_BIN" -e '.schema_version == 1' "$RULES_FILE" >/dev/null 2>&1; then
  warn "pinning rules JSON 파싱/스키마 검증 실패: $RULES_FILE (warn-only skip)"
  exit 0
fi

jq_rule() {
  local id="$1" query="$2"
  "$JQ_BIN" -r --arg id "$id" ".rules[] | select(.id == \$id) | $query" "$RULES_FILE"
}

jq_value() {
  "$JQ_BIN" -r "$1" "$RULES_FILE"
}

ALLOW_URL_RE="$(jq_value '.allowlist.urls.grep_ere')"
ALLOW_CROSS_RE="$(jq_value '.allowlist.cross_repo_refs.grep_ere')"
ALLOW_CLOSING_RE="$(jq_value '.allowlist.closing_refs.grep_ere')"

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
    warn "$message"
    grep -nE "$pattern" "$CLEAN_MSG" | sed 's/^/         /' >&2
    found=1
  fi
}

check_bare_issue_refs() {
  local pattern="$1" message="$2"
  local scrubbed_msg report
  scrubbed_msg=$(mktemp)
  awk -v url="$ALLOW_URL_RE" -v cross="$ALLOW_CROSS_RE" -v closing="$ALLOW_CLOSING_RE" '{
    gsub(url, "")
    gsub(cross, "")
    gsub(closing, "")
    print
  }' "$CLEAN_MSG" > "$scrubbed_msg"

  report="$(grep -nE "$pattern" "$scrubbed_msg" | sed 's/^/         /' || true)"

  if [ -n "$report" ]; then
    warn "$message"
    echo "$report" >&2
    found=1
  fi
  rm -f "$scrubbed_msg"
}

check_partial_hashes() {
  local pattern="$1" message="$2"
  local min max require_alpha exclude_full strip_backticks
  min="$(jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .min_length')"
  max="$(jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .max_length')"
  require_alpha="$(jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .require_hex_alpha')"
  exclude_full="$(jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .exclude_full_sha_length')"
  strip_backticks="$(jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .strip_backticks')"

  local pinning_hash_report
  pinning_hash_report=$(grep -noE "$pattern" "$CLEAN_MSG" 2>/dev/null \
    | awk -v min="$min" -v max="$max" -v require_alpha="$require_alpha" \
        -v exclude_full="$exclude_full" -v strip_backticks="$strip_backticks" '
        { idx = index($0, ":"); lineno = substr($0, 1, idx - 1); tok = substr($0, idx + 1);
          if (strip_backticks == "true") gsub(/`/, "", tok);
          n = length(tok);
          if (exclude_full != "" && n == exclude_full) next;
          if (n < min || n > max) next;
          if (require_alpha == "true" && tok !~ /[a-f]/) next;
          print "         " lineno ": " tok }
      ' || true)
  if [ -n "$pinning_hash_report" ]; then
    warn "$message"
    echo "$pinning_hash_report" >&2
    found=1
  fi
}

while IFS= read -r rule_id; do
  [ -n "$rule_id" ] || continue
  message="$(jq_rule "$rule_id" '.message')"
  pattern="$(jq_rule "$rule_id" '.matchers.grep_ere')"
  kind="$(jq_rule "$rule_id" '.kind')"

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
done < <("$JQ_BIN" -r '.rules[] | select(.contexts[] == "commit_msg") | .id' "$RULES_FILE")

if [ "$found" -eq 1 ]; then
  warn "위 경고는 차단하지 않습니다 (warn-only). 검토 후 amend로 정정하거나 의도적 사용이면 무시하세요."
fi

exit 0
