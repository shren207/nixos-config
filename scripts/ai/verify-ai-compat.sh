#!/usr/bin/env bash
# verify-ai-compat.sh — Claude Code + Codex CLI 호환 구조 검증
# 사용: `./scripts/ai/verify-ai-compat.sh` 또는 devShell에서 `verify-ai-compat`
# tomlkit 미가용 환경에서는 자동으로 `nix shell .#pythonWithTomlkit --command bash "$0"`로
# 재실행된다 (아래 tomlkit self-wrap 섹션 참조).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_SKILLS_DIR="$REPO_ROOT/.claude/skills"
TARGET_SKILLS_DIR="$REPO_ROOT/.agents/skills"

errors=0
warnings=0

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; errors=$((errors + 1)); }
warn() { echo "  [WARN] $1" >&2; warnings=$((warnings + 1)); }

# ─── Python 사전 체크 ───
# 이 스크립트는 python3 >= 3.11 (tomllib 내장)을 가정한다. 사전에 명확히 실패해서
# "tomllib 미존재" → "TOML parse 실패" 같은 오검진을 방지한다.
if ! command -v python3 >/dev/null 2>&1; then
  echo "  [FAIL] python3 not found in PATH" >&2
  exit 1
fi
if ! python3 - <<'PY' 2>/dev/null
import sys, tomllib  # tomllib requires 3.11+
if sys.version_info < (3, 11):
    raise SystemExit(1)
PY
then
  echo "  [FAIL] python3 >= 3.11 with tomllib is required" >&2
  exit 1
fi

# ─── tomlkit self-wrap ───
# sync-codex-config.py의 `check` subcommand가 tomlkit에 의존한다(import 필수).
# direct 실행(`bash scripts/ai/verify-ai-compat.sh`) 경로에서는 devShell에 tomlkit이 없어
# 호출이 EXIT_ERROR로 실패한다. tomlkit 미가용 시 repo-pinned flake output으로
# 스크립트 자체를 re-exec하여 이후 python3 호출이 항상 tomlkit-enabled가 되도록 한다.
# lefthook pre-push는 이미 `nix shell .#pythonWithTomlkit --command`로 wrap하므로
# 그 경로에서는 _VERIFY_AI_COMPAT_TOMLKIT_READY=1로 방어되어 재진입 루프가 발생하지 않는다.
if [ -z "${_VERIFY_AI_COMPAT_TOMLKIT_READY:-}" ]; then
  if ! python3 -c 'import tomlkit' 2>/dev/null; then
    if ! command -v nix >/dev/null 2>&1; then
      echo "  [FAIL] python3 tomlkit 미가용 + nix 명령도 없음 — 'nix shell .#pythonWithTomlkit' 환경이 필요합니다" >&2
      exit 1
    fi
    _VERIFY_AI_COMPAT_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    echo "  tomlkit 미가용 감지: nix shell ${_VERIFY_AI_COMPAT_REPO_ROOT}#pythonWithTomlkit로 재실행" >&2
    export _VERIFY_AI_COMPAT_TOMLKIT_READY=1
    exec nix shell "${_VERIFY_AI_COMPAT_REPO_ROOT}#pythonWithTomlkit" --command bash "${BASH_SOURCE[0]}" "$@"
  fi
fi

# ─── TOML helper ───
# 통합 helper. 모든 TOML inspection을 단일 `_toml_inspect --what=<mode>`로 수행한다.
# 이전의 _toml_parse/_toml_get_scalar/_toml_has_table/_file_mode는 모두 여기로 통합.
#
# Mode별 반환 계약 (soft-fail 계약 유지 — 한 체크 실패가 이후 섹션을 끊지 않도록):
#   --what=scalar <file> <dotted.path>
#       stdout: scalar 값(str/int/float/bool). 없거나 파싱 실패면 empty.
#       exit  : 항상 0 (command substitution 안전)
#   --what=table  <file> <dotted.path>
#       stdout: 없음.
#       exit  : table로 존재하면 0, 아니면 1 (if/then 분기용)
#   --what=parse  <file>
#       stdout: 없음.
#       exit  : 유효한 TOML이면 0, 아니면 1
#   --what=mode   <file>
#       stdout: 8진수 mode 문자열 (예: "600"). 실패 시 "?".
#       exit  : 항상 0
_toml_inspect() {
  # $1 = --what=<mode>, $2 = file, $3 = optional dotted path (scalar/table 전용)
  local what="${1#--what=}"
  shift
  python3 - "$what" "$@" <<'PY'
import os, stat, sys, tomllib

what = sys.argv[1]
args = sys.argv[2:]


def inspect_parse(path):
    try:
        with open(path, "rb") as f:
            tomllib.load(f)
    except Exception:
        sys.exit(1)
    sys.exit(0)


def inspect_scalar(path, dotted):
    # soft-fail: 파일/파싱/경로 문제는 empty stdout + exit 0.
    try:
        with open(path, "rb") as f:
            data = tomllib.load(f)
    except Exception:
        sys.exit(0)
    cur = data
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            sys.exit(0)
        cur = cur[part]
    if isinstance(cur, (str, int, float, bool)):
        print(cur)
    sys.exit(0)


def inspect_table(path, dotted):
    try:
        with open(path, "rb") as f:
            data = tomllib.load(f)
    except Exception:
        sys.exit(1)
    cur = data
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            sys.exit(1)
        cur = cur[part]
    sys.exit(0 if isinstance(cur, dict) else 1)


def inspect_mode(path):
    try:
        print(f"{stat.S_IMODE(os.stat(path).st_mode):o}")
    except Exception:
        print("?")
    sys.exit(0)


dispatch = {
    "parse":  lambda: inspect_parse(args[0]),
    "scalar": lambda: inspect_scalar(args[0], args[1]),
    "table":  lambda: inspect_table(args[0], args[1]),
    "mode":   lambda: inspect_mode(args[0]),
}
handler = dispatch.get(what)
if handler is None:
    print(f"_toml_inspect: unknown --what={what}", file=sys.stderr)
    sys.exit(2)
handler()
PY
}

echo "=== Codex 실행 정책 확인 ==="

CODEX_CONFIG="$HOME/.codex/config.toml"
if [ -f "$CODEX_CONFIG" ]; then
  _ap="$(_toml_inspect --what=scalar "$CODEX_CONFIG" approval_policy)"
  if [ "$_ap" = "never" ]; then
    pass "approval_policy = \"never\""
  else
    fail "approval_policy = \"never\" 미설정 (actual: \"$_ap\")"
  fi

  _sm="$(_toml_inspect --what=scalar "$CODEX_CONFIG" sandbox_mode)"
  if [ "$_sm" = "danger-full-access" ]; then
    pass "sandbox_mode = \"danger-full-access\""
  else
    fail "sandbox_mode = \"danger-full-access\" 미설정 (actual: \"$_sm\")"
  fi

  if grep -q 'nixos-config' "$CODEX_CONFIG"; then
    pass "프로젝트 trust 항목 존재 (선택)"
  else
    pass "프로젝트 trust 항목 없음 (선택)"
  fi
else
  fail "$HOME/.codex/config.toml 없음"
fi

echo ""
echo "=== AGENTS.md 심링크 확인 ==="

if [ -L "$REPO_ROOT/AGENTS.md" ]; then
  target="$(readlink "$REPO_ROOT/AGENTS.md")"
  if [ "$target" = "CLAUDE.md" ]; then
    pass "AGENTS.md → CLAUDE.md"
  else
    fail "AGENTS.md → '$target' (expected: CLAUDE.md)"
  fi
else
  fail "AGENTS.md 심링크 없음"
fi

echo ""
echo "=== AGENTS.override.md 확인 ==="

if [ -f "$REPO_ROOT/AGENTS.override.md" ]; then
  pass "AGENTS.override.md 존재"
else
  warn "AGENTS.override.md 없음 (Codex 전용 보충 규칙 누락)"
fi

echo ""
echo "=== 프로젝트 스킬 투영 확인 (디렉토리 심링크) ==="

if [ ! -d "$TARGET_SKILLS_DIR" ]; then
  fail ".agents/skills/ 디렉토리 없음"
else
  src_count=0
  dst_count=0

  for skill_dir in "$SOURCE_SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    [ -f "$skill_dir/SKILL.md" ] || continue
    skill_name="$(basename "$skill_dir")"
    src_count=$((src_count + 1))

    projected_entry="$TARGET_SKILLS_DIR/$skill_name"
    expected_target="../../.claude/skills/$skill_name"

    # 디렉토리 심링크 여부 확인
    if [ ! -L "$projected_entry" ]; then
      if [ -d "$projected_entry" ]; then
        fail "레거시 실디렉토리: .agents/skills/$skill_name (심링크 전환 필요)"
      else
        fail "투영 누락: .agents/skills/$skill_name"
      fi
      continue
    fi

    # 심링크 대상 경로 확인
    actual_target="$(readlink "$projected_entry")"
    if [ "$actual_target" != "$expected_target" ]; then
      fail "심링크 대상 불일치: $skill_name ($actual_target != $expected_target)"
      continue
    fi

    # 대상 존재 확인 (깨진 심링크 = warn, Nix 생성 스킬 허용)
    if [ ! -e "$projected_entry" ]; then
      warn "깨진 심링크: .agents/skills/$skill_name (소스 미존재, Nix 생성 스킬일 수 있음)"
      continue
    fi

    # SKILL.md 접근 가능 확인
    if [ -f "$projected_entry/SKILL.md" ]; then
      pass "디렉토리 심링크 정상: $skill_name"
    else
      fail "SKILL.md 접근 불가: $skill_name"
    fi
  done

  # 고아 심링크 탐지 (깨진 심링크도 포함)
  for entry in "$TARGET_SKILLS_DIR"/*; do
    [ -L "$entry" ] || [ -d "$entry" ] || continue
    skill_name="$(basename "$entry")"
    dst_count=$((dst_count + 1))

    if [ -d "$SOURCE_SKILLS_DIR/$skill_name" ]; then
      continue
    fi

    if [ -L "$entry" ]; then
      target="$(readlink "$entry")"
      if [[ "$target" = /* ]] && [ -f "$entry/SKILL.md" ]; then
        pass "플러그인 스킬 심링크 정상: $skill_name"
        continue
      fi
    fi

    fail "고아 투영: .agents/skills/$skill_name (원본 없음)"
  done

  echo ""
  echo "  소스 스킬: ${src_count}개, 투영 스킬: ${dst_count}개"
fi

echo ""
echo "=== 글로벌 설정 확인 ==="

# ~/.codex/config.toml 관리 상태
# activation의 syncCodexConfig가 repo-managed 키와 사용자 소유 섹션을 merge한 regular file로
# 유지한다. PASS 기준: (a) regular file, (b) mode 0600, (c) TOML 파싱 성공,
#                     (d) template-managed key 존재 (model/approval_policy/sandbox_mode).
# mode 불일치는 fail로 승격, legacy symlink 감지 시 nrs --force 안내.
_codex_cfg="$HOME/.codex/config.toml"
if [ ! -e "$_codex_cfg" ]; then
  fail "$_codex_cfg 없음"
elif [ -L "$_codex_cfg" ]; then
  fail "$_codex_cfg 심링크 — syncCodexConfig 미적용 (NO_CHANGES 경로 회피 위해 \`nrs --force\` 실행 필요)"
elif [ ! -f "$_codex_cfg" ]; then
  fail "$_codex_cfg regular file 아님"
else
  _mode="$(_toml_inspect --what=mode "$_codex_cfg")"
  if [ "$_mode" = "600" ]; then
    pass "$_codex_cfg regular file, mode=0600"
  else
    fail "$_codex_cfg mode=$_mode (기대: 0600) — 권한 제한 실패"
  fi
  if ! _toml_inspect --what=parse "$_codex_cfg"; then
    fail "$_codex_cfg TOML 파싱 실패"
  fi
fi

# ~/.codex/AGENTS.md
if [ -L "$HOME/.codex/AGENTS.md" ]; then
  pass "$HOME/.codex/AGENTS.md 심링크"
elif [ -f "$HOME/.codex/AGENTS.md" ]; then
  warn "$HOME/.codex/AGENTS.md 일반 파일 (심링크 아님)"
else
  warn "$HOME/.codex/AGENTS.md 없음"
fi

# ─── template ↔ live drift 검증 ───
# sync-codex-config.py의 `check` 서브커맨드에게 drift 계산을 위임한다. writer와
# 동일한 `_walk_template_leaves` iterator를 쓰므로 ownership policy drift가 구조적으로
# 차단된다. 플랫폼별 하드코딩(예: [mcp_servers.chrome-devtools] Darwin 전용) 없이,
# 해당 플랫폼의 template 파일에 선언된 leaf만 자동으로 검증된다.
echo ""
echo "=== template ↔ live drift 검증 ==="

# Nix store에 복사된 template seed가 아니라 현재 flake 워킹트리의 template을 검증 기준으로 쓴다.
if [ "$(uname -s)" = "Darwin" ]; then
  _TEMPLATE="$REPO_ROOT/modules/shared/programs/codex/files/config.darwin.toml"
else
  _TEMPLATE="$REPO_ROOT/modules/shared/programs/codex/files/config.toml"
fi
_CHECK_SCRIPT="$REPO_ROOT/modules/shared/programs/codex/files/sync-codex-config.py"

if [ ! -f "$_TEMPLATE" ]; then
  fail "template 파일 없음: $_TEMPLATE"
elif [ ! -f "$_CHECK_SCRIPT" ]; then
  fail "sync-codex-config.py 없음: $_CHECK_SCRIPT"
else
  # rc 흡수 패턴: EXIT_DRIFT(1)는 데이터 있는 정상 경로이므로 `if ...; then rc=0; else rc=$?; fi`로
  # 받아 set -euo pipefail 하에서도 verifier가 조기 종료되지 않는다. EXIT_ERROR(2)만 섹션 종료.
  _check_stdout=""
  _check_stderr=""
  _check_rc=0
  _check_err_file="$(mktemp "${TMPDIR:-/tmp}/verify-ai-compat-check-err.XXXXXX")"
  if _check_stdout="$(python3 "$_CHECK_SCRIPT" check "$_TEMPLATE" "$CODEX_CONFIG" 2>"$_check_err_file")"; then
    _check_rc=0
  else
    _check_rc=$?
  fi
  _check_stderr="$(cat "$_check_err_file")"
  rm -f "$_check_err_file"

  case "$_check_rc" in
    0|1)
      # JSON 파싱 후 target_state + drift 분기. malformed shape는 한 건 fail로 처리하고 이후 섹션 계속.
      _verdict="$(
        python3 - <<'PY' "$_check_stdout"
import json, sys
try:
    payload = json.loads(sys.argv[1])
except Exception as e:
    print(f"PARSE_ERROR {e}")
    sys.exit(0)
if not isinstance(payload, dict):
    print("PARSE_ERROR not a JSON object")
    sys.exit(0)
state = payload.get("target_state")
drift = payload.get("drift")
if state not in ("present", "missing"):
    print(f"PARSE_ERROR unexpected target_state={state!r}")
    sys.exit(0)
if not isinstance(drift, list):
    print(f"PARSE_ERROR drift not a list")
    sys.exit(0)
if state == "missing":
    print("MISSING")
elif not drift:
    print("OK")
else:
    print(f"DRIFT {len(drift)}")
    for item in drift:
        if not isinstance(item, dict):
            print(f"  malformed item: {item!r}")
            continue
        print(f"  {item.get('path','?')}: {item.get('reason','?')} expected={item.get('expected')!r} actual={item.get('actual')!r}")
PY
      )"
      case "$_verdict" in
        OK)
          pass "template이 선언한 모든 leaf가 live와 일치"
          ;;
        MISSING)
          fail "$CODEX_CONFIG 없음 (target_state=missing) — activation이 실행되지 않은 상태일 수 있음 (nrs --force 권장)"
          ;;
        DRIFT*)
          # 첫 줄 "DRIFT <N>" 헤드는 정보성 출력, 이후 각 항목을 fail()로 누적해 errors에 1건씩 반영.
          # 주의: `| while ...`는 pipe 우측이 subshell이라 `fail()`의 errors 증가가 부모로 전파되지 않는다.
          # process substitution `< <(...)`으로 while을 현재 shell에서 실행해야 한다.
          while IFS= read -r _line; do
            case "$_line" in
              "DRIFT "*)
                echo "  → template ↔ live drift: ${_line#DRIFT }건 감지" >&2
                ;;
              *)
                fail "drift: $_line"
                ;;
            esac
          done < <(echo "$_verdict" | awk 'NR==1 {print; next} {sub(/^  /,""); print}')
          ;;
        PARSE_ERROR*)
          fail "check.py 출력 파싱 실패: ${_verdict#PARSE_ERROR }"
          ;;
        *)
          fail "check.py 출력 예상치 못한 상태: $_verdict"
          ;;
      esac
      ;;
    2)
      fail "check.py EXIT_ERROR (template 읽기/파싱 실패): $_check_stderr"
      ;;
    *)
      fail "check.py 비정상 종료 (rc=$_check_rc): $_check_stderr"
      ;;
  esac
fi

echo ""
echo "=== Shared 글로벌 스킬 노출 정책 확인 ==="

SHARED_SKILLS_DIR="$REPO_ROOT/modules/shared/programs/claude/files/skills"
CODEX_GLOBAL_SKILLS_DIR="$HOME/.codex/skills"

# Nix SoT(default.nix)와 독립된 감사 오라클.
# 두 리스트는 서로 교집합이 없어야 하며, shared 디렉토리의 모든 스킬이 둘 중 하나에 속해야 한다.
EXPECTED_EXPOSED=(
  create-issue
  create-pr
  parallel-audit
  plan-with-questions
  playwright-cli
  review-pr-feedback
  run-da
  syncing-codex-harness
  write-handoff
)
INTENTIONAL_EXCLUDE=(
  set-icons
  using-claude-p
  using-codex-exec
  codex-fan-out
  documenting-intent
)

in_list() {
  local needle="$1"; shift
  local item
  for item in "$@"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

if [ ! -d "$SHARED_SKILLS_DIR" ]; then
  fail "shared skills 디렉토리 없음: $SHARED_SKILLS_DIR"
else
  shared_count=0
  for skill_dir in "$SHARED_SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    [ -f "$skill_dir/SKILL.md" ] || continue
    skill_name="$(basename "$skill_dir")"
    shared_count=$((shared_count + 1))

    exposed_path="$CODEX_GLOBAL_SKILLS_DIR/$skill_name"

    if in_list "$skill_name" "${EXPECTED_EXPOSED[@]}"; then
      if [ ! -L "$exposed_path" ]; then
        fail "노출 누락: ~/.codex/skills/$skill_name (심링크 없음)"
        continue
      fi
      # Canonical target 검증: readlink -f 결과가 shared source에 도달해야 함
      resolved="$(readlink -f "$exposed_path" 2>/dev/null || true)"
      expected_real="$(readlink -f "$skill_dir" 2>/dev/null || true)"
      if [ -z "$resolved" ] || [ "$resolved" != "$expected_real" ]; then
        fail "노출 대상 불일치: $skill_name (actual=$resolved expected=$expected_real)"
        continue
      fi
      pass "shared 노출 정상: $skill_name"
    elif in_list "$skill_name" "${INTENTIONAL_EXCLUDE[@]}"; then
      # broken symlink도 노출 상태로 간주 (-e는 깨진 심링크에 false; -L || -e로 둘 다 검출)
      if [ -L "$exposed_path" ] || [ -e "$exposed_path" ]; then
        fail "의도적 비노출이 노출됨: $skill_name"
      else
        pass "의도적 비노출 확인: $skill_name"
      fi
    else
      fail "미분류 shared 스킬: $skill_name (EXPECTED_EXPOSED 또는 INTENTIONAL_EXCLUDE 중 하나에 등록 필요)"
    fi
  done

  echo ""
  echo "  shared 스킬: ${shared_count}개, 노출 기대값: ${#EXPECTED_EXPOSED[@]}개, 비노출 기대값: ${#INTENTIONAL_EXCLUDE[@]}개"
fi

echo ""
echo "=== Codex helper 스크립트 확인 ==="

# Codex 프로비저닝된 helper가 shared source를 정확히 가리키는지 검증 (#486 F4/F8)
verify_codex_helper() {
  local helper="$1"
  local helper_path="$HOME/.codex/scripts/$helper"
  local helper_source="$REPO_ROOT/modules/shared/programs/claude/files/scripts/$helper"
  if [ ! -L "$helper_path" ]; then
    fail "$helper_path 심링크 없음"
    return
  fi
  local resolved expected
  resolved="$(readlink -f "$helper_path" 2>/dev/null || true)"
  expected="$(readlink -f "$helper_source" 2>/dev/null || true)"
  if [ -z "$resolved" ] || [ "$resolved" != "$expected" ]; then
    fail "$helper_path 대상 불일치: actual=$resolved expected=$expected"
  else
    pass "Codex helper 정상: $helper"
  fi
}

verify_codex_helper "write-handoff-repo-slug.sh"

echo ""
echo "=== Hooks 산출물 확인 ==="

if [ -e "$REPO_ROOT/.codex/hooks.json" ] || [ -e "$REPO_ROOT/.codex/hooks.compatibility.json" ]; then
  fail "stale Codex hook artifacts present (.codex/hooks*.json)"
else
  pass "repo-local Codex hook artifacts 없음"
fi

echo ""
echo "=== 원본 무결성 확인 ==="

cd "$REPO_ROOT"
if git diff --quiet .claude/skills/ 2>/dev/null; then
  pass ".claude/skills/ 원본 무변경"
else
  warn ".claude/skills/ 에 uncommitted 변경 있음"
fi

echo ""
echo "========================================="
if [ "$errors" -gt 0 ]; then
  echo "검증 실패: ${errors}개 오류, ${warnings}개 경고"
  exit 1
elif [ "$warnings" -gt 0 ]; then
  echo "검증 통과 (경고 ${warnings}개)"
  exit 0
else
  echo "검증 완전 통과"
  exit 0
fi
