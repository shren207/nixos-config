# Phase 3: Hook Registration

Parent PRD: [PRD: Session Handoff Automation](../prd-session-handoff-automation.md)
Status: Complete (nrs manual smoke만 Phase 5 통합)
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
- [x] 관련 코드/파일: settings.json + config.toml + _stop-dispatcher.sh + claude/default.nix + codex/default.nix
- [x] 관련 테스트/fixture: tests/test-codex-hook-fixtures.sh + tests/test-handoff-hooks.sh
- [x] 관련 docs/spec/외부 참조: epic #584 + issue #590 + issue #591
- [x] 관련 command 또는 도구: nrs build + nixfmt --check + JSON/TOML syntax check + shellcheck
- [x] Master PRD의 DEC-S10 H2 + DEC-S11 ordering 결과가 Phase 1에서 확정됨
- [x] 발견 사항이 후속 phase를 바꾸면 PRD 파일을 먼저 갱신

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

- [x] `settings.json` Stop chain에 `handoff-stop.sh` 추가 — DEC-S11 위치 `record-last-stop → handoff-stop → stop-notification → nrs-session-cleanup`
- [x] `settings.json` SessionEnd에 `handoff-session-end.sh` append (기존 `nrs-session-cleanup.sh` 보존)
- [x] `settings.json` SessionStart에 `handoff-session-start.sh` append (기존 `session-init-icons.sh` 보존)
- [x] `_stop-dispatcher.sh`에 `handoff-stop.sh` 호출 추가 — H2 위치 `record-last-stop → nrs-session-cleanup → handoff-stop → stop-notification`. 헤더 주석에 issue #614 ordering rationale 추가
- [x] `config.toml`에 `[[hooks.SessionStart]]` block 추가 — `command = "$HOME/.codex/hooks/handoff-session-start.sh"`
- [x] `claude/default.nix`에 4 symlink 선언 (handoff-lib, handoff-stop, handoff-session-end, handoff-session-start)
- [x] `codex/default.nix`에 3 symlink 선언 (handoff-lib, handoff-stop, handoff-session-start)
- [ ] `nrs` 실행 — 사용자 협조 필요 (host mutation, Post-Implementation 자동 수행 범위 외). Phase 5 dogfooding 시 manual로 nrs apply 후 `~/.claude/hooks/handoff-*.sh` + `~/.codex/hooks/handoff-*.sh` symlink 검증

## Validation Strategy

본 phase는 declarative 변경(settings.json, config.toml, default.nix)이다. risk: nix eval 실패, hook entry 누락, ordering 회귀, sync-codex-config가 template entry를 덮어씀. 따라서 (a) `nix eval`로 module 통과 확인 (b) `nrs` 실측 build (c) lefthook eval-tests + ai-skills-consistency + codex-hook-fixtures 통과 확인 (d) 실제 hook 발화 manual smoke (단순 echo로 시작점만 검증, 실제 동작은 Phase 5 dogfooding).

## Validation Checklist

- [x] Static check: `nixfmt --check` 두 default.nix 깨끗 + `shellcheck -S warning` _stop-dispatcher.sh 깨끗 + `bash -n` 모든 hook script OK
- [x] 자동 test: 본 phase commit 시 lefthook pre-commit이 gitleaks + ai-skills-consistency + shellcheck + eval-tests + codex-hook-fixtures 모두 실행. 회귀 fixture(test-handoff-hooks.sh) 16/16 PASS 유지
- [x] API/CLI workflow: settings.json + config.toml syntax 검증(JSON/TOML parsable) 통과
- [x] Browser/UI E2E: N/A
- [x] Agent/dev browser: N/A
- [x] Mobile/app simulator: N/A
- [x] Visual/screenshot: N/A
- [x] Observability/logging: helper의 stderr 진단 메시지(quarantine/non-blocking 등)로 충분. 별도 log 파일 미생성 (NFR-1 latency 영향 회피)
- [ ] Manual smoke check: nrs apply 후 Claude Code 세션 1회 진입 + 종료 → SessionStart/SessionEnd hook 발화 확인. **사용자 협조 필요** (host mutation은 자동 수행 범위 외). Phase 5 dogfooding 시나리오 1과 통합
- [x] Error/empty/permission/retry/rollback: settings.json/config.toml 파싱 실패 시 nrs eval 단계에서 차단. sync-codex-config 한계(NG-6 — user entry 미보존, template entry 보존)는 본 PRD 범위 내

## Exit Criteria

- [x] Phase objective 달성 (settings.json + config.toml + dispatcher + nix module 모두 등록 완료)
- [x] FR-1, NFR-2 만족 (양쪽 runtime hook 정의 완료, 발화 확인은 nrs apply 후 사용자 manual)
- [x] Validation Checklist 완료 (Manual smoke만 사용자 협조 대기)
- [ ] `nrs` 빌드 통과 + symlink 검증 — Phase 5 dogfooding과 통합 (사용자 협조)
- [x] 기존 hook(record-last-stop, nrs-session-cleanup, stop-notification, session-init-icons) ordering 보존, 신규 entry append만 수행

## Phase-End Multi-Pass Review

다음 phase로 이동하기 전 순서대로 완료한다:
- [x] 1. Intent/coverage review — FR-1/NFR-2 매핑 항목 모두 등록 (Stop/SessionStart/SessionEnd hook + Codex SessionStart + dispatcher ordering)
- [x] 2. Correctness review — settings.json/config.toml syntax valid, dispatcher H2 ordering 정확, symlink 선언 4 + 3 = 7 path 모두 존재
- [x] 3. Simplicity review — declarative 변경만. 불필요한 추상화 없음
- [x] 4. Code quality review — dispatcher 헤더 주석에 issue #590 + #614 ordering rationale 명시. symlink 선언 패턴(claude/default.nix line 178+, codex/default.nix line 122+) 기존과 일관
- [x] 5. Duplication/cleanup review — 기존 hook(record-last-stop/stop-notification/nrs-session-cleanup/session-init-icons) ordering 보존. 신규 handoff-* 4 entry는 append + dispatcher H2 위치
- [x] 6. Security/privacy review — settings.json/config.toml 변경이 secret/PII에 영향 주지 않음 (실제 redaction + gitleaks는 Phase 2 helper + Phase 4 강화)
- [x] 7. Performance/load review — Stop chain 4 entry로 증가했으나 handoff-stop은 turn-counter 외부 file write 1회만 (~ms). NFR-1 추정 만족
- [x] 8. Validation review — nixfmt + JSON/TOML parser + shellcheck + lefthook + fixture 16/16 PASS로 risk 커버. nrs build + manual smoke은 사용자 협조 (Phase 5 통합)
- [x] 9. Future-phase review — Phase 4 gitleaks staged ordering은 본 phase의 hook 위치(handoff-session-end.sh / Codex handoff-stop.sh)에서 호출되므로 일치
- [x] 10. PRD sync review — master PRD Document Status / Phase Index / Change Log 갱신 예정 (commit과 함께)

## Discoveries / Decisions

- **Claude Stop chain 신규 ordering**: `record-last-stop → handoff-stop → stop-notification → nrs-session-cleanup` (settings.json line 121-145 갱신).
- **Codex Stop dispatcher 신규 ordering**: `record-last-stop → nrs-session-cleanup → handoff-stop → stop-notification` (`_stop-dispatcher.sh` line 42-46). dispatcher 헤더에 issue #614 rationale 추가 (3번 항목 추가).
- **Codex `[[hooks.SessionStart]]` template-declared 추가**: config.toml에 single entry. SessionEnd 미지원이라 미등록.
- **nix module symlink**: claude 4개(handoff-lib, handoff-stop, handoff-session-end, handoff-session-start), codex 3개(handoff-lib, handoff-stop, handoff-session-start). 모두 mkOutOfStoreSymlink로 nrs 후 즉시 반영.
- **nrs apply는 사용자 manual 협조 필요**: Post-Implementation 자동 수행 범위에 host mutation은 포함되지 않음. Phase 5 dogfooding 시나리오 1과 통합하여 nrs 후 hook 발화 + manual smoke 진행.

## Phase Change Log

- 2026-05-05: Phase file created (split mode 동시 생성).
- 2026-05-05: settings.json + config.toml + _stop-dispatcher.sh + claude/default.nix + codex/default.nix 갱신 완료. nixfmt --check / JSON / TOML / shellcheck / fixture 모두 PASS. nrs apply는 Phase 5 dogfooding과 통합 (사용자 협조).
