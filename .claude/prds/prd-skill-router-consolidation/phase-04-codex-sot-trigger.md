# Phase 4: Codex SoT + Trigger Absorption

Parent PRD: [PRD: Skill Router Consolidation](../prd-skill-router-consolidation.md)
Status: Not Started
Last Updated: 2026-05-01

## Objective

Codex 측 skill exposure SoT를 갱신한다 — `codex/default.nix:38-51`의 `exposedCodexSkills` list와 `scripts/ai/verify-ai-compat.sh:349-357`의 `EXPECTED_EXPOSED`에서 `"prd"`, `"review-implementation"` 두 entry 제거(DL-10). plan-with-questions의 흡수 trigger를 SKILL.md description + evals/queries.json (positive + negative + ambiguous case)에 추가한다(DL-15). advanced mode는 폐기(DL-12)이므로 추가하지 않고 for_prd 본문에 자연어 입력 가이드를 보완한다.

본 phase는 단일 commit (Commit 3)으로 처리한다.

## Context From Master PRD

- Goals covered: G-4 (trigger 흡수 + advanced mode 폐기), G-6 (Codex/Claude SoT 동기화)
- Success Criteria: SC-1 (positive case), SC-2 (negative case), SC-3 (~/.codex/skills 부재), SC-4 (codex SoT + verify-ai-compat.sh)
- Requirements covered: FR-6, FR-7, FR-8, FR-9, FR-13
- Decisions: DL-5, DL-10, DL-12, DL-15

## Phase Discovery Gate

코드 편집 전에 재확인한다:
- [ ] Phase 3 완료 확인 (~/.claude/skills/{prd,review-implementation} 부재).
- [ ] `sed -n '34,75p' modules/shared/programs/codex/default.nix` — exposedCodexSkills list 정확한 line 38-51 + 두 entry 위치 (line 45, 46) 확인.
- [ ] `sed -n '340,360p' scripts/ai/verify-ai-compat.sh` — EXPECTED_EXPOSED 배열 정확한 line + format 확인.
- [ ] `cat modules/shared/programs/claude/files/skills/plan-with-questions/SKILL.md` — description 현재 trigger 키워드 위치 + 빠른 참조 표 위치 + 모드 판별 표 위치 확인.
- [ ] `cat modules/shared/programs/claude/files/skills/plan-with-questions/evals/queries.json` — 기존 entry 31개 + "Living PRD 작성" entry (false→true 갱신 대상) 확인.
- [ ] `cat modules/shared/programs/claude/files/skills/plan-with-questions/modes/for_prd.md` — PRD 갱신·review-only 자연어 가이드 추가 위치 식별.
- [ ] **Open Question 결정**: 흡수 trigger positive 8-12개 + negative 4-6개 + ambiguous 2-3개의 정확한 query 목록 확정. 후보:
  - positive: `PRD 작성해줘`, `이 기능 PRD 만들어줘`, `PRD 업데이트`, `phase 계획 짜자`, `이 기능 스펙 정리`, `Living PRD 작성`, `Discovery Gate 있는 계획서`, `구현 감사 돌려줘`, `문서 대비 구현 리뷰`, `스펙 대비 감사`, `overbuilt 검사`, `PRD phase 완료 확인`.
  - negative: `PR 코멘트 처리해줘` (review-pr-feedback), `DA 피드백 돌려줘` (run-da), `전수조사 해줘` (parallel-audit), `직접 코드 작성해줘` (일반 implementation).
  - ambiguous: `이 기능 어떻게 할까`, `요구사항 정리해줘`.

## Scope

### In Scope

- codex/default.nix:38-51 두 entry 제거.
- verify-ai-compat.sh:349-357 두 entry 제거 (prd=line 356, review-implementation=line 357).
- plan-with-questions/SKILL.md description, 빠른 참조 표, 모드 판별 표 갱신.
- plan-with-questions/evals/queries.json positive 8-12 + negative 4-6 + ambiguous 2-3 추가, "Living PRD 작성" false→true.
- plan-with-questions/modes/for_prd.md 본문에 PRD 갱신·review-only 자연어 가이드 추가.
- nrs 빌드 + ~/.codex/skills/{prd,review-implementation} 부재 확인.

### Out of Scope

- run-da link 갱신 (Phase 5).
- run-da/arbiter-prompt.md example 갱신 (Phase 5).
- Final review (Phase 5).
- 흡수 trigger 정확한 query 목록 결정은 Discovery Gate에서 확정.

## Implementation Checklist

- [ ] `modules/shared/programs/codex/default.nix:38-51` Edit — `exposedCodexSkills` list에서 `"prd"` (line 45), `"review-implementation"` (line 46) 두 줄 제거.
- [ ] `scripts/ai/verify-ai-compat.sh:349-357` Edit — `EXPECTED_EXPOSED` 배열에서 `prd` (line 356) + `review-implementation` (line 357) 두 entry 제거. (sub-range 349-357 = 배열 시작 ~ review-implementation entry까지; 정확한 Edit 단위는 두 line.)
- [ ] `plan-with-questions/SKILL.md` **description frontmatter Edit (link는 Phase 2에서 이미 갱신, 본 phase는 description/표만)**: 흡수 trigger 추가 (PRD 작성, 구현 감사, 스펙 대비 감사, overbuilt 검사, Living PRD, phase 계획, PRD 업데이트, 문서 대비 구현 리뷰 등 12개).
- [ ] `plan-with-questions/SKILL.md` 모드 판별 표 — for_prd 트리거 키워드 보강 (PRD 작성·구현 감사 등 자연어 입력 자동 매칭).
- [ ] `plan-with-questions/SKILL.md` 빠른 참조 표 / 차용 reference 표 — Phase 2에서 link는 갱신됨. 본 phase에서는 표 헤더/본문 정합만 확인 (link 재변경 없음).
- [ ] `plan-with-questions/evals/queries.json` 갱신:
  - `Living PRD 작성` entry: should_trigger false→true, why="흡수 trigger: prd 영역 (DL-5/15)".
  - positive case 추가: `PRD 작성해줘`, `이 기능 PRD 만들어줘`, `PRD 업데이트`, `phase 계획 짜자`, `이 기능 스펙 정리`, `Discovery Gate 있는 계획서`, `구현 감사 돌려줘`, `문서 대비 구현 리뷰`, `스펙 대비 감사`, `overbuilt 검사`, `PRD phase 완료 확인` (총 11 positive + 기존 1 = 12).
  - negative case 추가: `PR 코멘트 처리해줘` (혼동 쌍 review-pr-feedback), `DA 피드백 돌려줘` (run-da), `전수조사 해줘` (parallel-audit), `직접 코드 작성해줘` (일반 implementation, plan-with-questions 아님).
  - ambiguous: `이 기능 어떻게 할까` (should_trigger:true, why="저항적: brainstorming → plan 전환 의미"), `요구사항 정리해줘` (should_trigger:true, why="명시적: 요구사항 파악").
- [ ] `plan-with-questions/modes/for_prd.md` 본문 — PRD 갱신·review-only 자연어 입력 처리 가이드 추가 (advanced mode 부재 보완, DL-12). 예: "기존 PRD 갱신 요청 시 사용자가 PRD 파일 경로를 ref로 제공하면 for_prd가 갱신 흐름으로 진입. review-only 직접 적용은 for_action Post-Implementation 5번에서 자연 처리."
- [ ] commit 메시지: `feat(skills): absorb prd/review-impl triggers into plan-with-questions + sync codex SoT (#611)`. body에 DL-5, DL-10, DL-12, DL-15 인용.
- [ ] `nrs` 재실행 (codex/default.nix 변경 반영). 메인 에이전트 직접.
- [ ] `test ! -e ~/.codex/skills/prd && test ! -e ~/.codex/skills/review-implementation` 통과.
- [ ] `bash ./scripts/ai/verify-ai-compat.sh` 통과.

## Validation Strategy

trigger 흡수의 routing 정합 + Codex SoT 정합 검증.

- **static**: `rg -n '"prd"|"review-implementation"' modules/shared/programs/codex/default.nix scripts/ai/verify-ai-compat.sh` → 0건.
- **eval-tests** (lefthook): `bash tests/run-eval-tests.sh` 자동 실행 (commit 시).
- **verify-ai-compat.sh**: `bash ./scripts/ai/verify-ai-compat.sh` — exposedCodexSkills + EXPECTED_EXPOSED 정합 검증.
- **run-eval.sh skill-eval**: `bash ~/.claude/scripts/run-eval.sh --skill plan-with-questions --queries modules/shared/programs/claude/files/skills/plan-with-questions/evals/queries.json` — positive 12개 통과, negative 4개 차단, ambiguous 2-3개 매치.
- **nrs 빌드**: 메인 에이전트가 nrs 실행. ~/.codex/skills/{prd,review-implementation} symlink 사라짐.
- **명시 test**: `test ! -e ~/.codex/skills/prd && test ! -e ~/.codex/skills/review-implementation` (DL-13).

## Validation Checklist

- [ ] Static check: `rg -n '"prd"|"review-implementation"' modules/shared/programs/codex/default.nix scripts/ai/verify-ai-compat.sh` → 0건.
- [ ] 자동 test: lefthook eval-tests 통과 (commit 시 자동).
- [ ] API/CLI/service-level: `bash ./scripts/ai/verify-ai-compat.sh` 통과. `bash ~/.claude/scripts/run-eval.sh --skill plan-with-questions --queries ...` 통과.
- [ ] Browser/UI E2E: N/A.
- [ ] Agent/dev browser: N/A.
- [ ] Mobile/simulator: N/A.
- [ ] Visual/screenshot: N/A.
- [ ] Observability: N/A.
- [ ] Manual smoke: `test ! -e ~/.codex/skills/prd` 통과. plan-with-questions/SKILL.md description trigger 키워드 수동 read 검증.
- [ ] error/empty/loading/permission/retry/rollback: rollback `git revert <commit-3>`.

## Exit Criteria

- [ ] codex/default.nix + verify-ai-compat.sh + plan-with-questions/SKILL.md + evals/queries.json + modes/for_prd.md 갱신 완료.
- [ ] commit 1개 생성 (Commit 3).
- [ ] nrs 빌드 성공.
- [ ] `~/.codex/skills/{prd,review-implementation}` symlink 부재.
- [ ] verify-ai-compat.sh 통과.
- [ ] eval-tests positive/negative/ambiguous case 모두 통과.
- [ ] 다음 phase blocker 없음.

## Phase-End Multi-Pass Review

- [ ] 1. Intent/coverage review — FR-6/7/8/9/13 매핑.
- [ ] 2. Correctness review — codex/default.nix 두 entry만 정확히 제거 (다른 entry 영향 없음). verify-ai-compat.sh도 동일.
- [ ] 3. Simplicity review — Edit 도구로 명확한 제거. trigger 추가는 description + evals 보강만.
- [ ] 4. Code quality review — plan-with-questions/SKILL.md description 도구-중립 용어 유지. evals query format 일관성 (기존 31 entry 패턴 따름).
- [ ] 5. Duplication/cleanup review — `Living PRD 작성` 중복 false 갱신.
- [ ] 6. Security/privacy review — secret 노출 없음. trigger 추가가 다른 skill과 routing 충돌 없는지 검증.
- [ ] 7. Performance/load review — eval-tests + verify-ai-compat.sh 실행 시간 baseline과 큰 차이 없음.
- [ ] 8. Validation review — positive + negative + ambiguous case 균형. routing 정합 강제.
- [ ] 9. Future-phase review — Phase 5 (cross-skill link)가 본 phase 후 SKILL.md 갱신 일관성 가정. 확인.
- [ ] 10. PRD sync review — master PRD Phase 3 → Phase 4 갱신.

추가로 `review-implementation/requirement-status.md` 6-classification 보조 layer 적용.

## Discoveries / Decisions

(Phase 4 진행 중 발견사항 기록.)

## Phase Change Log

- 2026-05-01: Phase 4 file created via /prd handoff.
