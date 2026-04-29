#!/usr/bin/env bash
# Shared helpers for pinning rule scanners.

PINNING_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="${PINNING_RULES_FILE:-$PINNING_COMMON_DIR/pinning-rules.json}"
JQ_BIN="${PINNING_JQ_BIN:-jq}"
PINNING_WARN_PREFIX="${PINNING_WARN_PREFIX:-pinning}"

pinning_warn() {
  echo "[WARN] $PINNING_WARN_PREFIX: $1" >&2
}

pinning_init_rules() {
  if ! command -v "$JQ_BIN" >/dev/null 2>&1; then
    pinning_warn "jq 미설치로 pinning 검사를 건너뜁니다 (warn-only). devShell 또는 PATH를 확인하세요."
    return 1
  fi

  if [ ! -f "$RULES_FILE" ]; then
    pinning_warn "pinning rules 파일 없음: $RULES_FILE (warn-only skip)"
    return 1
  fi

  if ! "$JQ_BIN" -e '.schema_version == 1' "$RULES_FILE" >/dev/null 2>&1; then
    pinning_warn "pinning rules JSON 파싱/스키마 검증 실패: $RULES_FILE (warn-only skip)"
    return 1
  fi

  pinning_load_common_config
}

pinning_jq_rule() {
  local id="$1" query="$2"
  "$JQ_BIN" -r --arg id "$id" ".rules[] | select(.id == \$id) | $query" "$RULES_FILE"
}

pinning_jq_value() {
  "$JQ_BIN" -r "$1" "$RULES_FILE"
}

pinning_load_common_config() {
  MARKER_MIN_REASON="$(pinning_jq_value '.markers.min_reason_length')"
  MARKER_SAME_SHELL="$(pinning_jq_value '.markers.same_line.shell')"
  MARKER_SAME_MARKDOWN="$(pinning_jq_value '.markers.same_line.markdown')"
  MARKER_NEXT_SHELL="$(pinning_jq_value '.markers.next_line.shell')"
  MARKER_NEXT_MARKDOWN="$(pinning_jq_value '.markers.next_line.markdown')"
  ALLOW_URL_RE="$(pinning_jq_value '.allowlist.urls.grep_ere')"
  ALLOW_CROSS_RE="$(pinning_jq_value '.allowlist.cross_repo_refs.grep_ere')"
  ALLOW_CLOSING_RE="$(pinning_jq_value '.allowlist.closing_refs.grep_ere')"
  PATH_EXCLUDES="$(pinning_jq_value '.path_excludes[]')"
  PARTIAL_MIN="$(pinning_jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .min_length')"
  PARTIAL_MAX="$(pinning_jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .max_length')"
  PARTIAL_REQUIRE_ALPHA="$(pinning_jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .require_hex_alpha')"
  PARTIAL_EXCLUDE_FULL="$(pinning_jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .exclude_full_sha_length')"
  PARTIAL_STRIP_BACKTICKS="$(pinning_jq_rule partial_hash '.post_filters[] | select(.type == "partial_hash") | .strip_backticks')"
}

pinning_rules_tsv_for_context() {
  local context="$1"
  # shellcheck disable=SC2016  # jq expands $context, not the shell.
  "$JQ_BIN" -r --arg context "$context" \
    '.rules[] | select(.contexts[] == $context) | "\(.id)\u001f\(.kind)\u001f\(.message)\u001f\(.matchers.grep_ere)"' \
    "$RULES_FILE"
}

pinning_rule_ids_for_context() {
  local context="$1"
  # shellcheck disable=SC2016  # jq expands $context, not the shell.
  "$JQ_BIN" -r --arg context "$context" '.rules[] | select(.contexts[] == $context) | .id' "$RULES_FILE"
}

pinning_trim_reason() {
  printf '%s\n' "$1" | sed -e 's/[[:space:]]*-->[[:space:]]*$//' \
    -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

pinning_marker_reason() {
  local line="$1" marker="$2"
  case "$line" in
    *"$marker"*)
      local reason="${line#*"$marker"}"
      pinning_trim_reason "$reason"
      ;;
    *)
      return 1
      ;;
  esac
}

pinning_has_valid_marker() {
  local line="$1" marker reason
  for marker in "$MARKER_SAME_SHELL" "$MARKER_SAME_MARKDOWN" "$MARKER_NEXT_SHELL" "$MARKER_NEXT_MARKDOWN"; do
    if reason="$(pinning_marker_reason "$line" "$marker")"; then
      [ "${#reason}" -ge "$MARKER_MIN_REASON" ] && return 0
    fi
  done
  return 1
}

pinning_has_valid_next_marker() {
  local line="$1" marker reason
  for marker in "$MARKER_NEXT_SHELL" "$MARKER_NEXT_MARKDOWN"; do
    if reason="$(pinning_marker_reason "$line" "$marker")"; then
      [ "${#reason}" -ge "$MARKER_MIN_REASON" ] && return 0
    fi
  done
  return 1
}

pinning_path_excluded() {
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

pinning_scrub_allowed_refs_file() {
  local file="$1"
  awk -v url="$ALLOW_URL_RE" -v cross="$ALLOW_CROSS_RE" -v closing="$ALLOW_CLOSING_RE" '{
    gsub(url, "")
    gsub(cross, "")
    gsub(closing, "")
    print
  }' "$file"
}

pinning_scrub_allowed_refs() {
  local line="$1"
  printf '%s\n' "$line" | awk -v url="$ALLOW_URL_RE" -v cross="$ALLOW_CROSS_RE" -v closing="$ALLOW_CLOSING_RE" '{
    gsub(url, "")
    gsub(cross, "")
    gsub(closing, "")
    print
  }'
}

pinning_partial_hash_tokens() {
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

pinning_partial_hash_report_file() {
  local pattern="$1" file="$2"
  grep -noE "$pattern" "$file" 2>/dev/null \
    | awk -v min="$PARTIAL_MIN" -v max="$PARTIAL_MAX" -v require_alpha="$PARTIAL_REQUIRE_ALPHA" \
        -v exclude_full="$PARTIAL_EXCLUDE_FULL" -v strip_backticks="$PARTIAL_STRIP_BACKTICKS" '
        { idx = index($0, ":"); lineno = substr($0, 1, idx - 1); tok = substr($0, idx + 1);
          if (strip_backticks == "true") gsub(/`/, "", tok);
          n = length(tok);
          if (exclude_full != "" && n == exclude_full) next;
          if (n < min || n > max) next;
          if (require_alpha == "true" && tok !~ /[a-f]/) next;
          print "         " lineno ": " tok }
      ' || true
}
