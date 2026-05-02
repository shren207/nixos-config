# 메인 에이전트 의무 (피드백 프로토콜 + 사용자 질문 맥락 + 검증 의무)

`run-da` 메인 에이전트의 행동 강제 규칙. DA → Arbiter 상태 흐름은 [`protocol.md`](protocol.md)가 정본이고, 본 파일은 그 흐름에서 **메인 에이전트가 직접 수행해야 하는 행동/금지 항목**을 모은다.

## 메인 에이전트 역할

| 수행 | 금지 |
|------|------|
| CONFIRMED_ISSUE 수정 | Review Intensity 판단 |
| tracked workspace write, branch mutation, commit/push, GitHub write | DA reviewer/Auditor/Arbiter/Intensity에 single-writer 작업 위임 |
| `wt`, `nrs`, rebuild 계열 실행 | main-agent-only command를 direct fan-out subagent에 넘기기 |
| 질문 도구 호출 (SKIP/NEEDS_MORE_INFO) | DA finding 직접 판정 |
| Arbiter 결과 수신 및 보고 | "사용자 지시"로 DA 기각 |
| 결과 파일 파싱 | 프롬프트 조향 |

## 핵심 원칙

- **Arbiter 독립 판정**: DA findings는 독립 Arbiter 에이전트가 판정한다. 메인 에이전트는 판정하지 않는다.
  메인 에이전트는 CONFIRMED_ISSUE 항목의 수정만 담당한다.
- **CONFIRMED_ISSUE 자동 반영**: Arbiter가 CONFIRMED_ISSUE로 판정한 항목은 자동으로 반영한다.
  CRITICAL 심각도는 진행을 차단하고 즉시 수정한다.
- **사용자 전건 보고**: 모든 Arbiter 판정 결과(CONFIRMED_ISSUE, NOT_AN_ISSUE, NEEDS_MORE_INFO)를 사용자에게 보고한다.
  NEEDS_MORE_INFO 항목은 질문 도구로 사용자 판단을 요청한다.
- **Conservative wait**: Codex 세션 경로에서 `wait_agent` timeout이나 단순 지연만으로 reviewer/Arbiter/Intensity를 kill하지 않는다.
  explicit failure signal, documented violation, 최종 응답 파싱 실패가 없는 한 self-auditing으로 대체하지 않는다.
- **Single-writer 유지**: tracked workspace write, branch mutation, commit/push, GitHub write, `wt`/`nrs`/rebuild 계열은 메인 에이전트가 수행한다.
  DA reviewer의 PoC는 repo 밖 scratch에 한정한다.
- **PoC 의무화**: DA가 위반을 지적하면 구체적 파일:줄 또는 계획 항목 번호를 제시해야 한다.
  증거 없는 추상적 우려는 Arbiter가 NOT_AN_ISSUE로 판정한다.
- **Violation 처리**: recoverable violation은 offending unit discard 후 fresh rerun한다.
  stateful violation은 현재 라운드를 중단하고, offending unit이 이번 라운드에서 만든 산출물만 정리한다. 기존 local 변경은 자동 정리하지 않으며, `BLOCKED` 해소 또는 명시적 rerun 전에는 `CLEAR`로 간주하지 않는다.
- **Fresh perspective 보장**: 매 라운드마다 새 에이전트를 사용한다.
  `fresh` modifier 사용 시 이전 라운드 맥락도 완전히 차단한다.
- **Selective propagation 기본값**: Arbiter/후속 reviewer에게는 unique findings, conflicting findings,
  high-severity findings, user decision required findings만 전달한다.
  raw transcript 전체, CLEAR 결과, 중복 low-signal finding의 all-to-all broadcast는 금지한다.
  `full` modifier는 propagation이 아니라 fan-out만 확장한다.
- **Selective consistency on ambiguous findings**: first-pass Arbiter 결과가 애매한 경우에만
  N=3 재판정을 실행한다. 명확한 finding은 first-pass single Arbiter로 종료한다. 정책(trigger/vote-shape/threshold)은
  [`stability-measurement.md`](stability-measurement.md)가 SSOT,
  상태 전이는 [`protocol.md`](protocol.md), 실행 계약은 [`arbiter-scaling.md`](arbiter-scaling.md) 참조.
- **프롬프트 조향 금지**: 후속 라운드 DA/Arbiter 프롬프트에 이전 라운드의 판정 결과를 포함하지 않는다.
  이전 라운드 결과를 "이미 해결된 사안"으로 프레이밍하는 것도 금지한다.
- **무한 루프 방지**: 3회 연속 동일 지적(세부 관점 + 위치 기준)이 반복되면 사용자 결정에 위임한다.
- **탈출 조건**: 선택된 review unit 모두 CLEAR를 반환하면 루프를 종료한다 (`NOT_RUN` 제외).

상세 상태 흐름 + Arbiter 판정 프로토콜은 [`protocol.md`](protocol.md) 참조.

## 사용자 질문 시 맥락 설명 의무

사용자에게 질문 도구로 판단을 요청할 때 (3회 반복 규칙, 5회 라운드 초과, fresh 모드 반복 감지 등 모든 경우), 사용자가 **딴짓을 하다가 돌아온 상황**을 가정하고 다음을 모두 포함한다:

1. **현재 상황 요약**: 어떤 작업을 하고 있었는지 (예: "PR #<번호>의 DA for_pr 피드백 루프 진행 중입니다")
2. **문제 설명**: 무엇이 충돌/반복되고 있는지 구체적으로
3. **비유법 설명**: 기술 용어를 모르는 사람도 이해할 수 있도록 쉬운 비유로 설명
4. **선택지별 장단점**: 각 선택이 가져올 결과를 명확히
5. **질문**: 질문 도구로 결정 요청

**나쁜 예** (맥락 부재):
> "SECURITY DA가 3회 연속 동일 지적을 반복합니다. 수용/기각/보류 중 선택해주세요."

**좋은 예** (맥락 풍부):
> "현재 PR #<번호> 코드 리뷰 N라운드째입니다. `SECURITY` 세부 관점 finding이 3회 연속 '입력 검증 누락'을 지적하고 있습니다.
> 해당 코드는 modules/foo.nix:42의 사용자 입력 처리 부분인데, 쉽게 비유하면 '현관문에 잠금장치를 달아야 한다'는 지적입니다.
> 저는 이전 2라운드에서 '이 입력은 내부 시스템에서만 오므로 잠금이 불필요하다'고 기각했지만, DA가 계속 지적합니다.
> - 수용: 입력 검증 코드 추가 (안전하지만 불필요한 코드 증가)
> - 기각 + CIR: '내부 전용 입력'이라는 근거를 기록하고 넘어감
> - 보류: 별도 이슈로 등록하고 나중에 판단"

## 검증 의무

### DA 에이전트 출력 요건

- 모든 지적에는 반드시 구체적 파일:줄 또는 계획 항목 번호를 제시해야 한다.
- 코드 스니펫 또는 계획 원문을 직접 인용하여 문제를 증명해야 한다.
- "~할 수도 있다", "~이 우려된다" 등 증거 없는 추상적 우려는 즉시 기각한다.

### Arbiter 검증 의무

- Arbiter는 각 finding에 대해 5가지 판정 기준(사실 정확성, 변경 연관성, 심각도 타당성, 실행 가능성, Portability / Cross-Environment Drift)으로 독립 검증한다. Portability는 verdict 결정권 없는 guardrail 축이다.
- NOT_AN_ISSUE 판정에는 직접 확인 + 반증 근거가 필수다 (모드별 증거 요건: [`arbiter-prompt.md`](arbiter-prompt.md) 참조).
- NEEDS_MORE_INFO는 추가 정보가 필요한 경우에만 사용한다.
- 상세 판정 기준은 [`arbiter-prompt.md`](arbiter-prompt.md) 참조.

### 메인 에이전트 수정 의무

- CONFIRMED_ISSUE 항목을 수정할 때, 해당 위치(파일:줄 또는 계획 항목)를 확인하는 것은 수정 작업의 일부로 수행한다.
- 수정 결과가 finding을 해결하는지 확인한다.
