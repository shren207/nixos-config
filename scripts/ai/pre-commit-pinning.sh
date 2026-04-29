#!/usr/bin/env bash
# pre-commit-pinning.sh
# staged added-lines에서 LLM 박제(pinning) 패턴을 감지한다. warn-only이며 commit을 차단하지 않는다.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="${PINNING_RULES_FILE:-$SCRIPT_DIR/lib/pinning-rules.json}"
JQ_BIN="${PINNING_JQ_BIN:-jq}"

warn() {
  echo "[WARN] pinning (pre-commit): $1" >&2
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

MARKER_MIN_REASON="$(jq_value '.markers.min_reason_length')"
MARKER_SAME_SHELL="$(jq_value '.markers.same_line.shell')"
MARKER_SAME_MARKDOWN="$(jq_value '.markers.same_line.markdown')"
MARKER_NEXT_SHELL="$(jq_value '.markers.next_line.shell')"
MARKER_NEXT_MARKDOWN="$(jq_value '.markers.next_line.markdown')"
ALLOW_URL_RE="$(jq_value '.allowlist.urls.grep_ere')"
ALLOW_CROSS_RE="$(jq_value '.allowlist.cross_repo_refs.grep_ere')"
ALLOW_CLOSING_RE="$(jq_value '.allowlist.closing_refs.grep_ere')"
PATH_EXCLUDES="$(jq_value '.path_excludes[]')"
PARTIAL_MIN="$(jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .min_length')"
PARTIAL_MAX="$(jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .max_length')"
PARTIAL_REQUIRE_ALPHA="$(jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .require_hex_alpha')"
PARTIAL_EXCLUDE_FULL="$(jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .exclude_full_sha_length')"
PARTIAL_STRIP_BACKTICKS="$(jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .strip_backticks')"
RULES_TSV="$(mktemp)"
trap 'rm -f "$RULES_TSV"' EXIT
"$JQ_BIN" -r '.rules[] | select(.contexts[] == "staged_line") | "\(.id)\u001f\(.kind)\u001f\(.message)\u001f\(.matchers.grep_ere)"' "$RULES_FILE" > "$RULES_TSV"

trim_reason() {
  printf '%s\n' "$1" | sed -e 's/[[:space:]]*-->[[:space:]]*$//' \
    -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

marker_reason() {
  local line="$1" marker="$2"
  case "$line" in
    *"$marker"*)
      local reason="${line#*"$marker"}"
      trim_reason "$reason"
      ;;
    *)
      return 1
      ;;
  esac
}

has_valid_marker() {
  local line="$1" marker reason
  for marker in "$MARKER_SAME_SHELL" "$MARKER_SAME_MARKDOWN" "$MARKER_NEXT_SHELL" "$MARKER_NEXT_MARKDOWN"; do
    if reason="$(marker_reason "$line" "$marker")"; then
      [ "${#reason}" -ge "$MARKER_MIN_REASON" ] && return 0
    fi
  done
  return 1
}

has_valid_next_marker() {
  local line="$1" marker reason
  for marker in "$MARKER_NEXT_SHELL" "$MARKER_NEXT_MARKDOWN"; do
    if reason="$(marker_reason "$line" "$marker")"; then
      [ "${#reason}" -ge "$MARKER_MIN_REASON" ] && return 0
    fi
  done
  return 1
}

path_excluded() {
  local path="$1" pattern
  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    # shellcheck disable=SC2254  # path_excludes intentionally use glob semantics.
    case "$path" in
      $pattern) return 0 ;;
    esac
  done <<< "$PATH_EXCLUDES"
  return 1
}

scrub_allowed_refs() {
  local line="$1"
  printf '%s\n' "$line" | awk -v url="$ALLOW_URL_RE" -v cross="$ALLOW_CROSS_RE" -v closing="$ALLOW_CLOSING_RE" '{
    gsub(url, "")
    gsub(cross, "")
    gsub(closing, "")
    print
  }'
}

report_finding() {
  local path="$1" line_no="$2" message="$3" line="$4"
  warn "$path:$line_no: $message"
  printf '         %s\n' "$line" >&2
  found=1
}

partial_hash_tokens() {
  local pattern="$1" line="$2"
  printf '%s\n' "$line" | grep -oE "$pattern" 2>/dev/null \
    | awk -v min="$PARTIAL_MIN" -v max="$PARTIAL_MAX" -v require_alpha="$PARTIAL_REQUIRE_ALPHA" \
        -v exclude_full="$PARTIAL_EXCLUDE_FULL" -v strip_backticks="$PARTIAL_STRIP_BACKTICKS" '
        { tok = $0;
          if (strip_backticks == "true") gsub(/`/, "", tok);
          n = length(tok);
          if (exclude_full != "" && n == exclude_full) next;
          if (n < min || n > max) next;
          if (require_alpha == "true" && tok !~ /[a-f]/) next;
          print tok }
      ' || true
}

scan_added_line() {
  local path="$1" line_no="$2" line="$3"
  local rule_id kind message pattern scrubbed tokens

  if has_valid_marker "$line"; then
    return 0
  fi

  while IFS=$'\037' read -r rule_id kind message pattern; do
    [ -n "$rule_id" ] || continue
    case "$kind" in
      partial_hash)
        tokens="$(partial_hash_tokens "$pattern" "$line")"
        if [ -n "$tokens" ]; then
          report_finding "$path" "$line_no" "$message" "$line"
        fi
        ;;
      bare_issue_ref)
        scrubbed="$(scrub_allowed_refs "$line")"
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
    if [ -n "$current_file" ] && ! path_excluded "$current_file"; then
      if [ "$skip_next" -eq 1 ]; then
        skip_next=0
      elif has_valid_next_marker "$line"; then
        skip_next=1
      else
        scan_added_line "$current_file" "$new_line" "$line"
      fi
    fi
    new_line=$((new_line + 1))
  fi
done < <(git diff --cached --unified=0 --no-ext-diff -- ':!*.lock')

if [ "$found" -eq 1 ]; then
  warn "위 경고는 차단하지 않습니다 (warn-only). 필요하면 안정 링크 또는 pinning allowlist marker를 사용하세요."
fi

exit 0
