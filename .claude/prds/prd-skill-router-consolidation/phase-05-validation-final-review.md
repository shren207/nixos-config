# Phase 5: Cross-Skill Link + Validation + Final Review

Parent PRD: [PRD: Skill Router Consolidation](../prd-skill-router-consolidation.md)
Status: Not Started
Last Updated: 2026-05-01

## Objective

cross-skill link를 갱신한다 — `run-da/SKILL.md:75`의 `validation-paths.md` 참조를 새 평면 위치로(`../plan-with-questions/references/validation-paths.md`)(DL-16, FR-11), `run-da/references/arbiter-prompt.md:192-196`의 `~/.claude/skills/prd` example을 갱신 또는 obsolete annotation(FR-12). 이후 lefthook eval-tests + ai-skills-consistency(보조) + verify-ai-compat.sh + run-eval.sh 모두 통과 + 명시 test + dogfooding round-trip 시나리오 검증을 수행한다. 마지막으로 parallel-audit + Final 10-pass + 9-pass review-only(auto-fix 미사용)를 수행한다.

본 phase는 코드 변경(Commit 4)과 검증 전용(Commit 5) 두 commit을 포함한다(DL-17).

## Context From Master PRD

- Goals covered: G-5 (lefthook 통과 + verify-ai-compat 통과)
- Success Criteria: SC-5 (lefthook 통과), SC-6 (dogfooding round-trip)
- Requirements covered: FR-11, FR-12, NFR-1~6
- Decisions: DL-13 (ai-skills-consistency 보조 강등), DL-16 (validation-paths 평면), DL-17 (Commit 5 검증 전용)

## Phase Discovery Gate

코드 편집 전에 재확인한다:
- [ ] Phase 4 완료 확인 (codex SoT + trigger 흡수 commit 머지 + nrs 빌드 성공 + verify-ai-compat.sh 통과).
- [ ] `sed -n '70,85p' modules/shared/programs/claude/files/skills/run-da/SKILL.md` — line 75 `validation-paths.md` link 정확한 위치 확인.
- [ ] `sed -n '185,205p' modules/shared/programs/claude/files/skills/run-da/references/arbiter-prompt.md` — line 192-196 example 4 line 정확한 위치 + 인용 형식 확인.
- [ ] **Open Question 결정**: arbiter-prompt.md example 갱신 vs obsolete annotation 채택. 단순화 권장 → obsolete annotation (`<!-- 본 example의 경로는 #611 흡수 후 obsolete. plan-with-questions/references/prd/ 또는 동등 위치 -->` 같은 inline 주석).
- [ ] `git status --porcelain` 빈 출력 (Phase 4 commit 후 working tree clean).
- [ ] 사용자 dogfooding 시나리오 design — 가상 이슈 ref 만들어 plan-with-questions for_prd 호출 → PRD 작성 → phase 진행 → Final review까지의 round-trip 시나리오 결정.

## Scope

### In Scope

- run-da/SKILL.md:75 link 갱신 (Commit 4).
- run-da/references/arbiter-prompt.md:192-196 example 갱신 또는 obsolete annotation (Commit 4).
- lefthook eval-tests + ai-skills-consistency(보조) + verify-ai-compat.sh + run-eval.sh 모두 통과 검증 (Commit 5).
- 명시 test (`test ! -e ~/.claude/skills/prd ...`).
- dogfooding round-trip 시나리오 수동 검증.
- parallel-audit (`/parallel-audit`) 실행.
- Final 10-pass (`prd/multi-pass-review.md` 이동 후 위치, `plan-with-questions/references/prd/multi-pass-review.md`) + 9-pass review-only (`review-implementation/requirement-status.md` 이동 후 위치).

### Out of Scope

- review-implementation auto-fix mode (NG-2 유지).
- 추가 advanced mode 기능 (DL-12).
- Post-Implementation 7번 PR 생성은 본 phase가 아니라 Post-Implementation 자동 흐름 (PRD master `Post-Implementation 자동 수행 범위` 따름).

## Implementation Checklist

- [ ] `modules/shared/programs/claude/files/skills/run-da/SKILL.md:75` Edit — `../prd/references/validation-paths.md` → `../plan-with-questions/references/validation-paths.md` (평면, DL-16).
- [ ] `modules/shared/programs/claude/files/skills/run-da/references/arbiter-prompt.md:192-196` Edit — example의 `~/.claude/skills/prd` 경로를 `~/.claude/skills/plan-with-questions/references/prd` 또는 obsolete annotation으로 갱신. 단순화 채택 시 obsolete annotation으로.
- [ ] commit 메시지: `refactor(skills): update run-da cross-skill links after prd absorption (#611)`. body에 DL-16 인용.
- [ ] `git commit` (Commit 4).
- [ ] **검증 단계 (Commit 5 — 코드 변경 없음)**:
  - [ ] `git status --porcelain` 빈 출력 확인.
  - [ ] static rg 확장 패턴 잔존 검증: `rg -n '(/prd|/review-implementation|prd/references|review-implementation|\.\./prd|\.\./\.\./prd)' modules/shared/programs/claude/files/skills/ scripts/ modules/shared/programs/codex/` → 의도적 잔존만 확인.
  - [ ] `bash tests/run-eval-tests.sh` 통과.
  - [ ] `bash scripts/ai/warn-skill-consistency.sh` 통과 (보조 검증).
  - [ ] `bash ./scripts/ai/verify-ai-compat.sh` 통과.
  - [ ] `bash ~/.claude/scripts/run-eval.sh --skill plan-with-questions --queries modules/shared/programs/claude/files/skills/plan-with-questions/evals/queries.json` 통과 (positive + negative + ambiguous).
  - [ ] `nrs` 빌드 성공.
  - [ ] 명시 test: `test ! -e ~/.claude/skills/prd && test ! -e ~/.claude/skills/review-implementation && test ! -e ~/.codex/skills/prd && test ! -e ~/.codex/skills/review-implementation` 통과.
  - [ ] dogfooding round-trip 시나리오: 가상 이슈 ref로 `/plan-with-questions for_prd` 호출 시뮬레이션 → for_prd 모드 진입 → 인터뷰 가능 → /prd handoff 가능 → phase 진행 가능.
  - [ ] `/parallel-audit` 실행 후 SAFE 결과.
  - [ ] Final 10-pass (`plan-with-questions/references/prd/multi-pass-review.md` 체크리스트) 모든 항목 PASS 또는 N/A skip 근거.
  - [ ] 9-pass review-only (`plan-with-questions/references/review-impl/requirement-status.md` 6-classification — auto-fix 미사용, NG-2) PRD master + 5 phase 파일 대상.
- [ ] eval 미세 조정 발견 시 Commit 3을 `git commit --amend` (DL-17). amend 후 Commit 5 재검증.
- [ ] commit 메시지 (Commit 5): `test(skills): validation pass after skill router consolidation (#611)`. body에 검증 결과 요약. **DL-17에 따라 검증 통과 후 코드 변경 없으면 빈 commit 안 만들고 Commit 4가 마지막 commit이 된다** — Commit 5 conditional, eval 미세 조정 amend 외에는 새 코드 변경 만들지 않음.

## Validation Strategy

본 phase는 검증 자체가 핵심. 모든 도구 검증 + 수동 dogfooding + parallel-audit + multi-pass review 통합.

- **static rg 확장**: stale link/prose 잔존 0 강제.
- **lefthook full**: pre-commit 모든 hook (eval-tests, ai-skills-consistency, gitleaks, nixfmt, shellcheck, codex-hook-fixtures) 통과.
- **verify-ai-compat.sh**: Codex global skill exposure SoT 정합.
- **run-eval.sh full**: skill-eval positive/negative/ambiguous case 통과.
- **nrs build**: NixOS/Darwin 양쪽 build 성공.
- **명시 test**: ~/.claude/skills + ~/.codex/skills 부재.
- **dogfooding**: 사용자 비전 (single entry point) 충실 검증.
- **parallel-audit**: 전수조사 + 사이드이펙트 검증.
- **Final 10-pass**: requirements coverage, cross-phase integration, correctness, simplicity, cleanup, security, performance, validation, documentation, **PRD closeout**.
- **9-pass review-only**: 6-classification (satisfied/partial/missing/conflicting/overbuilt/deferred) 통합.

## Validation Checklist

- [ ] Static check 통과: `rg` 잔존 0건.
- [ ] 자동 test 통과: lefthook all hooks PASS.
- [ ] API/CLI/service-level: verify-ai-compat.sh + run-eval.sh + nrs 모두 통과.
- [ ] Browser/UI E2E: N/A.
- [ ] Agent/dev browser: N/A.
- [ ] Mobile/simulator: N/A.
- [ ] Visual/screenshot: N/A.
- [ ] Observability: nrs 빌드 로그 확인.
- [ ] Manual smoke: dogfooding round-trip 시나리오 통과.
- [ ] error/empty/loading/permission/retry/rollback: lefthook 실패 시 fix → re-commit. nrs 실패 시 git revert. parallel-audit 실패 시 finding 반영 후 retry.

## Exit Criteria

- [ ] FR-11, FR-12 구현 완료 (Commit 4).
- [ ] 위 모든 Validation Checklist 통과.
- [ ] PRD master Status `Complete`로 갱신 + Phase Index 5개 phase Status `Complete`.
- [ ] Final 10-pass + 9-pass review-only 통합 보고서 (PRD master 또는 phase-05 본문에 inline).
- [ ] 다음 phase blocker 없음 (마지막 phase, Post-Implementation 7번 PR 생성으로 이어짐).

## Phase-End Multi-Pass Review

본 phase가 마지막 phase이므로 Phase-End 10-pass와 Final 10-pass가 통합. Final review는 본 phase Implementation Checklist 안에 포함.

- [ ] 1. Intent/coverage review — Master PRD G-1~6 모두 충족 (검증 결과로 증명).
- [ ] 2. Correctness review — happy path (사용자 비전 충실) + edge case (외부 LLM hallucination) + 권한 경계.
- [ ] 3. Simplicity review — 단일 PR + 5 commit. mode 추가 폐기로 표면 단순화.
- [ ] 4. Code quality review — link 갱신 일관 패턴. SKILL.md description 도구-중립.
- [ ] 5. Duplication/cleanup review — Phase 2~3에서 standalone 제거 + 빈 디렉토리 정리. plan-with-questions가 단일 owner.
- [ ] 6. Security/privacy review — main-agent-only 경계 유지. tracked write 권한 명확.
- [ ] 7. Performance/load review — skill discovery 시간 baseline 영향 없음.
- [ ] 8. Validation review — 모든 검증 도구 통과 (static + eval-tests + verify-ai-compat + run-eval + nrs + 명시 test + dogfooding + parallel-audit + multi-pass).
- [ ] 9. Future-phase review — N/A (마지막 phase). 후속 follow-up issue 필요 시 PR 본문에 명시.
- [ ] 10. **PRD closeout review** — PRD master Status `Complete`, Phase Index 5/5 `Complete`, change log 최신, follow-up 기록.

## Discoveries / Decisions

(Phase 5 진행 중 발견사항 + Final review 결과 기록.)

## Phase Change Log

- 2026-05-01: Phase 5 file created via /prd handoff.
