# Phase 3: Hook Registration

Parent PRD: [PRD: Session Handoff Automation](../prd-session-handoff-automation.md)
Status: Not Started
Last Updated: 2026-05-05

## Objective

Phase 2에서 작성한 helper + 4 script를 Claude `settings.json` + Codex `_stop-dispatcher.sh` + `config.toml` + nix module(`claude/default.nix`, `codex/default.nix`)에 등록한다. DEC-S10 H2 ordering + DEC-S11 Claude Stop 위치를 적용하고 dispatcher 헤더 주석에 ordering rationale을 명시한다.

## Context From Master PRD

- Goals covered: G-1 (수동 단계 제거), G-2 (cross-runtime), G-3 (cross-machine).
- Success Criteria: SC-1, SC-2, SC-3 (모든 시나리오에서 hook이 발화하려면 등록이 정상 동작).
- Requirements covered: FR-1 (SessionStart 발화), FR-2 (Claude Stop), FR-3 (Claude SessionEnd), FR-4 (Codex Stop dispatcher 분기), NFR-2 (cross-runtime 일관성).
- Key scenarios touched: 모든 시나리오 (등록 없으면 아무것도 발화 안 함).

## Phase Discovery Gate

코드 편집 전에 재확인한다:
- [ ] 관련 코드/파일: `modules/shared/programs/claude/files/settings.json` (특히 Stop/SessionEnd/SessionStart 섹션), `modules/shared/programs/codex/files/config.toml`, `modules/shared/programs/codex/files/hooks/_stop-dispatcher.sh`, `modules/shared/programs/claude/default.nix` (mkOutOfStoreSymlink 패턴), `modules/shared/programs/codex/default.nix` (Codex 사본 symlink 패턴)
- [ ] 관련 테스트/fixture: `tests/test-codex-hook-fixtures.sh` (config.toml hook entry 보존 검증), `tests/test-handoff-hooks.sh`
- [ ] 관련 docs/spec/외부 참조: epic #584 (Codex 사본 정책 + dispatcher pattern), issue #590 (Stop ordering rationale), issue #591 (sync-codex-config user entry append 한계 — NG-6)
- [ ] 관련 command 또는 도구: `nrs` (build + apply), `nix eval`, `lefthook run` (eval-tests, ai-skills-consistency, codex-hook-fixtures)
- [ ] Master PRD의 DEC-S10 H2 + DEC-S11 ordering 결과가 Phase 1에서 확정됨
- [ ] 발견 사항이 후속 phase를 바꾸면 PRD 파일을 먼저 갱신

## Scope

### In Scope
- `modules/shared/programs/claude/files/settings.json`:
  - `Stop` chain에 `~/.claude/hooks/handoff-stop.sh` 추가 (DEC-S11 위치)
  - `SessionEnd`에 `~/.claude/hooks/handoff-session-end.sh` append
  - `SessionStart`에 `~/.claude/hooks/handoff-session-start.sh` append (기존 `session-init-icons.sh` 옆)
- `modules/shared/programs/codex/files/hooks/_stop-dispatcher.sh`:
  - 새 ordering 적용: `record-last-stop` → `nrs-session-cleanup` → `handoff-stop` → `stop-notification`
  - 헤더 주석 갱신: H2 위치 rationale (lock 해제 후 안정 상태에서 metadata 작성, notification 전이라 latency 영향 없음, idle heuristic 위치, dispatcher가 ordering shim임을 유지)
- `modules/shared/programs/codex/files/config.toml`:
  - `[[hooks.SessionStart]]` template-declared 추가 (`$HOME/.codex/hooks/handoff-session-start.sh`)
  - SessionEnd는 미지원이라 미등록
- `modules/shared/programs/claude/default.nix`:
  - `~/.claude/hooks/handoff-stop.sh`, `handoff-session-end.sh`, `handoff-session-start.sh`, `handoff-lib.sh` 4개 mkOutOfStoreSymlink 선언
- `modules/shared/programs/codex/default.nix`:
  - `~/.codex/hooks/handoff-stop.sh`, `handoff-session-start.sh`, `handoff-lib.sh` 3개 mkOutOfStoreSymlink 선언 (SessionEnd 미지원)

### Out of Scope
- gitleaks inline scan code (Phase 4)
- PR diff 제외 정책 (Phase 4)
- dogfooding round-trip (Phase 5)
- write-handoff skill 처리 (Phase 6)

## Implementation Checklist

- [ ] `settings.json` Stop chain에 `handoff-stop.sh` 추가 — DEC-S11 결정 위치 (예: `record-last-stop → handoff-stop → stop-notification → nrs-session-cleanup` 또는 다른 위치, Phase 1 결과에 따라)
- [ ] `settings.json` SessionEnd에 `handoff-session-end.sh` append (기존 `nrs-session-cleanup.sh` 보존)
- [ ] `settings.json` SessionStart에 `handoff-session-start.sh` append (기존 `session-init-icons.sh` 보존, 양쪽 hook 모두 발화)
- [ ] `_stop-dispatcher.sh`에 `handoff-stop.sh` 호출 추가 — H2 위치, 헤더 주석에 새 ordering rationale 명시 (record-last-stop 첫째 + nrs-session-cleanup 후 안정 상태 + handoff-stop H2 + stop-notification 마지막)
- [ ] `config.toml`에 `[[hooks.SessionStart]]` block 추가 — `command = "$HOME/.codex/hooks/handoff-session-start.sh"`
- [ ] `claude/default.nix`에 4 symlink 선언 (handoff-stop, handoff-session-end, handoff-session-start, handoff-lib)
- [ ] `codex/default.nix`에 3 symlink 선언 (handoff-stop, handoff-session-start, handoff-lib)
- [ ] `nrs` 실행으로 build + apply. `~/.claude/hooks/handoff-*.sh` + `~/.codex/hooks/handoff-*.sh` symlink 검증

## Validation Strategy

본 phase는 declarative 변경(settings.json, config.toml, default.nix)이다. risk: nix eval 실패, hook entry 누락, ordering 회귀, sync-codex-config가 template entry를 덮어씀. 따라서 (a) `nix eval`로 module 통과 확인 (b) `nrs` 실측 build (c) lefthook eval-tests + ai-skills-consistency + codex-hook-fixtures 통과 확인 (d) 실제 hook 발화 manual smoke (단순 echo로 시작점만 검증, 실제 동작은 Phase 5 dogfooding).

## Validation Checklist

- [ ] Static check: `nix eval .#darwinConfigurations.<host>.system 또는 .#nixosConfigurations.<host>.system` (worktree에서 가능 시), `shellcheck modules/shared/programs/codex/files/hooks/_stop-dispatcher.sh`
- [ ] 자동 test: `lefthook run pre-commit` (또는 명시적으로 `eval-tests`, `ai-skills-consistency`, `codex-hook-fixtures` 단독 실행)
- [ ] API/CLI workflow: `nrs` 빌드 후 `~/.claude/hooks/handoff-*.sh` + `~/.codex/hooks/handoff-*.sh` symlink 존재 확인
- [ ] Browser/UI E2E: N/A
- [ ] Agent/dev browser: N/A
- [ ] Mobile/app simulator: N/A
- [ ] Visual/screenshot: N/A
- [ ] Observability/logging: hook 발화 시 `~/.claude/hooks/.last-handoff-stop.log` (또는 유사) 같은 진단 로그 작성 (Phase 2 helper에서 구현)
- [ ] Manual smoke check: Claude Code 세션 1회 진입 + 종료 → SessionStart/SessionEnd hook이 발화 (snapshot 작성은 Phase 4 미적용이므로 dummy 동작 확인만)
- [ ] Error/empty/permission/retry/rollback: nix eval 실패 시 메시지, sync-codex-config가 template entry 보존 확인 (issue #591 한계 NG-6 — user entry는 보존 안 됨, 단 template entry는 보존)

## Exit Criteria

- [ ] Phase objective 달성 (settings.json + config.toml + dispatcher + nix module 모두 등록 완료)
- [ ] FR-1, NFR-2 만족 (양쪽 runtime에서 hook 발화)
- [ ] Validation Checklist 완료
- [ ] `nrs` 빌드 통과 + symlink 검증
- [ ] 기존 hook(record-last-stop, nrs-session-cleanup, stop-notification, session-init-icons)이 회귀 없이 동작

## Phase-End Multi-Pass Review

다음 phase로 이동하기 전 순서대로 완료한다:
- [ ] 1. Intent/coverage review — 모든 FR-1/NFR-2 매핑 항목이 등록됨
- [ ] 2. Correctness review — settings.json/config.toml syntax 정확, dispatcher ordering 정확, symlink 모두 존재
- [ ] 3. Simplicity review — declarative 변경에 불필요한 추상화 없음
- [ ] 4. Code quality review — dispatcher 헤더 주석에 ordering rationale 충실, symlink 선언 패턴 일관
- [ ] 5. Duplication/cleanup review — 기존 hook과 신규 hook ordering 충돌 없음
- [ ] 6. Security/privacy review — settings.json/config.toml 변경이 secret/PII에 영향 주지 않음 (실제 차단은 Phase 4)
- [ ] 7. Performance/load review — Stop chain 길이 증가에 따른 latency 영향 측정 (Stop=metadata-only는 < 500ms 유지)
- [ ] 8. Validation review — lefthook + nix eval + nrs build 모두 risk를 커버
- [ ] 9. Future-phase review — Phase 4의 gitleaks staged ordering이 본 phase의 hook 위치와 일치
- [ ] 10. PRD sync review — master PRD `Document Status`, `Change Log`, Phase Index의 Phase 3 Status 갱신

## Discoveries / Decisions

- (작성 예정 — Phase 3 진행 중 evidence 누적)

## Phase Change Log

- 2026-05-05: Phase file created (split mode 동시 생성).
