# Phase 1: Design Lock-in

Parent PRD: [PRD: Skill Router Consolidation](../prd-skill-router-consolidation.md)
Status: Not Started
Last Updated: 2026-05-01

## Objective

PR #612 머지 상태와 lefthook/eval/codex SoT 인프라 동작을 확인하고, Decision Log DL-1~16을 PRD master에 SSOT로 lock한다. 변경 대상 17 파일 + 디렉토리 6의 정확한 위치·라인을 확정하여 Phase 2~5의 변경 작업이 hallucination 없이 진행되도록 sealed baseline을 만든다.

## Context From Master PRD

- Goals covered: G-1~6 (lock-in이 모든 G의 전제)
- Success Criteria: SC-3, SC-4 (변경 대상 검증 baseline)
- Requirements covered: 모든 FR/NFR의 사실 baseline
- Key scenarios touched: Scenario 1, 2 (현재 standalone trigger 동작 baseline)

## Phase Discovery Gate

코드 편집 전에 재확인한다:
- [ ] `gh pr view 612 --json state,mergedAt,headRefName,baseRefName` — PR #612 state=MERGED, mergedAt=2026-05-01T05:52:07Z 확인.
- [ ] `git log --oneline -5` — main HEAD = f7c818b 확인.
- [ ] `cat lefthook.yml` — pre-commit hook 5개 (`ai-skills-consistency`, `gitleaks`, `nixfmt`, `shellcheck`, `eval-tests`, `codex-hook-fixtures`) 정의 확인.
- [ ] `cat tests/run-eval-tests.sh` — `nix eval --impure --file tests/eval-tests.nix` 호출 확인.
- [ ] `cat scripts/ai/warn-skill-consistency.sh` — `.claude/skills` ↔ `.agents/skills` 투영 비교 + `diff-filter=A` 신규 추가 확인 메커니즘 확인.
- [ ] `cat scripts/ai/verify-ai-compat.sh` — `EXPECTED_EXPOSED` 배열 위치 (line 349-357 부근) + `prd`, `review-implementation` entry 잔존 확인.
- [ ] `sed -n '34,75p' modules/shared/programs/codex/default.nix` — `exposedCodexSkills` list 위치 (line 38-51) + 두 entry (`"prd"`, `"review-implementation"`) 정확한 라인 확인.
- [ ] `sed -n '230,245p' modules/shared/programs/claude/default.nix` — claude declaration 위치 (line 236-240) + `mkOutOfStoreSymlink` 패턴 확인.
- [ ] `rg -n '../prd|../review-implementation|prd/references' modules/shared/programs/claude/files/skills/plan-with-questions/` — plan-with-questions 본인 link 갱신 대상 9 파일 확인 (DL-11).
- [ ] `rg -n '../prd|../review-implementation' modules/shared/programs/claude/files/skills/run-da/` — run-da의 link 갱신 대상 확인.
- [ ] PRD master Decision Log DL-1~16이 본 PRD에 SSOT로 기록됨 확인 (handoff seed `/tmp/plan-c54b0af3-611-lSbrfj/plan.md`와 일관성).
- [ ] 발견 사항이 이 phase 또는 후속 phase를 바꾸면, 구현 전에 PRD 파일을 먼저 갱신.

## Scope

### In Scope

- Discovery Gate 항목 모두 확인.
- 변경 대상 파일 목록의 정확한 라인 번호 확정.
- DL-1~16의 SSOT 검증.
- 본 phase는 코드 변경 없음 (Discovery + lock-in only).

### Out of Scope

- 실제 파일 이동/삭제/수정 (Phase 2~5 담당).
- 흡수 trigger 정확한 query 목록 결정 (Phase 4).
- run-da/arbiter-prompt.md example 갱신 vs obsolete annotation 결정 (Phase 5).

## Implementation Checklist

- [ ] Phase Discovery Gate 항목 모두 통과.
- [ ] PR #612 머지 검증 결과를 PRD master `Document Status` 섹션의 Baseline 필드에 기록 확인.
- [ ] lefthook.yml hook 정의 baseline 기록 (Phase 5 Validation에서 비교용).
- [ ] codex/default.nix:38-51 exposedCodexSkills의 정확한 entry 순서 + 라인 번호 baseline.
- [ ] scripts/ai/verify-ai-compat.sh의 EXPECTED_EXPOSED 배열 정확한 라인 + 형식 baseline.
- [ ] claude/default.nix:236-240 declaration 2개의 정확한 4-5줄 baseline (delete 단위 식별).
- [ ] plan-with-questions의 9 link 갱신 파일 목록 + 각 파일의 정확한 line 번호 매핑 확정.
- [ ] run-da/SKILL.md:75 + run-da/references/arbiter-prompt.md:192,195,196 정확한 위치 baseline.
- [ ] DL-1~16이 PRD master Decision Log에 모두 등장하는지 검증 (16개 entry 확인).

## Validation Strategy

본 phase는 검증 baseline 자체를 만드는 phase이므로 외부 도구 검증보다 self-consistency 검증 위주. 다음 도구로 PRD/plan 일관성 확인:

- `git status --porcelain` (clean 검증)
- `gh pr view 612 --json state,mergedAt` (PR 상태 검증)
- `rg -n` 명시 패턴 매칭 (변경 대상 위치 baseline)
- 본 PRD master 직접 read로 DL-1~16 SSOT 확인

## Validation Checklist

- [ ] Static check 통과 (가용 시): `git status --porcelain`이 빈 출력 (working tree clean)
- [ ] 자동 test 추가/갱신 및 통과 (해당 시): N/A — 본 phase는 baseline lock-in만
- [ ] API/CLI/service-level workflow 검증 (충분한 경우): `gh pr view 612` 상태 확인
- [ ] Browser/UI E2E — DOM/client 상호작용이 risk 경로일 때만 수행: N/A
- [ ] Agent/dev browser check: N/A
- [ ] Mobile/app simulator: N/A
- [ ] Visual/screenshot check: N/A
- [ ] Observability/logging/audit 동작 확인 (관련 시): N/A
- [ ] Manual smoke check: 본 PRD master read + Decision Log 16 entry counter check
- [ ] 해당 시 error, empty, loading, permission, retry, rollback 상태 검증: N/A

## Exit Criteria

- [ ] Phase objective 달성 (DL-1~16 SSOT lock + 변경 대상 baseline 확정)
- [ ] 위에 열거한 요구사항이 구현되었거나 명시적으로 deferred
- [ ] Validation checklist 완료 또는 gap이 근거와 함께 기록됨
- [ ] 다음 phase를 시작하지 못하게 막는 blocker 없음 (PR #612 main 머지 + working tree clean + DL 일관성 모두 통과)

## Phase-End Multi-Pass Review

다음 phase로 이동하기 전 순서대로 완료한다 (`prd/references/phase-template.md` 10-pass 정본):
- [ ] 1. Intent/coverage review — 본 phase가 objective와 매핑된 요구사항을 달성했다.
- [ ] 2. Correctness review — happy path, edge case (PR #612 미머지 시 대응), error 처리.
- [ ] 3. Simplicity review — 솔루션이 필요 이상으로 복잡하지 않다.
- [ ] 4. Code quality review — 본 phase는 코드 변경 없음, baseline 기록만.
- [ ] 5. Duplication/cleanup review — N/A (코드 변경 없음).
- [ ] 6. Security/privacy review — Discovery Gate 항목이 secret/auth 노출하지 않음 확인.
- [ ] 7. Performance/load review — N/A (Discovery only).
- [ ] 8. Validation review — 선택한 check가 phase risk에 적절. baseline lock-in이라 도구 검증보다 self-consistency 위주.
- [ ] 9. Future-phase review — Phase 2~5 파일이 Phase 1 baseline과 일치하는지 확인.
- [ ] 10. PRD sync review — master PRD status, active phase, baseline, change log 갱신 확인.

추가로 `review-implementation/requirement-status.md` 6-classification 보조 layer 적용 (Phase-end 통합, NG-2로 auto-fix 미사용).

## Discoveries / Decisions

(Phase 1 진행 중 발견사항 기록. PRD master Decision Log에 영향 시 새 DL 추가 또는 기존 DL supersede.)

## Phase Change Log

- 2026-05-01: Phase 1 file created via /prd handoff from plan-with-questions for_prd.
