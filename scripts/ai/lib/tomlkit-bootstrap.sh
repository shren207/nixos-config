#!/usr/bin/env bash
# scripts/ai/lib/tomlkit-bootstrap.sh
#
# tomlkit 포함 Python interpreter 부트스트랩 helper. verifier/test runner가 source한 뒤
# `tomlkit_bootstrap_require` 를 호출한다. 같은 파일을 여러 진입점이 재사용하므로 재진입
# guard env var와 nix shell re-exec 정책을 한 곳에만 둔다.
#
# 정책:
#   1) 이미 `_TOMLKIT_BOOTSTRAP_READY=1` 이면 현재 python3가 tomllib/tomlkit을 import할 수
#      있는지만 검증하고 반환한다. 실패하면 broken managed runtime으로 보고 즉시 hard fail한다.
#      devShell과 self-wrap된 nix shell은 이 sentinel을 설정한다.
#   2) sentinel이 없고 nix가 있으면 repo-pinned `nix shell .#pythonWithTomlkit --command
#      bash "$0" ...`로 재실행한다.
#   3) nix도 없으면 hard fail한다.
#
# 사용:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
#   # shellcheck disable=SC1091
#   . "$REPO_ROOT/scripts/ai/lib/tomlkit-bootstrap.sh"
#   tomlkit_bootstrap_require "$REPO_ROOT" "${BASH_SOURCE[0]}" "$@"
#
# tomlkit_bootstrap_require가 반환됐다면 이후 코드에서 `python3 -c 'import tomlkit'`를
# 전제해도 안전하다. 재실행이 필요하면 `exec`으로 교체되어 돌아오지 않는다.

tomlkit_bootstrap_require() {
  local repo_root="$1"
  local self_path="$2"
  shift 2

  if [ "${_TOMLKIT_BOOTSTRAP_READY:-}" = "1" ]; then
    if python3 -c 'import tomllib, tomlkit' 2>/dev/null; then
      return 0
    fi
    echo "  [FAIL] _TOMLKIT_BOOTSTRAP_READY=1 이지만 현재 python3가 tomllib/tomlkit을 import하지 못합니다" >&2
    exit 1
  fi

  if command -v nix >/dev/null 2>&1; then
    echo "  tomlkit bootstrap: nix shell ${repo_root}#pythonWithTomlkit --command bash $self_path" >&2
    exec nix shell "${repo_root}#pythonWithTomlkit" --command env _TOMLKIT_BOOTSTRAP_READY=1 bash "$self_path" "$@"
  fi

  echo "  [FAIL] tomlkit 미가용 + nix 명령도 없음 — 'nix develop' 또는 'nix shell .#pythonWithTomlkit' 환경이 필요합니다" >&2
  exit 1
}
