# Step 3.5 / Step I-3.5: 외부 LLM 기술 자문

Step 3 직후, 사용자에게 옵션을 제시하기 전(Step 4 직전)에 외부 LLM(`codex exec`)에 anchoring-neutral 옵션 평가를 위임한다. 목적은 사용자가 메인 LLM의 첫 추천에 anchor되어 이후 DA가 결함을 지적해도 재설계를 거부하는 패턴(`#490` 사례)을 차단하는 것이다.

## 적용 범위

- **for_action Step 3.5**: 트레이드오프 항목이 1개 이상이면 무조건 호출.
- **for_issue Step I-3.5**: 블랙박스 체크리스트 "C. 트레이드오프"에 1+ 항목이면 호출. 단순 요구사항 명료화 위주의 인터뷰는 skip.
- **for_prd**: 무조건 호출 + phase 단위로 반복 (Phase 4 채움).

## Step 3.5는 Step 5 DA와 다르다

| 항목 | Step 3.5 (consulting) | Step 5 (DA) |
|------|----------------------|-------------|
| 시점 | 사용자 질문 **전** | 사용자 답변 **후** |
| 입력 | 옵션 후보 + evidence | 작성된 plan |
| 출력 | anchoring-neutral 평가 매트릭스 | 결함 verdict (CONFIRMED/NOT_AN_ISSUE/...) |
| 목적 | de-anchoring 전처리 | 사후 검증 |

## 입력 (codex exec 프롬프트 구조)

```
## 작업 목표
{이슈/요청 요약, 1-3 문장}

## Resolved evidence (Step 2 직접 확인)
- 파일: {경로 + 핵심 사실 — `verified` 라벨}
- 명령: {실행 결과}
- 패턴: {기존 코드베이스 컨벤션}

## 제약
{기술/시간/조직 제약}

## Decision points (메인 LLM 추천 제외)
- decision_id: {식별자}
  decision_type: {tradeoff | requirement_interpretation | scope_boundary | ...}
  user_question: {사용자에게 물을 질문 원안}
  candidates:
    - id: {A/B/C}
      description: {중립 묘사 — "간단", "추천" 같은 표현 금지}

## 검증 surface (가용 도구)
{static / unit / integration / E2E / ... — `prd/references/validation-paths.md` catalog 인용}

## Non-goals
{명시적 비목표}
```

**제외할 입력**:
- 메인 LLM의 추천·선호 표현 ("A가 더 간단해 보임", "B를 권장").
- 사용자가 미이해 상태에서 수락한 선택은 `user-proposed candidate` 라벨로만 표시.
- "기본값", "default", "Recommended" 같은 anchor 단어.

## 출력 JSON schema (고정)

```json
{
  "decisions": [
    {
      "decision_id": "<string>",
      "decision_type": "<tradeoff | requirement_interpretation | scope_boundary | ...>",
      "user_question": "<string>",
      "options": [
        {
          "id": "<A | B | C | ...>",
          "description": "<중립 1-2 문장>",
          "evaluation_matrix": {
            "요구충족": "<요약>",
            "구현비용": "<요약>",
            "되돌리기쉬움": "<요약>",
            "운영위험": "<요약>",
            "검증가능성": "<요약>",
            "주요unknown": "<요약>",
            "비용시간추정": "<범위 또는 [UNVERIFIED]>"
          },
          "disqualifiers": ["<이 옵션이 틀릴 수 있는 조건>", "..."],
          "evidence_gaps": ["<verify 필요 사항>", "..."]
        }
      ],
      "validation_needed": "<검증 surface 추천>",
      "ask_user_only_if": "<사용자 판단이 정말 필요한 조건>",
      "can_agent_decide_if": "<에이전트가 판단 가능한 조건>"
    }
  ]
}
```

**금지** (메인 LLM은 codex 출력에서 이 필드들이 발견되면 무시 — anchoring 위험):
- 점수 합산, 순위, "Best", "Recommended", "Default" 라벨.
- 옵션 description에 추천/우열 암시 표현.
- Score 필드, ranking 필드.
- `chosen_*`, `selected_*`, `recommended_*`, `winner` 같은 implicit choice 필드 (codex가 자체 추가한 경우도 무시).
- `rationale` 필드를 단일 옵션 정당화로 사용 — `disqualifiers`/`evidence_gaps`만 표시 가능.

명백히 불가능한 옵션은 출력 단계에서 제외하지 않고 `disqualifiers`로 표시한다 (사용자가 "왜 이게 빠졌는지" 추측하지 않도록).

**프롬프트 정밀화**: 호출자는 "출력 JSON schema를 반환하라"가 아니라 "**위 schema에 맞는 JSON instance를 반환하라. schema definition은 출력하지 마라**"라고 명시한다. 가능하면 1-shot 예시(dummy decision의 JSON instance)를 프롬프트에 포함한다.

## codex exec 호출 명령 템플릿

`codex-fan-out` 패턴을 차용하되 read-only sandbox + JSON 출력 강제:

```zsh
# 세션 namespace
_FO_SID="${CODEX_COMPANION_SESSION_ID:+${CODEX_COMPANION_SESSION_ID:0:8}}"
if [ -z "$_FO_SID" ]; then
  if command -v sha1sum >/dev/null 2>&1; then
    _FO_SID="$(printf '%s' "$PWD-consult" | sha1sum | head -c 8)"
  else
    _FO_SID="$(printf '%s' "$PWD-consult" | shasum | head -c 8)"
  fi
fi
CONSULT_DIR=$(mktemp -d /tmp/consult-${_FO_SID}-XXXXXX)
echo "CONSULT_DIR=$CONSULT_DIR"

# 프롬프트 작성 (호출자가 위 입력 schema에 맞게 작성)
(umask 077; cat > "$CONSULT_DIR/prompt.md" <<'PROMPT'
{입력 schema 본문}

위 decision points에 대해 출력 JSON schema를 반환하라.
점수 합산·순위·"Recommended"·"Best"·"Default" 라벨 금지.
파일을 수정하지 마라. 읽기와 검색만 수행하라.
tracked write, branch mutation, commit/push, GitHub write,
main-agent-only command, host mutation,
wt/nrs/rebuild 계열 명령을 실행하지 마라.
PROMPT
)

# read-only sandbox + ephemeral + high reasoning
cat "$CONSULT_DIR/prompt.md" | env CODEX_PROGRAMMATIC=1 codex exec \
  --sandbox read-only --ephemeral \
  -c model_reasoning_effort="high" \
  -o "$CONSULT_DIR/result.json" \
  - \
  2>"$CONSULT_DIR/stderr.log"
```

- **`--sandbox read-only`**: codex 0.128.0+ 가용 (Phase 2 Discovery Gate에서 `codex exec --help`로 확인).
- **`--ephemeral`**: 세션 영속화 안 함.
- **`-o`**: JSON 결과 저장. 출력 schema 강제는 프롬프트 본문에서.
- **xhigh**: 명시적 심층 자문 요청 시에만 (`model_reasoning_effort="xhigh"`).

호출 후 정리: `rm -rf "/tmp/consult-..."`로 리터럴 경로 제거.

## Background timing

- **호출 시점**: Step 3 종료 직후 background로 발사 (`run_in_background: true`).
- **메인 LLM이 그 사이 수행할 작업**:
  - Discovery Summary 정리.
  - Plan draft 초안 (변경 대상 파일 / 실행 순서 / 검증 surface).
  - Step 3에서 수집한 사용자 질문의 비-트레이드오프 항목(요구사항 명료화 등) 1차 점검.
- **결과 도착 시**: Step 4(또는 I-4 첫 라운드) 사용자 질문 제시. 자문 매트릭스를 입력으로 통합.
- **budget**: 1-3분 (high). 초과 시 (a) timeout 알림 후 자문 없이 Step 4 진행 + plan에 [UNVERIFIED] 라벨로 자문 부재 명시, 또는 (b) 사용자에게 대기 의사 확인.

## Anti-anchoring 4 규칙 (사용자 제시 단계에서 강제)

자문 결과를 `AskUserQuestion`(또는 등가 도구)으로 제시할 때 다음을 모두 적용:

1. **"(Recommended)" 라벨 금지** — `option.label`에 추천 표시 안 함. 자문 출력에 score/rank가 있어도 무시.
2. **옵션 순서 셔플** — `decision_id`를 seed로 매 호출마다 옵션 배열 순서를 무작위화. mapping(원본 ↔ 셔플)은 메인 LLM 내부 기록에 보존.
3. **disqualifier 표시** — 각 `option.description`에 "이 선택이 틀릴 수 있는 조건"을 함께 표기. 자문 출력의 `disqualifiers` 필드를 그대로 사용.
4. **judgment-first** — 트레이드오프 옵션 제시 직전 별도 질문으로 사용자 기준을 먼저 묻는다 (예: "이 결정에서 가장 중요한 기준은? (a) 구현 속도 (b) 운영 안정성 (c) 되돌리기 용이성 (d) 검증 가능성"). 그 다음 옵션 제시.

상세 메시지 패턴은 [`output-templates.md`](./output-templates.md#step-4--step-i-4-질문-패턴) 참조.

## Decision Log 기록

자문 결과로 사용자 선택이 바뀐 경우 plan 파일 Decision Log에 ADR 미니 기록:

```
## DL-N: <decision_id>
- Status: accepted
- Context: Step 3에서 메인 LLM이 옵션 A를 후보로 작성. Step 3.5 외부 자문에서 옵션 A의 disqualifier 발견.
- Decision: 옵션 B 채택.
- Consequences: <영향>
- External Consult: <자문 결과 요약 또는 result.json 경로>
```

## Validation (Phase 2 Exit Criteria 보조)

- dummy decision (옵션 A/B 2개) 1개로 Step 3.5 round-trip 1회 성공.
- 출력 JSON에 "Recommended" / "Best" / "Default" 라벨 부재 확인 (`rg`).
- 옵션 순서가 동일 입력 2회 호출에 대해 다름 (셔플 동작 확인).
- 1-3분 내 결과 도착 (`time codex exec ...`).
- `--sandbox read-only`로 호출했을 때 file write 시도가 sandbox에서 차단됨 (negative test).
