# Phase 5: Cross-runtime + Cross-machine Dogfooding

Parent PRD: [PRD: Session Handoff Automation](../prd-session-handoff-automation.md)
Status: Pending User Smoke (manual dogfooding 협조 필요)
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
- [x] 관련 코드/파일: Phase 2~4에서 작성한 helper + 4 script + 등록 + secret/PII 3 layer 모두 — 4 commit으로 누적 (PRD docs / hook scripts+fixture / hook 등록 / redaction 강화+.gitattributes)
- [x] 관련 테스트/fixture: `tests/test-handoff-hooks.sh` 23 fixture 전부 PASS + `tests/test-codex-hook-fixtures.sh` scenario-C PermissionRequest 이전 통과
- [x] 관련 docs/spec/외부 참조: master PRD의 Key Scenarios (1~5), Decision Matrix (DEC-S6 B refined Phase 1에서 확정)
- [ ] 관련 command 또는 도구: 두 머신(MiniPC + macOS), Claude Code + Codex CLI 양쪽 세션, `git push` + `git pull`, multi-worktree 시뮬레이션 — **사용자 manual smoke 협조 필요** (host mutation `nrs` + cross-machine + cross-runtime 모두 자동 수행 범위 외)
- [x] Phase 1~4 완료 (manual smoke 일부 항목 본 phase로 이관)
- [x] 발견 사항이 PRD 또는 후속 phase를 바꾸면 즉시 반영

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

## Implementation Checklist (사용자 manual smoke 항목)

본 phase의 9 시나리오는 nrs apply + 두 머신(MiniPC + macOS) + 양 runtime(Claude Code + Codex CLI) 실세션 진입이 필요하므로 사용자 manual smoke 협조가 필수다. Post-Implementation 자동 수행 범위 외 (host mutation + cross-machine).

- [ ] 시나리오 1 (Claude → Claude): nrs apply 후 Claude Code 세션 1회 진입 + 종료 (SessionEnd 발화) → `.claude/handoffs/<branch-slug>-<branch-hash>.md` 생성 + commit (`chore(handoff): session-end snapshot for issue/614`) → 새 Claude 세션 SessionStart stdout 확인 (`[handoff resume] branch=...`).
- [ ] 시나리오 2 (Codex → Codex): Codex 세션 turn 20+ 또는 transcript_path mtime 5분+ 후 Stop trigger → handoff-stop.sh가 full snapshot+commit 발화 확인. 미발동 시 metadata-only (turn-counter 누적만).
- [ ] 시나리오 3 (cross-runtime): Claude → Codex, Codex → Claude 양방향 resume. 동일 SoT 파일 read.
- [ ] 시나리오 4 (cross-machine): 머신 A(MiniPC)에서 commit + push → 머신 B(macOS)에서 git pull → B의 Claude 또는 Codex 새 세션 SessionStart 주입 확인.
- [ ] 시나리오 5 (abnormal termination): `pkill -9 claude` 또는 Codex 강제 종료 → 다음 세션 SessionStart에서 이전 metadata가 stale 상태로 표시되는지 확인 (Stop hook이 record-last-stop으로 metadata만 갱신했을 수 있음).
- [ ] 시나리오 6 (multi-worktree race): 동일 branch가 두 worktree에 동시 checkout된 상태에서 양쪽 SessionEnd → snapshot 충돌 시 마지막 writer wins 동작 + 부작용(이전 active-files 손실 등) 측정. A-2 가정(빈도 낮음) 1-2주 dogfooding 후 재확인.
- [ ] 시나리오 7 (non-blocking): gitleaks PATH 제거 또는 nix store gitleaks 위치 변경 시뮬레이션 → 세션 종료 흐름이 차단되지 않는지. handoff_run_gitleaks가 commit 차단 + quarantine 후 exit 0 (Phase 2 fixture에서 일부 자동 검증 완료, 실세션 통합은 사용자 협조).
- [ ] 시나리오 8 (secret/PII 3 layer 통합): chat content에 fixture corpus(GitHub PAT/OpenAI/AWS/Stripe/JWT/이메일/전화/주민번호/$HOME/env-var)를 의도적으로 포함 + SessionEnd → 생성된 snapshot 파일에 잔존 토큰 0건 확인 (Phase 4 fixture에서 일부 자동 검증, 실 chat 통합은 사용자 협조).
- [ ] 시나리오 9 (write-handoff race): Codex 세션에서 `/write-handoff <issue-url>` 명시 호출 + 동시 SessionEnd hook 발화 → GitHub 코멘트와 `.claude/handoffs/` 양쪽 갱신 race 측정. 결과를 D6 risk evidence + Phase 6 follow-up 이슈에 인용.

## Validation Strategy

본 phase는 manual + scripted dogfooding이 핵심이다. 각 시나리오마다 (a) 시나리오 setup (b) trigger 발화 (c) expected outcome 검증 (d) evidence 캡처(commit hash / stdout / 파일 diff / latency 측정)을 수행한다. risk: heuristic false trigger, race condition, secret leak, abnormal termination 누락. browser/UI/visual은 N/A.

## Validation Checklist

- [x] Static check: N/A (manual dogfooding 위주)
- [x] 자동 test (부분): 시나리오 7 non-blocking + 시나리오 8 secret/PII 3-layer는 Phase 2/4 fixture가 일부 자동 검증. 23/23 PASS
- [ ] API/CLI workflow: 9 시나리오 evidence는 사용자 manual smoke로 수집 — git commit hash + SessionStart stdout 캡처 + handoff snapshot 파일 내용
- [x] Browser/UI E2E: N/A
- [x] Agent/dev browser: N/A
- [x] Mobile/app simulator: N/A
- [ ] Visual/screenshot: GitHub UI에서 .claude/handoffs/ collapsed by default 확인 — 사용자 PR 머지 후 manual
- [ ] Observability/logging: 각 시나리오의 hook stderr 보존 — 사용자 협조 시 stderr 인용
- [ ] Manual smoke check: 본 phase 핵심. 사용자가 9 시나리오 진행 + evidence를 본 phase Discoveries에 추가
- [ ] Error/empty/permission/retry/rollback: 시나리오 5~9가 error/abnormal 경로 커버 (manual)

## Exit Criteria

- [ ] Phase objective 달성 (9 시나리오 evidence 확보) — **사용자 manual smoke 후 갱신**
- [ ] G-1~5 + SC-1~6 모두 dogfooding으로 검증 — manual smoke 후 갱신
- [ ] FR-1~8 + NFR-1~4 모두 작동 확인 — manual smoke 후 갱신
- [ ] Validation Checklist 완료 (자동 검증 부분 완료, manual은 evidence 인용 시 완료)
- [ ] dogfooding 결과로 schema/필드/threshold 조정이 필요하면 Phase 2~4 backport 후 재검증

**자동 진행 가능 작업 (Post-Implementation 자동 수행 범위)**: 본 phase의 manual smoke 결과를 기다리지 않고 Phase 6 closeout(review-only)을 진행한다. dogfooding evidence가 모이면 본 phase Discoveries + Exit Criteria를 사용자 또는 후속 세션에서 갱신한다.

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

- 사용자 manual smoke 후 9 시나리오 evidence가 본 섹션에 누적. 특히:
  - DEC-S6 B refined turn-counter + transcript mtime 실측 trigger 빈도
  - A-2 multi-worktree 빈도 검증 (시나리오 6)
  - 시나리오 9 write-handoff race evidence (D6 risk + Phase 6 follow-up 이슈 inputs)

## Phase Change Log

- 2026-05-05: Phase file created (split mode 동시 생성).
- 2026-05-05: Phase 5 Status = Pending User Smoke. Phase 1~4 모든 자동 가능 작업 완료. nrs apply + 두 머신 + 양 runtime 실세션 진입은 host mutation으로 Post-Implementation 자동 수행 범위 외 → 사용자 manual smoke 협조 필요. Phase 6 closeout (review-only)는 본 phase manual smoke 결과를 기다리지 않고 자동 진행.
