# Post-Implementation (승인 후 자동 수행)

`for_action` 계획 승인 또는 `for_prd` 승인 게이트를 통과하면, 승인 표면에 표시된 stable step ID와 자동 수행 범위를 순차 수행한다. 추가 사용자 지시 없이 승인된 범위 안에서 진행한다. PR write는 표시 범위에 `PI-CREATE-PR`가 포함된 경우에만 수행한다. split PRD의 final PR write gate에서는 추가로 GitHub에 전달할 exact PR title/body 승인이 필요하다. 각 단계에서 reviewer/auditor/체크리스트 수행자는 read-only이며, tracked write·commit·push는 메인 에이전트 전용이다. 상세 권한 계약은 [`../../run-da/references/hardening-contract.md`](../../run-da/references/hardening-contract.md) `Codex 세션 하드닝 계약`을 따른다.

## 자동 진행 정책 (non-stop)

이 절차는 사용자 추가 지시 없이 자동 수행한다. "다음 단계 진행할까요?", "이 변경을 적용할까요?" 같은 단계 간 진행 확인 질문을 하지 않는다 (Claude Code 시스템 프롬프트의 default confirm 본능을 override하는 명시적 instruction).

단, 호출되는 하위 스킬이 자체 계약상 사용자 판단이나 중단을 요구하는 경우는 그 계약을 우선한다:

- split PRD에서 다음 phase가 `Pending phase-start approval` 상태이면 [`./output-templates.md#phase-start-materialization-gate-packet`](./output-templates.md#phase-start-materialization-gate-packet)의 승인 표면을 먼저 제시한다. 이는 단계 간 진행 확인 질문이 아니라, 새 phase durable body와 phase-scoped 자동 수행 범위를 승인받는 필수 신뢰 경계다.
- split PRD에서는 모든 phase가 materialized 되고 phase-end PRD sync가 커밋된 뒤 [`./output-templates.md#final-closeout-gate-packet`](./output-templates.md#final-closeout-gate-packet)의 final review gate를 먼저 제시한다. 이 gate 전에는 `PI-FINAL-REVIEW`, `PI-FOLLOWUP-COMMIT`를 수행하지 않는다. follow-up commit까지 끝나 final diff가 고정된 뒤 final PR write gate를 제시하며, 이 gate 전에는 `PI-CREATE-PR`를 수행하지 않는다.
- `/run-da`의 중단·질문·불안정 판정·위임 대체 조건은 [`../../run-da/references/hardening-contract.md`](../../run-da/references/hardening-contract.md)와 [`../../run-da/references/protocol.md`](../../run-da/references/protocol.md)를 따른다.
- `/parallel-audit`의 조율·중단·결과 처리 정책은 [`../../parallel-audit/SKILL.md`](../../parallel-audit/SKILL.md)를 따른다.
- DA Arbiter가 진행 차단급 결함을 확정하면 멈춘다.
- 동일 finding이 3회 연속 반복되면 무한 루프 방지를 위해 사용자 판단을 요청한다.
- 사용자가 명시적으로 "stop"을 지시하면 즉시 멈춘다.

## 7단계

| 순서 | Stable step ID | 수행 내용 | 최소 의존성 |
|------|----------------|-----------|-------------|
| 1 | PI-IMPLEMENT | 변경 구현 | 없음 |
| 2 | PI-COMMIT | 구현 커밋 — `/run-da for_pr`의 DA 입력 checkpoint. 기계적 변경(flake.lock 등)이 포함되면 `git diff main...HEAD -- ':!flake.lock'`로 축약 diff 사용. | PI-IMPLEMENT |
| 3 | PI-RUN-DA | `/run-da for_pr` 코드 DA 피드백 루프 | PI-COMMIT |
| 4 | PI-PARALLEL-AUDIT | `/parallel-audit` 전수조사 | PI-RUN-DA |
| 5 | PI-FINAL-REVIEW | Final Multi-Pass Review ([`./prd/multi-pass-review.md`](./prd/multi-pass-review.md)) | PI-PARALLEL-AUDIT |
| 6 | PI-FOLLOWUP-COMMIT | 10-pass 반영 커밋 (수정 발생 시) | PI-FINAL-REVIEW |
| 7 | PI-CREATE-PR | `/create-pr` — main 브랜치 대상 PR 생성. split final PR write gate에서는 gate 전 `/create-pr prepare`, 승인 후 `/create-pr apply-approved`를 사용 | PI-FINAL-REVIEW; PI-FOLLOWUP-COMMIT when review changes exist |

Approval-surface default display string:
`Post-Implementation 자동 수행: PI-IMPLEMENT, PI-COMMIT, PI-RUN-DA, PI-PARALLEL-AUDIT, PI-FINAL-REVIEW, PI-FOLLOWUP-COMMIT, PI-CREATE-PR (default)`

Split-file PRD의 phase-scoped/final closeout stable step ID, dependency closure, remediation chain, resume semantics는 [`./resume-state.md#for_prd-prd-작성-후-next-blocking-step`](./resume-state.md#for_prd-prd-작성-후-next-blocking-step)이 canonical SSOT다. 사용자에게 보여줄 승인 packet 형식은 [`./output-templates.md#phase-start-materialization-gate-packet`](./output-templates.md#phase-start-materialization-gate-packet)과 [`./output-templates.md#final-closeout-gate-packet`](./output-templates.md#final-closeout-gate-packet)을 따른다. 이 문서는 공통 7단계 실행 순서와 신뢰 경계만 정의한다.

Final Multi-Pass Review는 메인 에이전트가 직접 수행한다 (fan-out 금지; `run-da` 4-bundle과 축 구분 — Cross-Phase Integration, Validation 선택, Documentation, PRD Closeout은 run-da가 커버하지 않는 영역).

- **for_prd 모드 추가**: 상세는 [`./task-size-routing.md#review-impl-통합-시점`](./task-size-routing.md#review-impl-통합-시점)이 SSOT (요약: phase-end는 PRD 10-pass + 6-classification 둘 다, Final은 PRD 10-pass + review-impl overlay(6-classification 라벨링 + overbuilt 우선), auto-fix 미사용).
- **PRD Closeout 항목**: 작업 입력 또는 현재 diff에 `.claude/prds/` 파일이 포함된 경우에만 수행. **`for_prd` 모드는 산출물 경로가 `.claude/prds/`이므로 PRD Closeout 자동 활성화** — `for_action` 단순 plan 작업에서만 항목 skip + 스킵 근거 기록.

승인 표면의 생략 항목은 위 표의 최소 의존성을 깨뜨리면 안 된다. 생략 요청이 의존성을 깨뜨리면 dependency closure를 적용한 최종 stable step ID 목록을 다시 사용자에게 노출하고 승인받는다.

## 신뢰 경계 (#569 회귀 방지)

계획/PRD 승인 gate는 승인 표면에 표시된 stable step ID와 자동 수행 범위에 대한 사용자 동의로 간주된다. tracked write·commit·GitHub PR write는 해당 gate의 표시 범위에 포함된 경우에만 승인된다. 단:

- 메인 LLM은 본 7단계 중 어떤 단계도 자체 판단으로 생략하지 않는다 (#453 회귀 방지). "범위 대비 비용 과도" 같은 메인 LLM 자체 판단은 사용자 stop 지시가 아니다.
- 단계 생략은 (a) 사용자 명시 stop, (b) 하위 스킬 canonical contract가 요구하는 중단/질문 조건, (c) 승인 표면에 명시된 자동 수행 범위의 생략 항목(for_action: plan Step 8, for_prd: Step 7 gate, phase-start materialization gate, final review gate, final PR write gate의 범위) — 셋 중 하나에만 가능하다.
