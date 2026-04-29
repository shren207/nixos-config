#!/usr/bin/env bash
# Codex 0.124+ Stop hook single entry point.
#
# Codex는 같은 이벤트의 multiple command를 concurrent 실행하므로,
# Claude의 Stop hook 배열 ordering(record-last-stop first)을 보장하려면
# inline [[hooks.Stop]]에 dispatcher 1개만 등록하고 dispatcher가 sub-script를 순차 호출한다.
#
# Ordering rationale (issue #590):
#   1. record-last-stop  — statusline TTL race 방어를 위해 first-write로 고정한다.
#   2. nrs-session-cleanup — /tmp/nrs-state lock 해제는 ~ms latency라 stop-notification 앞에서
#      실행해야 한다. notification은 외부 IPC/HTTP timeout(stop-notification.sh의
#      HS_NOTIFY_TIMEOUT_SECONDS / PUSHOVER_TIMEOUT_SECONDS / TRANSCRIPT_STABLE_* 상수가 SoT)을
#      합쳐 다 초 단위 대기를 발생시키므로, 직렬 실행 중에 lock 해제를 차단해 동시 worktree에서
#      새 nrs가 대기하던 회귀를 만들어왔다.
#   3. stop-notification — 외부 IPC/HTTP. dispatcher 마지막 단계로 두어 lock 해제와 분리한다.
#
# Claude 패턴에서는 nrs-session-cleanup.sh가 Stop과 SessionEnd 양쪽에서 호출되었으나,
# Codex는 SessionEnd 이벤트가 없으므로(0.124/0.125 미지원) Stop dispatcher에서만 호출한다.
# Stop이 main turn 종료를 cover하므로 lock cleanup 누락은 없다.
#
# 어느 sub-script가 실패해도 다음 sub-script는 계속 실행되며,
# dispatcher 자체는 항상 exit 0 (non-blocking).

set -u
INPUT=$(cat)

run_hook() {
  local name="$1"
  local path="$2"
  if ! printf '%s' "$INPUT" | "$path"; then
    printf 'codex stop dispatcher: %s exited non-zero (continuing)\n' "$name" >&2
  fi
}

run_hook record-last-stop      "$HOME/.codex/hooks/record-last-stop.sh"      # 1번: 타임스탬프 first-write
run_hook nrs-session-cleanup   "$HOME/.codex/hooks/nrs-session-cleanup.sh"   # 2번: nrs lock 즉시 해제 (notification 외부 IPC 차단 회피)
run_hook stop-notification     "$HOME/.codex/hooks/stop-notification.sh"     # 3번: Pushover/Hammerspoon 알림

exit 0
