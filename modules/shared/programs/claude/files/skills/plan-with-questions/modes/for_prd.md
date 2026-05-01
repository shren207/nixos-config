# Mode: for_prd

**Status**: stub (Phase 4에서 본문 채움)

이 파일은 Phase 1 progressive disclosure 추출 시 stub으로 생성되었다. 실제 for_prd 모드 흐름은 본 plan-with-questions 개편의 Phase 4(`for_prd 모드 + 자동 트리거 + review-impl 통합`)에서 정의된다.

## 진입 조건 (예정)

- 자동 트리거: Phase ≥4 OR 다중 도메인 (`task-size-routing.md`).
- 사용자 명시 요청 (frontmatter `for_prd` 첫 토큰).
- `for_action` 진입 후 자동 후보 감지 + 사용자 1회 알림 + opt-out 통과.

## 차용 reference (예정, 직접 복제 금지)

- [`../../prd/references/prd-master-template.md`](../../prd/references/prd-master-template.md) — Document Status / Goals / FR/NFR / Phase Index
- [`../../prd/references/phase-template.md`](../../prd/references/phase-template.md) — Phase Discovery Gate / Implementation / Validation / Exit / Phase-end 10-pass
- [`../../prd/references/file-mode-selection.md`](../../prd/references/file-mode-selection.md) — Single vs Split mode
- [`../../prd/references/validation-paths.md`](../../prd/references/validation-paths.md) — Validation 10-path catalog
- [`../../prd/references/multi-pass-review.md`](../../prd/references/multi-pass-review.md) — Final 10-pass review
- [`../../review-implementation/`](../../review-implementation/) — phase 종료 시 6-classification (auto-fix 미사용)

## 산출물 경로

- `.claude/plans/<slug>.md` 또는 `.claude/plans/<slug>/` (Phase 4에서 file-mode-selection 차용 결정).
- 최종 결정은 [`plan-file-template.md`](../references/plan-file-template.md)에 명시 (Phase 3 산출물).

## Phase 4 implementation 진입 시 본 stub을 대체한다.
