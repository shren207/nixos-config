#!/usr/bin/env bash
# handoff-session-start.sh — Claude SessionStart hook. helper로 위임.
#
# DEC-S3 I2 출력 형식:
#   [handoff resume] branch=<branch> last-commit=<sha7> file=.claude/handoffs/<slug>-<hash>.md
#   주: 상세는 위 file을 read하세요.
#
# Claude/Codex 양쪽이 plain stdout을 컨텍스트로 주입 (공식 docs 확인).
# source=startup/resume/clear 모두 동일 동작. clear의 경우 stale marker 추가.
# 본문 흐름은 handoff_session_start_emit_context helper가 single SoT.

set -u

INPUT=""
[ ! -t 0 ] && INPUT=$(cat || true)

HOOK_DIR=$(dirname -- "${BASH_SOURCE[0]}")
LIB="${HOOK_DIR}/handoff-lib.sh"
if [ ! -f "$LIB" ]; then
  exit 0
fi
# shellcheck source=./handoff-lib.sh
. "$LIB" || exit 0

handoff_session_start_emit_context "$INPUT"
exit 0
