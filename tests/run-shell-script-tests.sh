#!/usr/bin/env bash
# tests/run-shell-script-tests.sh
# Shell script fixture 테스트 실행기
#
# codex-config fixture는 tomlkit에 의존하므로, ambient python3가 tomlkit을 import하지 못하면
# `nix shell .#pythonWithTomlkit --command bash "$0"`로 self-wrap하여 재실행한다. verify-ai-compat.sh와
# 동일 계약. lefthook pre-push도 같은 wrapper를 쓰므로, 수동 실행(`bash tests/run-shell-script-tests.sh`)과
# pre-push 경로가 동일한 suite를 돈다.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -z "${_RUN_SHELL_SCRIPT_TESTS_TOMLKIT_READY:-}" ]; then
  if ! python3 -c 'import tomlkit' 2>/dev/null; then
    if ! command -v nix >/dev/null 2>&1; then
      echo "codex-config fixture는 tomlkit을 필요로 하지만 ambient python3와 nix 모두 미가용입니다." >&2
      echo "-> codex-config 섹션은 스킵하고 나머지만 실행합니다." >&2
      # tomlkit도 nix도 없으면 self-wrap 불가. shell-script-tests.sh 내부 skip 로직에 맡긴다.
    else
      echo "tomlkit 미가용 감지: nix shell .#pythonWithTomlkit로 재실행 (codex-config fixture 포함 전건 실행)" >&2
      export _RUN_SHELL_SCRIPT_TESTS_TOMLKIT_READY=1
      exec nix shell "${REPO_ROOT}#pythonWithTomlkit" --command bash "${BASH_SOURCE[0]}" "$@"
    fi
  fi
fi

echo "Running shell script tests..."
bash "$SCRIPT_DIR/shell-script-tests.sh"
echo "All shell script tests passed."
