# Phase 6: Cleanup + Follow-up Issues + PRD Closeout

Parent PRD: [PRD: Session Handoff Automation](../prd-session-handoff-automation.md)
Status: Not Started
Last Updated: 2026-05-05

## Objective

dogfooding 결과를 정리하고 본 PRD에서 다루지 않은 follow-up 항목을 별도 후속 이슈로 발행한다. 본 PRD Closeout(PRD 10-pass + review-impl overlay)을 수행하여 구현이 문서와 일치하는지 최종 검증한다.

## Context From Master PRD

- Goals covered: 모든 G가 Phase 5에서 검증되었으므로, 본 phase는 follow-up + closeout만.
- Success Criteria: 모든 SC가 Phase 5에서 측정되었으므로, 본 phase에서는 SC 미충족 항목을 follow-up 이슈로 분리.
- Requirements covered: 본 phase는 Open Questions 해소 + Closeout.
- Key scenarios touched: Phase 5 시나리오 9 결과를 follow-up 이슈에 인용.

## Phase Discovery Gate

코드 편집 전에 재확인한다:
- [ ] 관련 코드/파일: 본 PRD의 모든 phase 결과 (Discoveries / Decisions 섹션)
- [ ] 관련 테스트/fixture: `tests/test-handoff-hooks.sh`의 모든 fixture
- [ ] 관련 docs/spec/외부 참조: `~/.claude/skills/plan-with-questions/references/prd/multi-pass-review.md` (PRD 10-pass), `~/.claude/skills/plan-with-questions/references/review-impl/implementation-review.md` (review-impl overlay), `~/.claude/skills/plan-with-questions/references/review-impl/requirement-status.md` (6-classification taxonomy)
- [ ] 관련 command 또는 도구: `gh issue create` (follow-up 이슈 발행), `~/.claude/skills/run-da/SKILL.md`(`/run-da for_pr` Phase 5 직후 + Final review 시 호출)
- [ ] **Phase split**: 본 phase는 두 단계로 분리된다:
  - (a) Closeout review-only(`automated implementation closeout`): manual smoke 결과를 기다리지 않고 자동 가능. PRD 10-pass + review-impl overlay 중 evidence 무관 항목 + follow-up 이슈 사전 등록.
  - (b) Post-smoke completion: Phase 5 manual smoke 결과 도착 후 PRD Status=Complete + 마지막 follow-up issue body 갱신. Phase 1~5 모두 완료 상태가 전제.
- [ ] 발견 사항이 본 PRD를 바꾸면 마지막 master PRD 갱신 + Change Log 기록

## Scope

### In Scope
- **OQ-1 follow-up**: `/write-handoff` skill 자체의 처리 결정(폐기 vs advanced 잔존 vs 통합)을 별도 이슈로 발행. 본 PRD의 dogfooding 결과(Phase 5 시나리오 9 race + 1-2주 사용 패턴 관찰)를 evidence로 인용
- **OQ-2 follow-up**: multi-worktree key F1 → F2/F3 승격 검토를 별도 이슈로 발행 (dogfooding에서 race가 빈번하면). race 빈도 데이터를 Phase 5 Discoveries에서 인용
- **OQ-3 follow-up**: Codex SessionEnd가 향후 추가될 가능성 → upstream openai/codex tracking 이슈 등록 (PR 작성자가 별도 이슈로 트래킹할지 결정)
- **NG-6 노트**: sync-codex-config.py의 user entry append 한계(issue #591 OPEN)가 본 PRD 운영에 미치는 영향을 master PRD에 명시한 상태로 두고, follow-up 이슈와의 cross-reference만 추가
- **PRD Closeout — PRD 10-pass + review-impl overlay**: 본 PRD master + 6 phase 파일 + 구현 코드를 입력으로 `~/.claude/skills/plan-with-questions/references/prd/multi-pass-review.md`의 10-pass + `~/.claude/skills/plan-with-questions/references/review-impl/implementation-review.md` overlay(6-classification 라벨링 + overbuilt 우선 분류) 적용. auto-fix는 미사용 (NG-2 of plan-with-questions). 발견된 이슈는 메인 에이전트가 별도 승인 단계에서 처리하거나 follow-up issue로 deferred 기록
- **master PRD 최종 갱신**: Document Status를 `Complete`로 전환, Change Log에 closeout evidence 인용

### Out of Scope
- 코드 변경 (필요하면 별도 phase backport 또는 follow-up PR)
- 외부 cloud 서비스 통합 (NG-1)
- multi-user 협업 (NG-4)

## Implementation Checklist

- [ ] OQ-1 follow-up 이슈 발행 (`gh issue create`): 제목 후보 "skill: `/write-handoff` 폐기/advanced 잔존/통합 결정 (#614 dogfooding 후속)". 본문에 Phase 5 시나리오 9 race evidence + 1-2주 사용 패턴 관찰 결과
- [ ] OQ-2 follow-up 이슈 (필요 시): multi-worktree race가 dogfooding에서 빈번하면 발행. race 빈도 evidence + F2/F3 마이그레이션 후보 옵션
- [ ] OQ-3 upstream tracking (선택): Codex SessionEnd가 추가되면 DEC-S6 B(heuristic) → SessionEnd 직접 사용 마이그레이션 트래킹
- [ ] master PRD `Open Questions` → 발행한 follow-up 이슈 번호로 cross-reference 추가
- [ ] PRD Closeout — PRD 10-pass 수행:
  - 1. Intent/coverage / 2. Correctness / 3. Simplicity / 4. Code quality / 5. Duplication/cleanup / 6. Security/privacy / 7. Performance/load / 8. Validation / 9. Future-phase / 10. PRD sync 모두 패스
- [ ] PRD Closeout — review-impl overlay 적용:
  - 6-classification 라벨링: requirement → 구현 매핑(satisfied / partial / missing / conflicting / overbuilt / deferred). overbuilt 우선 분류
  - 발견된 issue는 메인 에이전트가 별도 승인 단계에서 처리하거나 follow-up issue로 deferred 기록 (auto-fix 미사용)
- [ ] master PRD `Document Status` → `Complete` 갱신
- [ ] master PRD `Change Log`에 closeout evidence 인용
- [ ] master PRD `Phase Index`의 모든 Phase Status `Complete`

## Validation Strategy

본 phase는 review-only + 이슈 발행 + 문서 갱신이 핵심이다. risk: closeout이 missing/partial requirement를 놓침, follow-up 이슈가 evidence 없이 발행되어 휘발됨. 따라서 (a) PRD 10-pass의 모든 항목을 master + 6 phase 파일에 적용 (b) review-impl overlay로 6-classification 라벨링 (c) follow-up 이슈에 dogfooding evidence 포함. 코드 변경 없으므로 unit/integration test는 N/A.

## Validation Checklist

- [ ] Static check: N/A (review only)
- [ ] 자동 test: N/A (review only). 단 PRD 10-pass review가 fixture를 통과한 상태에서 수행되어야 함
- [ ] API/CLI workflow: N/A
- [ ] Browser/UI E2E: N/A
- [ ] Agent/dev browser: N/A
- [ ] Mobile/app simulator: N/A
- [ ] Visual/screenshot: N/A
- [ ] Observability/logging: closeout 후 1-2주 사용 패턴 관찰을 위한 hook stderr/log 보존 정책 확인
- [ ] Manual smoke check: master PRD `Document Status`가 `Complete`이고 모든 phase가 `Complete`인 상태로 일관됨
- [ ] Error/empty/permission/retry/rollback: review에서 누락 발견 시 메인 에이전트의 처리 경로 명확

## Exit Criteria

- [ ] Phase objective 달성 (follow-up 이슈 발행 + PRD Closeout 완료)
- [ ] OQ-1, OQ-2(필요 시), OQ-3 모두 처리
- [ ] PRD 10-pass + review-impl overlay 통과
- [ ] master PRD `Document Status`가 `Complete`
- [ ] dogfooding 1-2주 사용 패턴 관찰을 위한 plan이 follow-up 이슈에 명시됨

## Phase-End Multi-Pass Review

본 phase는 Closeout 자체이므로, Phase-End 10-pass는 PRD 10-pass와 통합된다. 별도 phase-end review 대신 PRD 10-pass + review-impl overlay 결과를 본 phase의 review로 인정한다:
- [ ] 1. Intent/coverage — 모든 Goals/SC/FR/NFR이 구현 또는 명시적 deferred로 매핑
- [ ] 2. Correctness — happy path + edge case + abnormal termination 모두 dogfooding으로 검증
- [ ] 3. Simplicity — 솔루션 구조가 단순. 불필요한 layer 없음
- [ ] 4. Code quality — helper/wrapper 구조 일관, 헤더 주석 충실, dispatcher rationale 명시
- [ ] 5. Duplication/cleanup — Claude/Codex 사본 중복은 helper로 흡수, drift fixture가 잔존 중복만 검증
- [ ] 6. Security/privacy — 3 layer 차단 + dogfooding 시나리오 8 통과. 잔존 토큰 0건
- [ ] 7. Performance/load — Stop=metadata-only < 500ms, SessionEnd 비차단 (NFR-1)
- [ ] 8. Validation — 시나리오 1~9 + secret fixture corpus + idempotent fixture 모두 통과
- [ ] 9. Future-phase — N/A (마지막 phase)
- [ ] 10. PRD sync — master PRD + 6 phase 파일이 일관됨, Document Status = Complete

## Discoveries / Decisions

- (작성 예정 — Phase 6 진행 중 follow-up 이슈 번호 + Closeout 결과 누적)

## Phase Change Log

- 2026-05-05: Phase file created (split mode 동시 생성).
