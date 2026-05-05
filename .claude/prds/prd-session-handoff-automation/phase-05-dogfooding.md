# Phase 5: Cross-runtime + Cross-machine Dogfooding

Parent PRD: [PRD: Session Handoff Automation](../prd-session-handoff-automation.md)
Status: Not Started
Last Updated: 2026-05-05

## Objective

본 hook 시스템 자체를 사용자가 실제 워크플로에서 dogfooding하여 9 시나리오를 검증한다. 본 phase는 본 hook 시스템의 첫 dogfooding round-trip이며, 결과로 schema/필드/threshold/ordering이 조정될 수 있다.

## Context From Master PRD

- Goals covered: G-1, G-2, G-3, G-4, G-5 (전체 목표가 dogfooding으로 검증됨).
- Success Criteria: SC-1, SC-2, SC-3, SC-4, SC-5, SC-6 (모든 SC가 본 phase에서 측정).
- Requirements covered: FR-1~8, NFR-1~4 (전체 시스템 동작).
- Key scenarios touched: Scenario 1, 2, 3, 4, 5 (모두).

## Phase Discovery Gate

코드 편집 전에 재확인한다:
- [ ] 관련 코드/파일: Phase 2~4에서 작성한 helper + 4 script + 등록 + secret/PII 3 layer 모두
- [ ] 관련 테스트/fixture: `tests/test-handoff-hooks.sh` 전체 fixture
- [ ] 관련 docs/spec/외부 참조: master PRD의 Key Scenarios (1~5), Decision Matrix (특히 DEC-S6 B의 idle heuristic이 Phase 1에서 확정 또는 fallback)
- [ ] 관련 command 또는 도구: 두 머신(MiniPC + macOS), Claude Code + Codex CLI 양쪽 세션, `git push` + `git pull`, multi-worktree 시뮬레이션
- [ ] Phase 1~4 완료 + 모든 hook이 정상 발화 상태
- [ ] 발견 사항이 PRD 또는 후속 phase를 바꾸면 즉시 반영 (Phase 6 closeout 전 마지막 기회)

## Scope

### In Scope (9 시나리오)
1. Same-runtime resume (Claude → Claude): SessionEnd → snapshot commit → 새 Claude SessionStart → metadata 주입 확인 → 모델이 handoff 파일 read
2. Same-runtime resume (Codex → Codex): idle/turn-counter heuristic 발동 → snapshot commit → 새 Codex SessionStart → 동일 동작
3. Cross-runtime resume (Claude → Codex / Codex → Claude): 동일 SoT 파일을 read, 양쪽 SessionStart hook이 동일 형식 stdout
4. Cross-machine resume: 머신 A에서 commit + push → 머신 B git pull → B의 새 세션 SessionStart → 동일 metadata 주입
5. Abnormal termination fallback: SessionEnd 누락(SIGKILL 시뮬레이션) 시 Stop의 metadata가 fallback. 새 세션에서 stale marker로 표시
6. Multi-worktree race: 동일 branch 두 worktree 동시 checkout → 양쪽 SessionEnd → snapshot 충돌 처리 관찰 (마지막 writer wins, 부작용 측정)
7. Non-blocking: gitleaks 미설치(`PATH` 조작) + timeout(`timeout 1s` wrap) + 빈 commit → 세션 흐름 비차단 확인
8. Secret/PII 3-layer 통합 차단: 가짜 chat content에 secret/PII fixture corpus를 전체 삽입 → SessionEnd 발화 → snapshot 잔존 토큰 0건 확인 (3 layer 모두 통과)
9. `/write-handoff` 동시 동작 race: Codex 사용자가 명시 `/write-handoff` 호출 + 동시 SessionEnd hook 발화 → GitHub 코멘트와 `.claude/handoffs/` 양쪽 갱신 충돌 관찰 + race condition 측정

### Out of Scope
- 코드 변경 (Phase 2~4)
- write-handoff skill 처리 결정 (Phase 6)
- 본 PRD Closeout (Phase 6)

## Implementation Checklist

- [ ] 시나리오 1 dogfooding: Claude → Claude. 결과 evidence 정리 (SessionEnd commit hash, SessionStart stdout 캡처, 모델 read 흔적)
- [ ] 시나리오 2 dogfooding: Codex → Codex. idle/turn-counter heuristic 발동 빈도 측정. fallback 발동(DEC-S6 C/D)이라면 그 동작 확인
- [ ] 시나리오 3 dogfooding: cross-runtime 양방향 (Claude → Codex, Codex → Claude). 동일 SoT 파일 read 확인
- [ ] 시나리오 4 dogfooding: cross-machine (MiniPC ↔ macOS). git push/pull 후 metadata 주입 확인
- [ ] 시나리오 5 시뮬레이션: 강제 종료(`pkill -9 claude`) → Stop hook의 metadata가 fallback으로 남는지 확인. 새 세션에서 stale marker 표시
- [ ] 시나리오 6 시뮬레이션: 동일 branch 두 worktree에서 동시 SessionEnd → 마지막 writer wins. 부작용 측정 (이전 worktree의 active-files 손실 등). 빈도가 낮음을 dogfooding 1주 후 재확인 → A-2 가정 검증
- [ ] 시나리오 7 시뮬레이션: gitleaks 제거 + timeout 1s + 빈 commit 모두 fixture로 → 세션 종료 latency 영향 0
- [ ] 시나리오 8 dogfooding: secret/PII fixture corpus를 의도적으로 chat content에 포함 + SessionEnd → snapshot 검사 → 잔존 토큰 0건 확인 (Phase 4의 3 layer 통합 검증)
- [ ] 시나리오 9 dogfooding: Codex `/write-handoff` 명시 호출 + 동시 SessionEnd hook → GitHub 코멘트와 `.claude/handoffs/` 양쪽 갱신 → race 측정. 결과를 D6 risk evidence에 추가, Phase 6에서 별도 후속 이슈에 인용

## Validation Strategy

본 phase는 manual + scripted dogfooding이 핵심이다. 각 시나리오마다 (a) 시나리오 setup (b) trigger 발화 (c) expected outcome 검증 (d) evidence 캡처(commit hash / stdout / 파일 diff / latency 측정)을 수행한다. risk: heuristic false trigger, race condition, secret leak, abnormal termination 누락. browser/UI/visual은 N/A.

## Validation Checklist

- [ ] Static check: N/A (manual dogfooding 위주)
- [ ] 자동 test: 시나리오 5/6/7/8을 가능한 한 fixture로 자동화 (`tests/test-handoff-dogfooding.sh` 또는 `tests/test-handoff-hooks.sh` 확장)
- [ ] API/CLI workflow: 모든 9 시나리오의 git/codex/claude 명령 evidence
- [ ] Browser/UI E2E: N/A
- [ ] Agent/dev browser: N/A
- [ ] Mobile/app simulator: N/A
- [ ] Visual/screenshot: GitHub UI에서 `.claude/handoffs/` collapsed 확인(manual, Phase 4와 중복 가능)
- [ ] Observability/logging: 각 시나리오의 hook stderr/log 보존
- [ ] Manual smoke check: 본 phase의 핵심. 사용자가 실제로 9 시나리오 진행
- [ ] Error/empty/permission/retry/rollback: 시나리오 5~9가 error/abnormal 경로 커버

## Exit Criteria

- [ ] Phase objective 달성 (9 시나리오 모두 evidence 확보)
- [ ] G-1~5 + SC-1~6 모두 dogfooding으로 검증
- [ ] FR-1~8 + NFR-1~4 모두 작동 확인
- [ ] Validation Checklist 완료, manual 시나리오는 evidence(commit hash, stdout, log) 인용
- [ ] dogfooding 결과로 schema/필드/threshold 조정이 필요하면 Phase 2~4 backport 후 재검증

## Phase-End Multi-Pass Review

다음 phase로 이동하기 전 순서대로 완료한다:
- [ ] 1. Intent/coverage review — G-1~5 + SC-1~6이 dogfooding으로 모두 매핑됨
- [ ] 2. Correctness review — happy path + edge case + abnormal termination + race + secret leak + non-blocking 모두 처리
- [ ] 3. Simplicity review — 9 시나리오가 risk를 충분히 커버하면서 과도하지 않음
- [ ] 4. Code quality review — N/A (본 phase는 dogfooding 위주, 코드 변경은 backport 시에만)
- [ ] 5. Duplication/cleanup review — fixture가 dogfooding에서 발견된 새 case로 확장됨
- [ ] 6. Security/privacy review — 시나리오 8에서 secret/PII 3 layer 통합 검증, 잔존 토큰 0건 재확인
- [ ] 7. Performance/load review — 시나리오 7에서 latency 영향 측정, NFR-1 만족 확인
- [ ] 8. Validation review — manual + scripted 조합이 risk 모두 커버
- [ ] 9. Future-phase review — Phase 6의 closeout 항목이 dogfooding 결과를 반영해 갱신됨
- [ ] 10. PRD sync review — master PRD `Document Status`, `Change Log`, Phase Index의 Phase 5 Status 갱신. 시나리오 9 결과를 Phase 6 follow-up 이슈에 인용

## Discoveries / Decisions

- (작성 예정 — Phase 5 진행 중 evidence 누적. 특히 DEC-S6 B 실측 결과, A-2 (multi-worktree 빈도) 검증, A-3 (idle 신호 추출) 확정 또는 fallback 결정)

## Phase Change Log

- 2026-05-05: Phase file created (split mode 동시 생성).
