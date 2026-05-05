#!/usr/bin/env bash
# handoff-session-start.sh — Codex SessionStart hook (Codex 0.124+ stable).
# Claude과 동일하게 snapshot 파일 존재 시 stdout으로 compact metadata + link 출력 (DEC-S3 I2).
# Codex 가드: epic #584 패턴. CLAUDECODE/CODEX_PROGRAMMATIC=1이면 early-exit.
# Keep in sync with ~/.claude/hooks/handoff-session-start.sh.

set -u

if [ "${CLAUDECODE:-}" = "1" ] || [ "${CODEX_PROGRAMMATIC:-}" = "1" ]; then
  exit 0
fi

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

# branch-slug exact match: frontmatter branch와 현재 git branch 일치 검증.
SAVED_BRANCH=""
if command -v awk >/dev/null 2>&1; then
  SAVED_BRANCH=$(awk '/^---$/{c++; next} c==1 && /^branch:/{sub(/^branch:[ ]*/, ""); print; exit}' "$TARGET" 2>/dev/null || printf '')
fi
if [ -n "$SAVED_BRANCH" ] && [ "$SAVED_BRANCH" != "$BRANCH" ]; then
  exit 0
fi

LAST_COMMIT=""
if command -v awk >/dev/null 2>&1; then
  LAST_COMMIT=$(awk '/^---$/{c++; next} c==1 && /^last-commit:/{sub(/^last-commit:[ ]*/, ""); print; exit}' "$TARGET" 2>/dev/null || printf '')
fi
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
