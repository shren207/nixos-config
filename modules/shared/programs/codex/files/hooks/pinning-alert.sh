#!/usr/bin/env bash
# pinning-alert.sh — Codex 0.124+ PostToolUse warn-only alert.
# 정책 출처: https://github.com/greenheadHQ/nixos-config/issues/603
# 패턴 SSOT: scripts/ai/commit-msg-pinning.sh (PATTERN_A/B/C/D + HASH_MIN/MAX).
#   ↑ 본 파일은 그 SSOT의 inline 사본이다. commit-msg-pinning.sh 패턴을 갱신할 때 본 파일 +
#     Claude 사본(modules/shared/programs/claude/files/hooks/pinning-alert.sh)도 함께
#     갱신해야 한다 (lockstep 갱신 의무, drift 감지 자동화 없음 — 운영 검증으로 대체).
# 정책: warn-only — stderr alert + exit 0. permissionDecision 사용 금지.
#
# Codex 0.125 PostToolUse stdin schema 실측 (issue #603 Phase 0):
#   - tool_name="Bash"        → tool_input.command (shell command text)
#   - tool_name="apply_patch" → tool_input.command (V4A patch envelope text)
#       envelope: '*** Begin Patch\n*** {Update,Add,Delete} File: <path>\n@@\n+<line>\n*** End Patch'
#       matcher alias `Edit|Write|NotebookEdit`로 매칭은 트리거되지만 stdin tool_name은 apply_patch.
#       (openai/codex#18391 + 본 PR Phase 0 echo hook 캡처)
#   - tool_name="Edit|Write|NotebookEdit" → Claude Code-호환 키 (.tool_input.file_path / .new_string /
#     .content / .new_source). Codex 0.125에서는 미관측이지만 미래 호환을 위해 fallback path 유지.
set -euo pipefail

# 환경 가드(CLAUDECODE/CODEX_PROGRAMMATIC) 없음 — PostToolUse pinning-alert는 자식 LLM 세션의
# Edit/Write/apply_patch를 부모가 보지 못하기 때문에 항상 검사해야 한다
# (record-prompt-submit/stop-notification 등의 부모-처리-신뢰 가드와 의미가 다르다).
# Claude Code 안에서 Codex programmatic subprocess가 호출되면 부모 Claude hook은
# Bash matcher만 검사하고 Codex 안의 Edit/apply_patch는 못 보므로 자식 Codex hook이 직접
# 검사해야 박제를 놓치지 않는다. 중복 alert는 운영 noise로 수용.

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0

# Pinning hash 길이 경계 (commit-msg-pinning.sh와 동일)
HASH_MIN=7
HASH_MAX=12

# Patterns (commit-msg-pinning.sh PATTERN_A~D와 동일 — lockstep 갱신)
PATTERN_A='\b[Rr][Oo][Uu][Nn][Dd] [0-9]+\b'
PATTERN_B='\b(Correctness|CORRECTNESS|Design|DESIGN|Regression|REGRESSION|Maintainability|MAINTAINABILITY|Security|SECURITY|Hallucination|HALLUCINATION|Side_effect|SIDE_EFFECT|Consistency|CONSISTENCY|Readability|READABILITY|Clean_code|CLEAN_CODE|Yagni|YAGNI|Ngmi|NGMI|CORR|MAINT|MNT|REG|CIR)-[0-9][A-Za-z0-9-]*\b'
PATTERN_C='\bDA (for_pr|for_plan|피드백|[Rr]ound)\b|\bAuditor [A-Za-z_]+-[0-9]|\bparallel-audit (반영|결과|finding)\b'
PATTERN_D='\b[a-f0-9]{7,40}\b'

# 검사 대상 후보 (file_path, text) 쌍을 표준 출력 친화적 형태로 모은다.
# 단일 파일 케이스(Edit/Write/NotebookEdit)는 1쌍, apply_patch envelope는 N쌍.
# 각 쌍은 newline-separated `path\ttext_marker_id`로 표현하지 않고, 함수 호출 + 직접 grep으로 처리.

# 공통: file path가 본 hook 검사 대상에 부합하는지 판정. 통과하면 0, skip이면 1.
# mktemp tmpfile 한정: 실측 35건 모두 `body` substring(PR/issue body 작성 임시) → 그 형태로 한정.
# 일반 코드 확장자(.ts/.py/.nix 등)가 임시 디렉토리 안에 있어도 false positive 회피.
_should_check_path() {
  local p="$1"
  case "$p" in
    *.md | *.sh) ;;
    /tmp/*body* | /var/folders/*/T/*body*) ;;
    *) return 1 ;;
  esac
  case "$p" in
    */hooks/pinning-alert.sh) return 1 ;;
    */scripts/ai/commit-msg-pinning.sh) return 1 ;;
    */skills/run-da/*) return 1 ;;
    */skills/parallel-audit/*) return 1 ;;
    */tests/fixtures/*) return 1 ;;
    */evals/queries.json) return 1 ;;
    */eval-workspace/*) return 1 ;;
  esac
  return 0
}

# 공통: TEXT를 받아 패턴 4종 검사 후 매치된 finding 라인을 stdout으로 출력한다 (없으면 빈 출력).
_scan_text() {
  local text="$1"
  local out=""
  if printf '%s' "$text" | grep -qE "$PATTERN_A"; then
    out="${out}\n  - Round counter 박제: 'Round N'"
  fi
  if printf '%s' "$text" | grep -qE "$PATTERN_B"; then
    out="${out}\n  - Bundle finding ID 박제: 'Bundle-N'"
  fi
  if printf '%s' "$text" | grep -qE "$PATTERN_C"; then
    out="${out}\n  - DA 실행 키워드 박제"
  fi
  if printf '%s' "$text" | grep -oE "$PATTERN_D" 2>/dev/null \
    | awk -v min="$HASH_MIN" -v max="$HASH_MAX" '
        length($0) >= min && length($0) <= max && /[a-f]/ { found = 1 }
        END { exit !found }
      '; then
    out="${out}\n  - Partial commit hash 박제 (${HASH_MIN}~${HASH_MAX}자)"
  fi
  printf '%b' "$out"
}

case "$TOOL_NAME" in
  Edit | Write | NotebookEdit)
    # Claude Code-호환 단일 파일 케이스 (Codex 0.125에서는 미관측이지만 미래 호환).
    FILE_PATH=$(printf '%s' "$INPUT" | jq -r '
      .tool_input.file_path
      // .tool_input.notebook_path
      // empty
    ' 2>/dev/null)
    [ -n "$FILE_PATH" ] || exit 0
    _should_check_path "$FILE_PATH" || exit 0

    case "$TOOL_NAME" in
      Edit) TEXT=$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null) ;;
      Write) TEXT=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null) ;;
      NotebookEdit) TEXT=$(printf '%s' "$INPUT" | jq -r '.tool_input.new_source // empty' 2>/dev/null) ;;
    esac
    [ -n "$TEXT" ] || exit 0

    findings="$(_scan_text "$TEXT")"
    if [ -n "$findings" ]; then
      printf '[pinning-alert] %s on %s 매치:%b\n' "$TOOL_NAME" "$FILE_PATH" "$findings" >&2
    fi
    ;;
  apply_patch)
    # Codex 0.125 V4A apply_patch envelope: tool_input.command 안에 patch text.
    # patch text에서 `*** {Update,Add,Delete} File: <path>` 헤더로 영향 파일 목록을 추출하고,
    # 하나라도 검사 대상에 부합하면 patch text 전체에 박제 grep을 수행한다.
    PATCH_TEXT=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
    [ -n "$PATCH_TEXT" ] || exit 0

    SHOULD_CHECK=0
    REPORTED_PATH=""
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      if _should_check_path "$p"; then
        SHOULD_CHECK=1
        REPORTED_PATH="$p"
        break
      fi
    done < <(printf '%s' "$PATCH_TEXT" | grep -oE '^\*\*\* (Update|Add|Delete) File: .+$' | sed 's/^\*\*\* [A-Za-z]* File: //')

    [ "$SHOULD_CHECK" -eq 1 ] || exit 0

    findings="$(_scan_text "$PATCH_TEXT")"
    if [ -n "$findings" ]; then
      printf '[pinning-alert] apply_patch on %s 매치:%b\n' "$REPORTED_PATH" "$findings" >&2
    fi
    ;;
  *) exit 0 ;;
esac

exit 0
