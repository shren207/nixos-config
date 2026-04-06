#!/usr/bin/env bash
# PreToolUse Hook: rm 보호 경로 가드 (deny 보조 방어선)
#
# [WHY] settings.json의 deny는 exact match(rm -rf / 등)만 차단하므로
# 옵션 순서 변경, 추가 플래그 등 변형은 통과한다.
# 이 hook은 rm 명령의 대상 경로를 검사하여 보호 경로 삭제를 추가 차단한다.
#
# [SCOPE] rm 명령만 대상. shred, unlink, find -delete, 인터프리터 우회는 범위 밖.
# [LIMIT] regex 기반이므로 변수 확장($HOME 리터럴), path traversal(../),
#         symlink 경유, 서브셸(sh -c) 삭제는 감지 불가.
#         보안 경계가 아닌 보조 방어선으로만 기능한다.
#         deny가 catastrophic 케이스(rm -rf /, rm -rf ~ 등)를 커버한다.

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

case "$TOOL_NAME" in Bash) ;; *) exit 0 ;; esac

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# [WHY] rm 명령이 아닌 Bash 호출은 즉시 통과하여 hook 오버헤드를 최소화한다.
_contains_rm() {
  printf '%s' "$1" | grep -qE '(^|[;&|]\s*)\s*rm\b'
}
_contains_rm "$COMMAND" || exit 0

# [WHY] 보호 경로 목록. 시스템 디렉터리와 홈 디렉터리를 개별 열거한다.
# "/" catch-all은 사용하지 않는다 — bash [[ "$path" == "/"/* ]]가 "//*"로
# 전개되어 일반 절대경로를 매칭하지 못하기 때문이다.
# $HOME은 런타임에 확장되어 실제 홈 경로와 매칭한다.
PROTECTED_PREFIXES=(
  "/home"
  "/etc"
  "/var"
  "/usr"
  "/boot"
  "/sys"
  "/proc"
  "/nix"
  "/opt"
  "/lib"
  "/lib64"
  "/dev"
  "/bin"
  "/sbin"
  "/run"
  "/root"
  "/mnt"
  "/media"
  "/srv"
  "$HOME"
)

# [WHY] /tmp은 임시 파일 정리가 빈번하므로 허용한다.
# /tmp/../etc 같은 traversal은 이 hook의 scope 밖 (LIMIT 참조).
_is_tmp_path() {
  [[ "$1" == "/tmp" || "$1" == "/tmp/"* ]]
}

# [WHY] 경로가 보호 대상인지 검사한다.
# 정확히 보호 경로이거나 그 하위 경로이면 차단 대상.
# /tmp 예외를 먼저 확인하여 /tmp 하위 삭제는 허용한다.
# Returns: 매칭된 prefix를 stdout으로 출력. exit code 0=보호 대상, 1=아님.
_find_protected_prefix() {
  local path="$1"
  _is_tmp_path "$path" && return 1
  for prefix in "${PROTECTED_PREFIXES[@]}"; do
    if [ "$path" = "$prefix" ] || [[ "$path" == "$prefix"/* ]]; then
      echo "$prefix"
      return 0
    fi
  done
  return 1
}

# [WHY] rm 명령에서 경로 인자를 추출한다.
# 단순 토큰 분할로 -로 시작하는 옵션 플래그를 건너뛴다.
# [LIMIT] 따옴표 안의 공백, 변수 확장, glob은 처리하지 않는다.
# -- 이후는 모두 경로로 취급한다 (POSIX rm 관례).
_extract_rm_paths() {
  local cmd="$1"
  local past_double_dash=false
  # [WHY] grep -oE로 rm 명령 부분만 추출. 파이프/체인의 다른 명령은 무시.
  printf '%s' "$cmd" | grep -oE '(^|[;&|]\s*)\s*rm\b[^;&|]*' | while IFS= read -r rm_segment; do
    past_double_dash=false
    for token in $rm_segment; do
      case "$token" in
        rm) continue ;;
        --)
          past_double_dash=true
          continue
          ;;
        -*)
          if $past_double_dash; then
            echo "$token"
          fi
          ;;
        *) echo "$token" ;;
      esac
    done
  done
}

# [WHY] 추출된 각 경로를 보호 목록과 대조한다.
# 첫 번째 매치에서 즉시 차단하여 불필요한 반복을 방지한다.
while IFS= read -r path; do
  [ -z "$path" ] && continue
  if matched_prefix=$(_find_protected_prefix "$path"); then
    jq -n --arg reason "[rm-path-guard] 보호 경로입니다: $path (prefix: $matched_prefix)" \
      '{decision: "block", reason: $reason}'
    exit 0
  fi
done < <(_extract_rm_paths "$COMMAND")

exit 0
