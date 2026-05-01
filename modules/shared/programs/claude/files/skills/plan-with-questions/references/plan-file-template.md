# Plan File Template (`.claude/plans/<slug>.md`)

**Status**: stub (Phase 3에서 본문 채움)

이 reference는 plan-with-questions 개편의 Phase 3(`plan-file-template + Resume From + Decision Log`) 산출물이다.

## Phase 3에서 채울 내용

### 14 Metadata 필드 (plan 상단 — Document Status)

- `Status` enum: Draft / Clarifying / Waiting On User / Approved / Implementing / Validating / Blocked / Complete / Superseded
- `Mode`: for_action / for_issue / for_prd
- `Source`: 이슈 ref 또는 텍스트 설명
- `Plan File`: self-referential path
- `Resume From` enum: 기계적 식별자 (상세는 [`resume-state.md`](./resume-state.md))
- `Last Completed Step`, `Current Phase`, `Phase Progress`, `Active Phase File` (PRD 모드만)
- `Last Updated`, `Baseline` (branch + HEAD + dirty hash)
- `External Consult` (Step 3.5 결과 요약 + decision_id list)
- `DA State` (Pre-DA / Round N / CONFIRMED / NEEDS_MORE_INFO)
- `Pending User Questions` (count + high-impact link)
- `Change Log` (날짜별 append-only)

### Decision Log (ADR 미니, plan 하단 별도 섹션)

- 사용처: 사용자 선택 번복, DA Round의 큰 설계 변경, 재개 시 baseline 변경, 중요 방향 전환.
- 형식: `## DL-N: [decision]` + Status (proposed/accepted/superseded) + Context + Decision + Consequences.
- Superseded 시 새 DL 추가 + 기존 DL Status 변경 (덮어쓰지 않음).

### 본문 구조

- Problem / Goals / Non-Goals / Success Criteria / Key Scenarios
- 변경 대상 파일 / 실행 순서 / 검증 방법 / 사이드이펙트 / 롤백
- Open Questions
- Post-Implementation 자동 수행 범위 (Step 9 승인 의미 노출)
- Decision Log (ADR 미니)
- Change Log

## Phase 1 단계 임시 적용

Phase 3 구현 전까지는 [`../modes/for_action.md`](../modes/for_action.md#step-8-계획-파일-작성-계획-추적-상태)의 "최소 포함 내용" 항목만 적용한다. 14 metadata 필드와 Decision Log는 Phase 3 완료 후 강제된다.
