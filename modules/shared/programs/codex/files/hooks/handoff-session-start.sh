#!/usr/bin/env bash
# handoff-session-start.sh — Codex SessionStart hook (Codex 0.124+ stable).
# Claude과 동일하게 snapshot 파일 존재 시 stdout으로 compact metadata + link 출력 (DEC-S3 I2).
# Codex 가드: epic #584 패턴. CLAUDECODE/CODEX_PROGRAMMATIC=1이면 early-exit.
# 본문 흐름은 handoff_session_start_emit_context helper가 single SoT.

set -u

if [ "${CLAUDECODE:-}" = "1" ] || [ "${CODEX_PROGRAMMATIC:-}" = "1" ]; then
  exit 0
fi

INPUT=""
[ ! -t 0 ] && INPUT=$(cat || true)

# symlink target을 따라가지 않고 호출된 경로(`~/.codex/hooks/`) 안에서 lib을 찾는다.
# 자세한 rationale은 handoff-stop.sh 헤더 주석 참조 (issue #614 round-2 fix).
HOOK_DIR=$(dirname -- "${BASH_SOURCE[0]}")
LIB="${HOOK_DIR}/handoff-lib.sh"
if [ ! -f "$LIB" ]; then
  exit 0
fi
# shellcheck source=./handoff-lib.sh
. "$LIB" || exit 0

handoff_session_start_emit_context "$INPUT"
exit 0
