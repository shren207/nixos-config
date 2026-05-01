# Task Size Routing — for_prd 자동 트리거

**Status**: stub (Phase 4에서 본문 채움)

이 reference는 plan-with-questions 개편의 Phase 4(`for_prd 모드 + 자동 트리거 + review-impl 통합`) 산출물이다.

## Phase 4에서 채울 내용

### 자동 트리거 신호 (사용자 답변 기준)

`for_action` Step 1-2 진행 중 다음 신호 1개 이상 감지 시 → `for_prd` 후보:

- **Phase ≥4**: 의존성 순서 phase가 4개 이상 필요 (file-mode-selection 차용 — `/prd` Single/Split 판정 룰).
- **다중 도메인**: data model + backend + frontend + migration + observability 등 2+ 동시 변경.

(보조 신호 — Phase 4 결정 시 채택 여부 판단):
- 예상 소요일 ≥1일 또는 'overhaul', '재설계', '아키텍처 변경' 키워드.
- 파일 변경 수 ≥10 또는 이슈 'epic'/'meta'/'roadmap' 레이블.

### opt-out 알림 메시지 + 옵션

[`output-templates.md`](./output-templates.md#for_prd-모드-자동-트리거-알림-메시지) 참조.

- default: PRD 모드 진행
- opt-out: for_action 모드 fallback

### PRD 모드 산출물 경로

- 단일: `.claude/plans/<slug>.md` + 14 metadata 필드 + phase 인라인.
- Split: `.claude/plans/<slug>/` + master + phase 파일 분리 (`/prd/references/file-mode-selection.md` 차용).

Phase 4에서 어느 쪽을 default로 할지, 어떤 기준으로 자동 split할지 결정.

### review-implementation 통합 시점

- **PRD 모드**: 각 phase 종료 시 6-classification (satisfied/partial/missing/conflicting/overbuilt/deferred) 체크. Final 단계에서 9-pass review.
- **일반 plan 모드**: Post-Implementation 5번 Final 10-pass만.
- **auto-fix 미사용**: review-implementation의 fix 모드는 차용하지 않는다.

## Phase 1 단계 임시 적용

Phase 4 구현 전까지는 메인 LLM이 Step 1-2 결과를 보고 직관적으로 PRD 후보 여부 판단 → 사용자에게 1회 알림 + opt-out. 자동 트리거 알고리즘 강제는 Phase 4 완료 후 적용된다.
