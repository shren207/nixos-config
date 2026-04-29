#!/usr/bin/env bash
# pre-commit-pinning.sh
# staged added-lines에서 LLM 박제(pinning) 패턴을 감지한다. warn-only이며 commit을 차단하지 않는다.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PINNING_WARN_PREFIX="pinning (pre-commit)"
# shellcheck source=scripts/ai/lib/pinning-common.sh
source "$SCRIPT_DIR/lib/pinning-common.sh"

if ! pinning_init_rules; then
  exit 0
fi
RULES_TSV="$(mktemp)"
trap 'rm -f "$RULES_TSV"' EXIT
pinning_rules_tsv_for_context staged_line > "$RULES_TSV"

report_finding() {
  local path="$1" line_no="$2" message="$3" line="$4"
  pinning_warn "$path:$line_no: $message"
  printf '         %s\n' "$line" >&2
  found=1
}

scan_added_line() {
  local path="$1" line_no="$2" line="$3"
  local rule_id kind message pattern scrubbed tokens

  if pinning_has_valid_marker "$line"; then
    return 0
  fi

  while IFS=$'\037' read -r rule_id kind message pattern; do
    [ -n "$rule_id" ] || continue
    case "$kind" in
      partial_hash)
        tokens="$(pinning_partial_hash_tokens "$pattern" "$line")"
        if [ -n "$tokens" ]; then
          report_finding "$path" "$line_no" "$message" "$line"
        fi
        ;;
      bare_issue_ref)
        scrubbed="$(pinning_scrub_allowed_refs "$line")"
        if printf '%s\n' "$scrubbed" | grep -qE "$pattern"; then
          report_finding "$path" "$line_no" "$message" "$line"
        fi
        ;;
      *)
        if printf '%s\n' "$line" | grep -qE "$pattern"; then
          report_finding "$path" "$line_no" "$message" "$line"
        fi
        ;;
    esac
  done < "$RULES_TSV"
}

found=0
current_file=""
new_line=0
skip_next=0

while IFS= read -r diff_line || [ -n "$diff_line" ]; do
  case "$diff_line" in
    "+++ b/"*)
      current_file="${diff_line#+++ b/}"
      skip_next=0
      ;;
    "+++ /dev/null")
      current_file=""
      skip_next=0
      ;;
  esac

  if [[ "$diff_line" =~ ^@@[[:space:]].*\+([0-9]+)(,([0-9]+))?[[:space:]]@@ ]]; then
    new_line="${BASH_REMATCH[1]}"
    skip_next=0
    continue
  fi

  if [[ "$diff_line" == +* && "$diff_line" != +++* ]]; then
    line="${diff_line#+}"
    if [ -n "$current_file" ] && ! pinning_path_excluded "$current_file"; then
      if [ "$skip_next" -eq 1 ]; then
        skip_next=0
      elif pinning_has_valid_next_marker "$line"; then
        skip_next=1
      else
        scan_added_line "$current_file" "$new_line" "$line"
      fi
    fi
    new_line=$((new_line + 1))
  fi
done < <(git diff --cached --unified=0 --no-ext-diff -- ':!*.lock')

if [ "$found" -eq 1 ]; then
  pinning_warn "위 경고는 차단하지 않습니다 (warn-only). 필요하면 안정 링크 또는 pinning allowlist marker를 사용하세요."
fi

exit 0
