#!/usr/bin/env bash
# handoff-session-start.sh — Claude SessionStart hook. snapshot 파일 존재 시 stdout으로 compact metadata + link 출력 (DEC-S3 I2).
#
# 출력 형식:
#   [handoff resume] branch=<branch> last-commit=<sha7> file=.claude/handoffs/<slug>-<hash>.md
#   주: 상세는 위 file을 read하세요.
#
# Claude/Codex 양쪽이 plain stdout을 컨텍스트로 주입 (공식 docs 확인).
# source=startup/resume/clear 모두 동일 동작. clear의 경우 stale marker 추가.

set -u

INPUT=""
[ ! -t 0 ] && INPUT=$(cat || true)

HOOK_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")")
LIB="${HOOK_DIR}/handoff-lib.sh"
if [ ! -f "$LIB" ]; then
  exit 0
fi
# shellcheck source=./handoff-lib.sh
. "$LIB" || exit 0

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || printf '')
if [ -z "$REPO_ROOT" ]; then
  exit 0
fi

BRANCH=$(git -C "$REPO_ROOT" symbolic-ref --short HEAD 2>/dev/null || printf '')
if [ -z "$BRANCH" ]; then
  exit 0
fi

SLUG_FULL=$(handoff_compute_slug "$BRANCH" 2>/dev/null || printf '')
if [ -z "$SLUG_FULL" ]; then
  exit 0
fi

TARGET="${REPO_ROOT}/.claude/handoffs/${SLUG_FULL}.md"
if [ ! -f "$TARGET" ]; then
  exit 0
fi

# DEC-S8 F1 + branch-slug exact match: frontmatter branch 값과 현재 git branch가 같은지 검증.
# 다른 branch의 handoff가 slug 충돌로 잘못 주입되는 것을 차단한다.
# frontmatter parsing은 helper(handoff_read_frontmatter_field)가 single SoT.
SAVED_BRANCH=$(handoff_read_frontmatter_field "$TARGET" "branch")
if [ -n "$SAVED_BRANCH" ] && [ "$SAVED_BRANCH" != "$BRANCH" ]; then
  exit 0
fi

LAST_COMMIT=$(handoff_read_frontmatter_field "$TARGET" "last-commit")
[ -z "$LAST_COMMIT" ] && LAST_COMMIT="(unknown)"

REL_PATH=".claude/handoffs/${SLUG_FULL}.md"

SOURCE=""
if [ -n "$INPUT" ] && command -v jq >/dev/null 2>&1; then
  SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null || printf '')
fi

if [ "$SOURCE" = "clear" ]; then
  printf '[handoff resume] branch=%s last-commit=%s file=%s [stale: source=clear]\n' "$BRANCH" "$LAST_COMMIT" "$REL_PATH"
else
  printf '[handoff resume] branch=%s last-commit=%s file=%s\n' "$BRANCH" "$LAST_COMMIT" "$REL_PATH"
fi
printf '주: 상세는 위 file을 read하세요.\n'

exit 0
