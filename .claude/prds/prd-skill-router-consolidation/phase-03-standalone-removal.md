# Phase 3: Standalone Removal + Claude SoT

Parent PRD: [PRD: Skill Router Consolidation](../prd-skill-router-consolidation.md)
Status: Not Started
Last Updated: 2026-05-01

## Objective

standalone `/prd`, `/review-implementation` SKILL.md + evals/queries.json + 빈 디렉토리를 모두 제거한다 (DL-3). `claude/default.nix:236-240`의 두 symlink declaration도 함께 제거한다. nrs 빌드 후 `~/.claude/skills/{prd,review-implementation}` symlink가 사라지는지 확인한다.

본 phase는 단일 commit (Commit 2)으로 처리한다. Codex 측 SoT(`codex/default.nix`, `verify-ai-compat.sh`) 갱신은 Phase 4 담당.

## Context From Master PRD

- Goals covered: G-3 (standalone 완전 제거)
- Success Criteria: SC-3 (디렉토리 부재 + symlink 부재), SC-4 (claude/default.nix 갱신)
- Requirements covered: FR-1, FR-2, FR-5
- Decisions: DL-3, DL-7

## Phase Discovery Gate

코드 편집 전에 재확인한다:
- [ ] Phase 2가 완료되어 standalone references가 비어 있음 확인 (`ls modules/shared/programs/claude/files/skills/{prd,review-implementation}/references/` 빈 디렉토리).
- [ ] `cat modules/shared/programs/claude/files/skills/prd/SKILL.md` 마지막 read (삭제 전 백업 필요 없음 — git history에서 복원 가능).
- [ ] `cat modules/shared/programs/claude/files/skills/prd/evals/queries.json` 마지막 read.
- [ ] `cat modules/shared/programs/claude/files/skills/review-implementation/SKILL.md` 마지막 read.
- [ ] `cat modules/shared/programs/claude/files/skills/review-implementation/evals/queries.json` 마지막 read.
- [ ] `sed -n '230,245p' modules/shared/programs/claude/default.nix` — 정확한 4-5줄 (line 236-240) 삭제 단위 식별.
- [ ] `ls -la ~/.claude/skills/prd ~/.claude/skills/review-implementation` 현재 symlink 존재 확인 (nrs 후 부재 검증의 baseline).
- [ ] Phase 2 commit이 존재하고 working tree clean 확인.

## Scope

### In Scope

- standalone SKILL.md 4 파일 (실은 2 파일 — `prd/SKILL.md`, `review-implementation/SKILL.md`) git rm.
- standalone evals/queries.json 2 파일 git rm.
- 빈 디렉토리 6개 rmdir (`prd/evals`, `prd/references`, `prd`, `review-implementation/evals`, `review-implementation/references`, `review-implementation`).
- `claude/default.nix:236-240` declaration 2개 제거.
- nrs 빌드 + symlink 부재 확인 (메인 에이전트 직접 실행).

### Out of Scope

- codex/default.nix exposedCodexSkills 갱신 (Phase 4).
- verify-ai-compat.sh EXPECTED_EXPOSED 갱신 (Phase 4).
- plan-with-questions trigger 흡수 (Phase 4).
- run-da link 갱신 (Phase 5).

## Implementation Checklist

- [ ] `git rm modules/shared/programs/claude/files/skills/prd/SKILL.md`.
- [ ] `git rm modules/shared/programs/claude/files/skills/prd/evals/queries.json`.
- [ ] `rmdir modules/shared/programs/claude/files/skills/prd/evals`.
- [ ] `rmdir modules/shared/programs/claude/files/skills/prd/references`.
- [ ] `rmdir modules/shared/programs/claude/files/skills/prd`.
- [ ] `git rm modules/shared/programs/claude/files/skills/review-implementation/SKILL.md`.
- [ ] `git rm modules/shared/programs/claude/files/skills/review-implementation/evals/queries.json`.
- [ ] `rmdir modules/shared/programs/claude/files/skills/review-implementation/evals`.
- [ ] `rmdir modules/shared/programs/claude/files/skills/review-implementation/references`.
- [ ] `rmdir modules/shared/programs/claude/files/skills/review-implementation`.
- [ ] `modules/shared/programs/claude/default.nix` Edit: line 234-240의 `# prd 스킬 ... ` + `.claude/skills/prd ...` + `# review-implementation 스킬` + `.claude/skills/review-implementation ...` declaration 모두 제거 (주석 포함).
- [ ] `git diff modules/shared/programs/claude/default.nix` 확인 — 정확히 declaration 2개만 삭제, 다른 declaration 영향 없음.
- [ ] commit 메시지: `feat(skills): remove standalone prd/review-implementation skills (#611)`. body에 DL-3, DL-7 인용.
- [ ] `nrs` 실행 (메인 에이전트 직접 — main-agent-only command).
- [ ] nrs 성공 후 `test ! -e ~/.claude/skills/prd && test ! -e ~/.claude/skills/review-implementation` 통과.

## Validation Strategy

git 삭제는 명확하지만 nrs 빌드 후 symlink 부재 검증이 핵심. ai-skills-consistency hook 자동 실행 + verify-ai-compat.sh는 Phase 4 후 검증.

- **git diff 검증**: `git diff --stat HEAD~1` — 2 SKILL.md + 2 evals/queries.json + claude/default.nix(4-5줄) 삭제.
- **rmdir 결과**: `ls modules/shared/programs/claude/files/skills/{prd,review-implementation}` → no such directory.
- **nrs 빌드**: 메인 에이전트가 `nrs` 실행. 성공 시 home-manager activation으로 symlink 제거.
- **명시 test**: `test ! -e ~/.claude/skills/prd && test ! -e ~/.claude/skills/review-implementation` (DL-13).
- 이 phase에서는 codex 측 ~/.codex/skills 부재 검증은 Phase 4 후 (codex/default.nix 갱신 후).

## Validation Checklist

- [ ] Static check: `ls modules/shared/programs/claude/files/skills/{prd,review-implementation}` → no directory.
- [ ] 자동 test (lefthook commit hook): `gitleaks`, `nixfmt` (claude/default.nix), `eval-tests` 통과 (commit 시 자동).
- [ ] API/CLI/service-level: `nrs` 실행 성공.
- [ ] Browser/UI E2E: N/A.
- [ ] Agent/dev browser: N/A.
- [ ] Mobile/simulator: N/A.
- [ ] Visual/screenshot: N/A.
- [ ] Observability: N/A.
- [ ] Manual smoke: `test ! -e ~/.claude/skills/prd` 통과.
- [ ] error/empty/loading/permission/retry/rollback: nrs 실패 시 git revert 후 nrs 재실행 (rollback 절차).

## Exit Criteria

- [ ] 4 git rm + 6 rmdir + claude/default.nix 갱신 완료.
- [ ] commit 1개 생성 (Commit 2).
- [ ] nrs 빌드 성공.
- [ ] `~/.claude/skills/{prd,review-implementation}` symlink 부재.
- [ ] 다음 phase blocker 없음.

## Phase-End Multi-Pass Review

- [ ] 1. Intent/coverage review — FR-1/2/5 매핑.
- [ ] 2. Correctness review — `rmdir`이 빈 디렉토리만 제거 (Phase 2가 references 모두 이동). git rm이 두 SKILL.md + 두 evals/queries.json 정확히.
- [ ] 3. Simplicity review — `git rm` + `rmdir` + claude/default.nix Edit. 복잡 logic 없음.
- [ ] 4. Code quality review — claude/default.nix Edit이 다른 declaration 영향 없는지 확인.
- [ ] 5. Duplication/cleanup review — 빈 디렉토리 모두 정리.
- [ ] 6. Security/privacy review — secret/auth 노출 없음. 디렉토리 제거가 sandbox 경계 침해 없음.
- [ ] 7. Performance/load review — nrs 빌드 시간 baseline과 큰 차이 없음 확인.
- [ ] 8. Validation review — `test ! -e` 명시 test가 symlink 부재 강제 검증.
- [ ] 9. Future-phase review — Phase 4 (codex SoT)가 본 phase 후 ~/.claude/skills/{prd,review-impl} 부재 가정. 일관성 확인.
- [ ] 10. PRD sync review — master PRD Phase 2 → Phase 3 갱신, Phase Index Status 업데이트.

추가로 `review-implementation/requirement-status.md` 6-classification 보조 layer 적용 (auto-fix 미사용).

## Discoveries / Decisions

(Phase 3 진행 중 발견사항 기록.)

## Phase Change Log

- 2026-05-01: Phase 3 file created via /prd handoff.
