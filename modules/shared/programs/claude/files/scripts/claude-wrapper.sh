#!/usr/bin/env bash
# Claude Code wrapper: $PWD에 대한 hooks trust 자동 주입 후 claude 실행
# 배경: upstream #5572, #10409 — hasTrustDialogHooksAccepted를 공식 인터페이스로 설정 불가
set -euo pipefail

cfg="$HOME/.claude.json"
claude_bin="$HOME/.local/bin/claude"
lockdir="${cfg}.lock"

# jq 없으면 trust 주입 skip, claude만 실행 (fail-open)
if ! command -v jq >/dev/null 2>&1; then
  exec "$claude_bin" "$@"
fi

# 설정 파일 없으면 claude만 실행
if [ ! -s "$cfg" ]; then
  exec "$claude_bin" "$@"
fi

cwd="$PWD"

# --- fast path: 이미 trust 설정됨 → jq 1회 조회로 skip ---
current_val=$(jq -er --arg p "$cwd" '.projects[$p].hasTrustDialogHooksAccepted // empty' "$cfg" 2>/dev/null || true)
if [ "$current_val" = "true" ]; then
  exec "$claude_bin" "$@"
fi

# --- slow path: trust 미설정 → mkdir lock 획득 후 패치 ---
acquire_lock() {
  local waited=0
  while ! mkdir -- "$lockdir" 2>/dev/null; do
    # stale lock 감지: PID 파일의 프로세스가 살아있는지 확인
    if [ -f "$lockdir/pid" ]; then
      local other_pid
      other_pid=$(cat "$lockdir/pid" 2>/dev/null || echo "")
      if [ -n "$other_pid" ] && ! kill -0 "$other_pid" 2>/dev/null; then
        rm -rf -- "$lockdir"
        continue
      fi
    fi
    waited=$((waited + 1))
    if [ "$waited" -ge 100 ]; then
      echo "claude-wrapper: lock timeout, skipping trust injection" >&2
      return 1
    fi
    sleep 0.1
  done
  echo $$ > "$lockdir/pid"
  return 0
}

cleanup() {
  rm -f "$tmp" 2>/dev/null
  rm -rf -- "$lockdir" 2>/dev/null
}

tmp=""

if acquire_lock; then
  trap cleanup EXIT INT TERM

  # TOCTOU 방지: lock 내부에서 재확인
  current_val=$(jq -er --arg p "$cwd" '.projects[$p].hasTrustDialogHooksAccepted // empty' "$cfg" 2>/dev/null || true)
  if [ "$current_val" != "true" ]; then
    tmp=$(mktemp "${cfg}.tmp.XXXXXX")

    if jq --arg p "$cwd" '
      .projects |= ((. // {}) |
        .[$p] = ((.[$p] // { allowedTools: [] }) + {
          hasTrustDialogAccepted: true,
          hasTrustDialogHooksAccepted: true
        })
      )
    ' "$cfg" > "$tmp" 2>/dev/null && jq empty "$tmp" >/dev/null 2>&1; then
      mv -- "$tmp" "$cfg"
      tmp=""  # mv 성공 시 cleanup에서 삭제하지 않도록
    else
      echo "claude-wrapper: jq patch failed, skipping trust injection" >&2
    fi
  fi

  # lock 해제 (trap도 있지만 명시적으로)
  rm -f "$tmp" 2>/dev/null
  rm -rf -- "$lockdir" 2>/dev/null
  trap - EXIT INT TERM
fi

exec "$claude_bin" "$@"
