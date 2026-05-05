# Phase 3: Output Templates and Runtime

Parent PRD: [PRD: plan-with-questions Question UX](../prd-pwq-question-ux.md)
Status: Not Started
Last Updated: 2026-05-05

## Objective

`references/output-templates.md` Step 4 / Step I-4 질문 패턴을 라운드당 1개 + user_facing layer 사용 의무 + 라벨 부착 조건 + hard rule + 라운드별 룰 매트릭스 인용으로 재작성한다. `references/runtime-boundaries.md`에 for_action·for_issue 라운드 정책 통일 단락 추가.

## Context From Master PRD

- Goals covered: G-1 (라운드당 1개), G-2 (user_facing), G-4 (judgment-first 평이)
- Success Criteria: SC-1, SC-2, SC-3
- Requirements covered: FR-1, FR-2 (사용자 노출 패턴), FR-4 (judgment-first 라벨 금지), FR-7 (hard rule)
- Key scenarios touched: Scenario 1, 2, 3

## Phase Discovery Gate

코드 편집 전에 재확인한다:
- [ ] 관련 코드/파일: `~/.claude/skills/plan-with-questions/references/output-templates.md`, `~/.claude/skills/plan-with-questions/references/runtime-boundaries.md`
- [ ] Phase 1, 2 산출물: `references/consulting-step.md` (schema, fallback, 합의 알고리즘), `SKILL.md` Invariant 7, `modes/for_action.md` Step 4 흐름
- [ ] 관련 docs/spec: 본 PRD master "라운드별 룰 매트릭스" 섹션 (Phase 1/2 결과 통합)
- [ ] 관련 command: `rg`
- [ ] Master PRD assumption 유효
- [ ] Phase 1/2 결과로 output-templates 패턴이 영향받으면 본 phase에서 반영

## Scope

### In Scope

- `references/output-templates.md` Step 4 / Step I-4 질문 패턴:
  - 라운드당 1개 강제 (FR-1).
  - user_facing layer 사용 의무 표시 규칙 (FR-2).
  - 라벨 부착 조건 + hard rule (FR-7).
  - judgment-first 라운드 라벨 부착 절대 금지 (FR-4).
  - 라운드별 룰 매트릭스 (일반 / 트레이드오프 / judgment-first / fallback A/B/C/D 5 종류) 인용.
- `references/runtime-boundaries.md`에 for_action·for_issue 라운드 정책 통일 단락 추가 (FR-1).

### Out of Scope

- `references/consulting-step.md` (Phase 1).
- `SKILL.md`, `modes/*` (Phase 2).
- `references/bias-measurement.md` (Phase 4).
- 다른 인터뷰 스킬 (NG-2).

## Implementation Checklist

- [ ] `references/output-templates.md` Step 4 / Step I-4 질문 패턴 섹션 — 라운드당 1개 강제 명시 + 단일 question 도구 호출 예시.
- [ ] `references/output-templates.md` 라벨 부착 조건 단락 — Phase 1 합의 알고리즘 인용 + hard rule (도구 default 무시 + 합의 미달 옵션 라벨 절대 금지).
- [ ] `references/output-templates.md` user_facing 표시 규칙 단락 — Phase 1 schema의 user_facing layer 인용. evaluation_matrix raw 값을 사용자에게 노출하지 않는다는 명시 규칙.
- [ ] `references/output-templates.md` judgment-first 라운드 단락 — 라벨 부착 절대 금지 + user_facing 평이 라벨만 사용.
- [ ] `references/output-templates.md` 라운드별 룰 매트릭스 (일반/트레이드오프/judgment-first/fallback) 표 인라인 또는 master PRD 인용.
- [ ] `references/runtime-boundaries.md` for_action·for_issue 라운드 정책 통일 단락 추가 — "두 모드 모두 라운드당 1개 강제. modes/* 본문 SSOT 따름."

## Validation Strategy

본 phase는 output-templates 패턴 + runtime-boundaries 규칙 변경이라 정적 grep + Phase 5 self-test가 적절.

- 정적 grep: `rg "라운드당 1개" ~/.claude/skills/plan-with-questions/references/output-templates.md` ≥ 1건.
- 정적 grep: `rg "user_facing" ~/.claude/skills/plan-with-questions/references/output-templates.md` ≥ 2건 (표시 규칙 + judgment-first 인용).
- 정적 grep: `rg "judgment-first 라운드 라벨" ~/.claude/skills/plan-with-questions/references/output-templates.md` ≥ 1건 (FR-4 명시).
- 정적 grep: `rg "Recommended" ~/.claude/skills/plan-with-questions/` → "허용 조건" 컨텍스트만 매칭, label에 직접 추가 없음 (SC-2).

## Validation Checklist

- [ ] Static check 통과: `rg "라운드당 1개" ~/.claude/skills/plan-with-questions/references/output-templates.md` ≥ 1건
- [ ] Static check 통과: `rg "user_facing" ~/.claude/skills/plan-with-questions/references/output-templates.md` ≥ 2건
- [ ] Static check 통과: `rg "judgment-first" ~/.claude/skills/plan-with-questions/references/output-templates.md` 등장 + 라벨 금지 단락 명시
- [ ] Static check 통과: `rg "Recommended" ~/.claude/skills/plan-with-questions/` → 허용 조건 컨텍스트만 (SC-2 직접 검증)
- [ ] Static check 통과: `rg "for_action.*for_issue.*통일" ~/.claude/skills/plan-with-questions/references/runtime-boundaries.md` 또는 동등 단락 존재
- [ ] 자동 test: N/A
- [ ] API/CLI workflow 검증: Phase 5 self-test
- [ ] Browser/UI E2E: N/A
- [ ] Manual smoke check: output-templates 패턴 read 후 다음 LLM이 패턴을 따라 질문할 수 있는지 확인 — 라운드별 룰 매트릭스가 명료한가?

## Exit Criteria

- [ ] Phase objective 달성 — output-templates Step 4/I-4 패턴 + runtime-boundaries 라운드 정책 통일
- [ ] FR-1 (output-templates 부분), FR-2 (사용자 노출 패턴), FR-4 (judgment-first 라벨 금지), FR-7 (hard rule) 구현
- [ ] Validation checklist 완료
- [ ] Phase 4 시작을 막는 blocker 없음

## Phase-End Multi-Pass Review

- [ ] 1. Intent/coverage — output-templates에 라운드당 1개 + user_facing + 라벨 조건 + judgment-first 라벨 금지 모두 반영
- [ ] 2. Correctness — 라운드별 룰 매트릭스 5 종류 (일반/트레이드오프/judgment-first/fallback A·B·C·D) 모두 다룸
- [ ] 3. Simplicity — output-templates 패턴이 Phase 1 schema 인용으로 단순화
- [ ] 4. Code quality — 패턴/표가 다음 LLM이 따라 적용 가능
- [ ] 5. Duplication/cleanup — 합의 알고리즘 본문 재복사 없이 phase 1 인용
- [ ] 6. Security/privacy — D4 hard rule + judgment-first 라벨 금지로 anti-anchoring 보호
- [ ] 7. Performance/load — N/A (인스트럭션)
- [ ] 8. Validation — 정적 grep + Phase 5 self-test 적절
- [ ] 9. Future-phase review — Phase 4 (bias-measurement metric)가 본 phase의 SC-2 기준 ("허용 조건 컨텍스트만")에 의존, 본 phase 결과 반영
- [ ] 10. PRD sync review — master PRD Phase Index Status `Phase 3` → `Complete`, `Active Phase File`을 phase-04로 갱신

## Discoveries / Decisions

(phase 진행 중 갱신)

## Phase Change Log

- 2026-05-05: Phase file created.
