#!/usr/bin/env bash
# commit-msg-pinning.sh
# 목적: commit message에서 LLM 박제(pinning) 패턴을 감지하고 경고. 영구 산출물(commit/PR/이슈)에
#       세션 내부 메타데이터(라운드 번호/finding ID/partial hash)가 박혀 squash 후 dangling되거나
#       drift를 일으키는 것을 차단한다.
# 정책:
# - warn-only: 매치 시 stderr 경고만 출력하고 exit 0. commit 차단하지 않음.
# - revert 예외: commit msg 첫 줄이 "revert" 또는 "Revert"로 시작하면 partial hash 검사 skip.
# - emergency bypass: 운영자용 escape hatch가 있다 (운영 runbook 참조). 경고 메시지에는 변수명을
#   노출하지 않는다 (사용자 인지부하 회피). 단, 스크립트 소스에서는 평문으로 보이므로 LLM이 Read
#   도구로 학습하는 경로까지 차단하지는 않는다 (security-by-obscurity 아님).
# 작동 범위: 이 hook은 신규 commit message의 박제만 감지한다. 과거 GitHub PR/이슈 본문, squash
#   commit body의 잔존 박제는 별도 sweep 작업 (.claude/research/2026-04-28-llm-pinning-audit.md).
set -euo pipefail

# 검사 대상 commit msg 파일 (lefthook이 {1}로 전달)
COMMIT_MSG_FILE="${1:-.git/COMMIT_EDITMSG}"

if [ ! -f "$COMMIT_MSG_FILE" ]; then
  exit 0
fi

is_true() {
  local val
  val=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')
  [ "$val" = "1" ] || [ "$val" = "true" ] || [ "$val" = "yes" ]
}

# Emergency bypass (운영자용 — 경고 메시지에 변수명 노출 안 함; 소스에서는 평문)
if is_true "${SKIP_PINNING_CHECK:-}"; then
  exit 0
fi

# Partial commit hash 길이 경계: GitHub 단축 hash 7자 최소, 12자 상한 (full SHA-1 40자보다 짧고
# 사람이 손으로 인용하는 범위).
HASH_MIN=7
HASH_MAX=12

# commit msg 본문 읽기 (verbose diff 라인 # 주석 + signed-off trailer 제외)
MSG_BODY=$(sed -e '/^#/d' "$COMMIT_MSG_FILE")

# commit msg 첫 줄 (revert prefix 판단용)
FIRST_LINE=$(echo "$MSG_BODY" | head -n 1)

warn() {
  echo "[WARN] pinning: $1" >&2
}

# 패턴 A — 진행 라운드 카운터: "Round N" (단어경계 + Round prefix 의무화).
# 단독 R[0-9]+는 false positive 너무 많아 제외 (정당한 약어 IPv4 R3, docs 표 R1/R2/R3 등).
PATTERN_A='\bRound [0-9]+\b'

# 패턴 B — DA finding ID 형식: BUNDLE-순번 (BUNDLE은 Title Case 풀이름 / UPPERCASE 세부 도메인 /
# 약어 모두 가능, suffix는 항상 숫자 시작). DA 출력 형식 SSOT는 modules/.../run-da/references/da-domains.md.
# 본 토큰 enum은 SSOT 스냅샷이며 자동 동기화되지 않는다 — da-domains.md에서 bundle/세부 도메인을
# 추가/제거하면 본 패턴도 함께 갱신해야 한다. 숫자 시작 suffix 의무화로 자연어 (Design-pattern,
# Regression-fix, YAGNI-concern, F-string, CIR-section, REG-istry 등) false positive 회피.
# 'F' 토큰은 SSOT 정의 없어 제거. 'DESIGN'/'REGR'은 'Design'/'REG'와 중복이라 제거.
PATTERN_B='\b(Correctness|Design|Regression|Maintainability|SECURITY|HALLUCINATION|SIDE_EFFECT|CONSISTENCY|READABILITY|CLEAN_CODE|YAGNI|NGMI|CORR|MAINT|REG|CIR)-[0-9][A-Za-z0-9-]*\b'

# 패턴 C — DA 키워드 컨텍스트: "DA for_pr" / "DA for_plan" / "DA 피드백".
# 앞쪽 단어경계 + 컨텍스트 좁힘. "DA Round N"은 패턴 A가 처리하므로 중복 분기 제거 (alert fatigue 회피).
PATTERN_C='\bDA (for_pr|for_plan|피드백)\b'

# 패턴 D — 백틱 안 partial hex (HASH_MIN ~ HASH_MAX 자리). 순수 숫자열은 hex 알파벳(a-f) 1개 이상
# 의무화하여 false positive 제외 — 포트 번호/이슈 ID/빌드 번호 같은 백틱 인용 노이즈 회피.
# commit msg 첫 줄이 revert로 시작하면 skip (정당한 git revert hash 인용 회피).
# hex 매직 상수(`deadbeef`, `cafebabe` 등)도 매치되나 발생 빈도 낮아 별도 allowlist 두지 않음
# (의도적 인용이면 amend로 무시 가능).
PATTERN_D="\`[a-f0-9]*[a-f][a-f0-9]*\`"

found=0

if echo "$MSG_BODY" | grep -qE "$PATTERN_A"; then
  warn "라운드 카운터(\`Round N\`) 박제 감지. 영구 산출물에는 자연어 설명으로 표현하라."
  echo "$MSG_BODY" | grep -nE "$PATTERN_A" | sed 's/^/         /' >&2
  found=1
fi

if echo "$MSG_BODY" | grep -qE "$PATTERN_B"; then
  warn "DA finding ID 박제 감지. 라운드/finding ID는 휘발성 보고에만 사용하고 commit message에는 박지 마라."
  echo "$MSG_BODY" | grep -nE "$PATTERN_B" | sed 's/^/         /' >&2
  found=1
fi

if echo "$MSG_BODY" | grep -qE "$PATTERN_C"; then
  warn "DA 키워드 박제 감지. 검토 모드 표기는 commit message가 아니라 PR description 또는 별도 노트에 둬라."
  echo "$MSG_BODY" | grep -nE "$PATTERN_C" | sed 's/^/         /' >&2
  found=1
fi

if [[ ! "$FIRST_LINE" =~ ^[Rr]evert ]]; then
  # PATTERN_D는 hex 알파벳 1개 이상 + 길이 경계를 요구하나 ERE에서 두 조건을 단일 표현식으로
  # 결합하기 어렵다 — grep으로 알파벳 조건만 잡고 awk로 길이 후처리. awk 내부 'matched' 변수는
  # awk-local로 셸 'found'와 독립. 단일 awk pass로 감지 + 출력 통합.
  pinning_hash_report=$(echo "$MSG_BODY" \
    | grep -noE "$PATTERN_D" 2>/dev/null \
    | awk -v min="$HASH_MIN" -v max="$HASH_MAX" '
        { idx = index($0, ":"); lineno = substr($0, 1, idx - 1); tok = substr($0, idx + 1);
          gsub(/`/, "", tok); n = length(tok);
          if (n >= min && n <= max) { print "         " lineno ": `" tok "`"; matched = 1 } }
        END { exit (matched ? 0 : 1) }
      ')
  if [ -n "$pinning_hash_report" ]; then
    warn "Partial commit hash 박제 감지. squash 머지 시 dangling 위험. 안정 식별자(PR 번호, 머지된 SHA)로 대체하라."
    echo "$pinning_hash_report" >&2
    found=1
  fi
fi

if [ "$found" -eq 1 ]; then
  warn "위 경고는 차단하지 않습니다 (warn-only). 검토 후 amend로 정정하거나 의도적 사용이면 무시하세요."
fi

exit 0
