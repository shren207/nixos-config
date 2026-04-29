#!/usr/bin/env bash
# pre-commit-pinning.sh
# staged added-lines에서 LLM 박제(pinning) 패턴을 감지한다. warn-only이며 commit을 차단하지 않는다.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PINNING_WARN_PREFIX="pinning (pre-commit)"
RUBY_BIN="${PINNING_RUBY_BIN:-ruby}"
# shellcheck source=scripts/ai/lib/pinning-common.sh
source "$SCRIPT_DIR/lib/pinning-common.sh"

if ! pinning_init_rules; then
  exit 0
fi

if ! command -v "$RUBY_BIN" >/dev/null 2>&1; then
  pinning_warn "ruby 미설치로 pinning 검사를 건너뜁니다 (warn-only). devShell 또는 PATH를 확인하세요."
  exit 0
fi

ADDED_LINES="$(mktemp)"
trap 'rm -f "$ADDED_LINES"' EXIT

current_file=""
new_line=0
hunk_id=0
in_hunk=0

while IFS= read -r diff_line || [ -n "$diff_line" ]; do
  if [[ "$diff_line" == "diff --git "* ]]; then
    current_file=""
    in_hunk=0
    continue
  fi

  if [ "$in_hunk" -eq 0 ]; then
    case "$diff_line" in
      "+++ b/"*)
        current_file="${diff_line#+++ b/}"
        ;;
      "+++ /dev/null")
        current_file=""
        ;;
    esac
  fi

  if [[ "$diff_line" =~ ^@@[[:space:]].*\+([0-9]+)(,([0-9]+))?[[:space:]]@@ ]]; then
    new_line="${BASH_REMATCH[1]}"
    hunk_id=$((hunk_id + 1))
    in_hunk=1
    continue
  fi

  if [[ "$diff_line" == +* ]] && ! { [ "$in_hunk" -eq 0 ] && [[ "$diff_line" == "+++ b/"* || "$diff_line" == "+++ /dev/null" ]]; }; then
    line="${diff_line#+}"
    if [ -n "$current_file" ] && ! pinning_path_excluded "$current_file"; then
      printf '%s\037%s\037%s\037%s\n' "$current_file" "$new_line" "$hunk_id" "$line" >> "$ADDED_LINES"
    fi
    new_line=$((new_line + 1))
  fi
done < <(git diff --cached --unified=0 --no-ext-diff -- ':!*.lock')

"$RUBY_BIN" - "$RULES_FILE" "$ADDED_LINES" "$PINNING_WARN_PREFIX" \
  "$MARKER_MIN_REASON" "$MARKER_SAME_SHELL" "$MARKER_SAME_MARKDOWN" \
  "$MARKER_NEXT_SHELL" "$MARKER_NEXT_MARKDOWN" <<'RUBY'
require "json"

rules_path, added_path, warn_prefix, min_reason, same_shell, same_markdown, next_shell, next_markdown = ARGV
rules = JSON.parse(File.read(rules_path))
min_reason = min_reason.to_i

allow_urls = Regexp.new(rules.fetch("allowlist").fetch("urls").fetch("js_regex"))
allow_cross = Regexp.new(rules.fetch("allowlist").fetch("cross_repo_refs").fetch("js_regex"))
allow_closing = Regexp.new(rules.fetch("allowlist").fetch("closing_refs").fetch("js_regex"))
scan_rules = rules.fetch("rules").select { |rule| rule.fetch("contexts").include?("staged_line") }
scan_rules.each do |rule|
  rule["compiled_regex"] = Regexp.new(rule.fetch("matchers").fetch("js_regex"))
end

def marker_reason(line, marker)
  idx = line.index(marker)
  return nil unless idx

  reason = line[(idx + marker.length)..] || ""
  reason = reason.sub(/[[:space:]]*-->[[:space:]]*\z/, "").strip
  reason
end

def valid_marker?(line, markers, min_reason)
  markers.any? do |marker|
    reason = marker_reason(line, marker)
    reason && reason.length >= min_reason
  end
end

def partial_hash_match?(line, rule)
  filter = rule.fetch("post_filters").find { |item| item.fetch("type") == "partial_hash" }
  return false unless filter

  line.scan(rule.fetch("compiled_regex")).flatten.any? do |raw_token|
    token = raw_token.to_s
    token = token.delete("`") if filter.fetch("strip_backticks")
    length = token.length
    next false if filter["exclude_full_sha_length"] && length == filter.fetch("exclude_full_sha_length")
    next false if length < filter.fetch("min_length") || length > filter.fetch("max_length")
    next false if filter.fetch("require_hex_alpha") && token !~ /[a-f]/

    true
  end
end

def report_finding(prefix, path, line_no, message, line)
  warn "[WARN] #{prefix}: #{path}:#{line_no}: #{message}"
  warn "         #{line}"
end

same_markers = [same_shell, same_markdown, next_shell, next_markdown]
next_markers = [next_shell, next_markdown]
found = false
skip_next = false
previous_hunk = nil

File.foreach(added_path, chomp: true) do |record|
  path, line_no, hunk_id, line = record.split("\u001f", 4)
  allow_non_reference_rules = false
  if hunk_id != previous_hunk
    skip_next = false
    previous_hunk = hunk_id
  end

  if skip_next
    allow_non_reference_rules = true
    skip_next = false
  end

  if valid_marker?(line, next_markers, min_reason)
    allow_non_reference_rules = true
    skip_next = true
  end

  allow_non_reference_rules = true if valid_marker?(line, same_markers, min_reason)

  scan_rules.each do |rule|
    next if allow_non_reference_rules && rule.fetch("kind") != "bare_issue_ref"

    matched =
      case rule.fetch("kind")
      when "partial_hash"
        partial_hash_match?(line, rule)
      when "bare_issue_ref"
        scrubbed = line.gsub(allow_urls, "").gsub(allow_cross, "").gsub(allow_closing, "")
        scrubbed.match?(rule.fetch("compiled_regex"))
      else
        line.match?(rule.fetch("compiled_regex"))
      end

    next unless matched

    report_finding(warn_prefix, path, line_no, rule.fetch("message"), line)
    found = true
  end
end

if found
  warn "[WARN] #{warn_prefix}: 위 경고는 차단하지 않습니다 (warn-only). bare ref는 leading closing-keyword line에만 두고, durable references는 URL 또는 full merged 40-char SHA를 사용하세요. non-reference metadata에만 pinning allowlist marker를 사용하세요."
end
RUBY

exit 0
