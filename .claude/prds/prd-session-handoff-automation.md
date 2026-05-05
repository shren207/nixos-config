# PRD: Session Handoff Automation

## Document Status
- Status: In Progress
- File Mode: Split
- Current Phase: Phase 4 (Phase 1+2+3 Complete; Phase 3 nrs apply는 Phase 5 통합)
- Active Phase File: [Phase 4](./prd-session-handoff-automation/phase-04-secret-and-prdiff.md)
- Last Updated: 2026-05-05
- PRD File: `.claude/prds/prd-session-handoff-automation.md`
- Purpose: Living PRD / 실행 source of truth. SessionStart/SessionEnd lifecycle hook으로 세션 인수인계를 완전 자동화한다 (`/write-handoff` + `gh issue view` + NSS 수동 단계 전부 제거). Claude Code + Codex CLI 양쪽에서 git-tracked `.claude/handoffs/<branch>.md` 단일 SoT로 cross-runtime + cross-machine resume 가능.

## Problem

세션 종료 시 사용자가 수동으로 수행하는 단계가 3개 있다.
1. `/write-handoff <issue-url>` 호출 → GitHub issue에 코멘트 작성.
2. 새 세션에서 `gh issue view N --comments`로 코멘트 read.
3. 코멘트의 NSS(Next Session Starter) bash 블록 복사·실행 (cwd 복원 + branch 복원 + 컨텍스트 명시).

3 단계 모두 수동이며 여러 머신/branch/runtime 전환 시 반복 부담이 누적된다. SessionStart/SessionEnd lifecycle hook이 Claude Code (모든 source: startup/resume/clear)와 Codex CLI 0.124+ (SessionStart만 — SessionEnd는 미지원)에서 stdout context 자동 주입을 지원하므로 hook + git-tracked snapshot으로 수동 단계를 완전 제거할 수 있다.

이슈 #614는 사용자 두 차례 인터뷰로 5 핵심 결정(F3/T4/I2/X4/P1)을 lock-in했고, 본 PRD는 이를 baseline으로 두고 Codex SessionEnd 미지원에서 발생하는 추가 트레이드오프(idle/turn-counter heuristic, snapshot commit policy, multi-worktree key, helper script 위치, dispatcher ordering)를 외부 자문 + Devil's Advocate 리뷰로 보강했다.

## Goals

- G-1: 사용자 수동 인수인계 단계(`/write-handoff` + `gh issue view` + NSS 실행) 모두 제거.
- G-2: Claude Code + Codex CLI 양쪽 동일 SoT(`.claude/handoffs/<branch>.md`) 사용.
- G-3: cross-machine resume — `git checkout <branch>` 후 새 세션에서 SessionStart hook이 자동으로 metadata + link를 모델 컨텍스트로 주입.
- G-4: secret + PII + 환경 정보 노출 차단 — 3 layer 방어 (snapshot 입력 allowlist + redaction + gitleaks staged scan).
- G-5: hook 실패가 세션 종료/시작 흐름을 막지 않음 (non-blocking + idempotent + degrade-safe).

## Non-Goals

- NG-1: 외부 cloud 서비스 snapshot 업로드 — 로컬 + git 한정.
- NG-2: chat history 자체 복원 — model context 주입은 metadata + link로만.
- NG-3: 기존 `/write-handoff` skill 자체 폐기 결정 — 별도 후속 이슈로 분리한다.
- NG-4: multi-user/team 협업 — 1인 사용자(greenhead) 가정.
- NG-5: 매 turn commit (이슈 본문의 T1) — Stop hook은 metadata만, 의미 있는 변경 시에만 commit.
- NG-6: 사용자가 같은 hook event(`UserPromptSubmit`/`Stop`)에 추가 entry를 append하는 워크플로 — sync-codex-config.py array AoT merge 한계(issue #591 OPEN)로 본 PRD에서는 다루지 않는다 (template-declared entry만 추가).
- NG-7: Codex 0.123 이하 호환성.

## Success Criteria

- SC-1: 사용자가 새 세션을 열었을 때 SessionStart stdout으로 `branch` + `last-commit` + handoff 파일 경로가 모델 컨텍스트에 자동 주입된다 (수동 read/copy 없음).
- SC-2: Claude Code 세션 종료 → 새 Claude Code 세션 SessionStart, Codex 세션 종료 → Codex 새 세션 SessionStart, 그리고 cross-runtime (Claude → Codex / Codex → Claude) 4 시나리오 모두 동일 SoT 파일을 read한다.
- SC-3: cross-machine — 머신 A에서 hook이 만든 commit을 push, 머신 B에서 git pull, B의 새 세션 SessionStart에서 동일 metadata가 주입된다.
- SC-4: secret/PII fixture corpus(`sk-...`, `AKIA...`, GitHub token, 이메일/전화 패턴, 절대경로/hostname/env vars)를 가짜 chat content에 삽입했을 때 3 layer(allowlist + redaction + gitleaks) 모두 차단한다.
- SC-5: hook script가 timeout, gitleaks 미설치, 빈 commit 등의 장애 상황에서 세션 종료/시작 흐름을 차단하지 않는다 (각 시나리오 fixture 통과).
- SC-6: snapshot이 의미 없는 변경(timestamp/session-id 등 noise field만 변경)일 때 git commit이 발생하지 않는다 (idempotent).

## Key Scenarios

### Scenario 1: Same-runtime resume
- Actor: 사용자
- Trigger: Claude Code 세션 종료 → 새 Claude Code 세션 시작
- Expected outcome: SessionEnd가 snapshot 작성 + commit. 새 세션 SessionStart가 stdout으로 metadata + link 주입. 모델은 필요 시 handoff 파일 read.

### Scenario 2: Cross-runtime resume
- Actor: 사용자
- Trigger: Claude Code 세션 종료 → Codex 새 세션 시작 (반대 포함)
- Expected outcome: 동일 `.claude/handoffs/<branch>.md` SoT를 read. 양쪽 SessionStart hook이 동일 형식의 stdout을 출력.

### Scenario 3: Cross-machine resume
- Actor: 사용자
- Trigger: 머신 A에서 push, 머신 B에서 pull 후 새 세션 시작
- Expected outcome: B의 SessionStart가 pull된 snapshot을 read하고 metadata + link 주입.

### Scenario 4: Codex pseudo-SessionEnd via Stop heuristic
- Actor: 사용자
- Trigger: Codex 세션의 idle 상태(N분 무활동) 또는 turn 카운트 초과
- Expected outcome: Stop dispatcher 안에서 idle/turn-counter heuristic이 발동해 metadata-only 모드 대신 full snapshot + commit 모드로 분기. 매 turn commit은 발생하지 않음.

### Scenario 5: Secret/PII redaction
- Actor: 사용자 (Claude/Codex 세션)
- Trigger: chat 내용에 API 토큰, 이메일, 절대경로, env var 값이 포함된 상태로 SessionEnd
- Expected outcome: snapshot 작성 단계에서 allowlist 외 필드 제거 + redaction 적용 → gitleaks staged scan으로 한 번 더 차단 → 통과 시에만 commit. 차단 시 staged unstage + working tree quarantine.

## Discovery Summary

- **Reviewed**: 이슈 #614 본문(사용자 두 차례 인터뷰 매트릭스) + epic #584(Codex 0.124+ stable hooks 재도입) + issue #591(sync-codex-config user entry append 한계, OPEN) + Claude/Codex 공식 hooks docs + 본 repo의 `modules/shared/programs/{claude,codex}/files/hooks/` baseline + `lefthook.yml` gitleaks 사용.
- **Current system**:
  - Claude Code Stop chain: `record-last-stop.sh` → `stop-notification.sh` → `nrs-session-cleanup.sh` (sequential, settings.json).
  - Claude SessionStart: `session-init-icons.sh` (JSON `hookSpecificOutput.additionalContext` 출력).
  - Claude SessionEnd: `nrs-session-cleanup.sh` (Stop과 동일 script).
  - Codex Stop: `_stop-dispatcher.sh` 단일 entry. 내부 ordering은 `record-last-stop` → `nrs-session-cleanup` → `stop-notification` (issue #590 rationale 확정 — Codex는 multiple command를 concurrent 실행하므로 dispatcher로 직렬화).
  - Codex 미지원 이벤트: SessionEnd. SessionStart는 0.124+에서 plain stdout과 JSON `additionalContext` 둘 다 지원.
  - gitleaks 8.30.1 가용 (nix store). lefthook이 `gitleaks protect --staged --no-banner --redact`를 pre-commit에서 사용. repo에 `.gitleaksignore` + `.gitleaks.toml` 존재.
  - `write-handoff` skill: `modules/shared/programs/claude/files/skills/write-handoff/`. **Codex에도 노출됨** (`codex/default.nix`의 `exposedCodexSkills`에 `"write-handoff"` 포함, `.codex/skills/write-handoff` symlink 생성).
- **Validation surface**: bash unit test (`tests/test-codex-hook-fixtures.sh` 패턴), nix eval, lefthook(eval-tests + ai-skills-consistency + codex-hook-fixtures + gitleaks 자체), secret/PII fixture corpus, dogfooding round-trip(Phase 5의 9 시나리오).
- **Design implications**:
  - Codex SessionEnd 부재로 T4 Decision의 "SessionEnd=full snapshot+commit"을 Codex에 그대로 mapping할 수 없다 → DEC-S6에서 Stop dispatcher 내 idle/turn-counter heuristic 채택, Phase 1 PoC 결과에 따라 fallback gate.
  - dispatcher가 ordering shim 책임만 갖도록 유지 → DEC-S10 H2 위치에 단일 entry `handoff-stop.sh` 호출. metadata vs snapshot 분기는 entry 안에서.
  - Claude/Codex 양쪽 사본 정책(DEC-S9 G2)은 thin wrapper + 공통 sourced helper(`handoff-lib.sh`)로 중복 surface를 구조적으로 축소.
  - secret/PII는 gitleaks만으로 부족. allowlist + redaction 별도 layer가 필요 (DEC-S12).
- **Confidence / gaps**:
  - Phase 1 Discovery 완료: hook payload에 idle 필드 부재 확인 → DEC-S6 B refined (turn-counter + transcript mtime 결합) 적용. `last_assistant_message`가 hook 입력에 포함되어 secret/PII 차단(Phase 4)이 더 중요해짐.
  - multi-worktree 빈도 검증 완료: 4 worktree 모두 다른 branch (per-issue 관습). A-2 가정 유지. F1 + hash safety 충분.
  - macOS PoC는 Phase 5 dogfooding 시나리오 4(cross-machine)에서 사용자 manual smoke check로 흡수.

## Requirements

### Functional Requirements
- FR-1: SessionStart에서 `.claude/handoffs/<branch-slug>-<branch-hash>.md`가 존재하면 stdout으로 compact metadata + link 출력 (Claude/Codex 모두 — 둘 다 plain stdout 지원).
- FR-2: Claude Stop hook이 매 호출 시 metadata-only 갱신 (commit 없음).
- FR-3: Claude SessionEnd hook이 의미 있는 변경 시 (idempotent diff check 통과) full snapshot + redaction + gitleaks staged scan + commit.
- FR-4: Codex Stop dispatcher가 단일 `handoff-stop.sh` entry 호출. entry 내부에서 idle/turn-counter heuristic 검사 → 발동 시 metadata-only 대신 full snapshot+commit 모드로 분기.
- FR-5: snapshot 작성 시 allowlist 필드만 포함 (`branch`, `branch-hash`, `last-commit`, `runtime`, `issue-ref`, `prd-link`, `pending-decisions[]`, `active-files[]`, `next-action[]`). transcript/env vars/cwd absolute path/hostname/PII 패턴은 redaction 또는 작성 단계 제거.
- FR-6: branch-slug 충돌 방지를 위해 raw branch의 short hash(6자)를 suffix로 추가. frontmatter에 raw branch 보존 + read 시 exact match. 빈 slug/예약 이름/path traversal 후보는 hard fail.
- FR-7: gitleaks 미설치/scan 실패 시 commit 차단 + stderr 알림 + exit 0 (non-blocking 흐름 유지). staged unstage + working tree quarantine.
- FR-8: handoff commit message는 `chore(handoff):` prefix 강제. squash 머지 시 본 prefix는 PR 본문에서 제외 가이드를 적용.

### Non-Functional Requirements
- NFR-1: hook 실행 latency가 세션 종료/시작 흐름을 차단하지 않는 수준 (Stop=metadata-only는 < 500ms 목표, SessionEnd full snapshot+gitleaks+commit은 사용자가 인지하지 못하는 비차단).
- NFR-2: cross-runtime 일관성 — Claude/Codex 양쪽이 동일 형식의 SessionStart stdout과 동일 snapshot schema 사용.
- NFR-3: idempotent — 의미 없는 변경 시 commit이 발생하지 않음 (noise field 제외 후 diff 비교).
- NFR-4: defense-in-depth — secret/PII 차단이 단일 layer가 아닌 3 layer (allowlist + redaction + gitleaks staged scan + lefthook pre-commit gitleaks).

## Assumptions

- A-1: 사용자는 단일 사용자(greenhead) 환경. multi-user/team 워크플로 가정 안 함.
- A-2: 동일 branch가 여러 worktree에 동시 checkout되는 빈도가 낮음 (per-issue worktree 관습). race condition은 dogfooding에서 관찰 후 필요 시 F2/F3 key로 승격.
- A-3: Codex hook payload 자체에는 idle 신호 필드 부재 (Phase 1 검증). 우회 방식: turn-counter (외부 state file 누적) + `transcript_path` mtime 결합으로 DEC-S6 B refined.
- A-4: gitleaks 설치는 정상 환경에서 보장. 미설치 시 commit 차단 fallback으로 안전 우선.

## Dependencies / Constraints

- gitleaks declarative dep: 8.30.1 nix store에 가용. lefthook이 이미 의존.
- Codex 0.124+ stable hooks: SessionStart 지원, SessionEnd 미지원.
- sync-codex-config.py: template-declared `[[hooks.<event>]]` 추가만 보존 (issue #591 한계 — NG-6).
- nix module 패턴: `mkOutOfStoreSymlink`로 `~/.claude/hooks/*` + `~/.codex/hooks/*` 노출.

## Risks / Edge Cases

- D1 — git history 오염: `.claude/handoffs/<branch>.md` commit이 PR diff에 포함될 위험. 대응: `chore(handoff):` prefix + `.gitattributes linguist-generated` + PR template squash 가이드.
- D2 — secret/PII 노출: gitleaks false negative 가능. 대응: 3 layer 방어 (allowlist + redaction + gitleaks).
- D3 — multi-worktree 혼선: 동일 branch가 두 worktree에 동시 checkout 시 snapshot 충돌. 대응: branch-slug + hash suffix + raw branch exact match 검증. dogfooding에서 race 관찰.
- D4 — hook overhead: Stop hook이 매 turn 수행되므로 latency budget 필요. 대응: Stop=metadata-only는 빠르게(<500ms), gitleaks scan은 SessionEnd/heuristic-trigger 시에만.
- D5 — Codex stop-review-gate-hook 충돌: dispatcher 패턴에 새 entry 추가 시 ordering 충돌 가능. 대응: dispatcher 헤더 주석에 ordering rationale + 신규 위치 명시.
- D6 — `/write-handoff` 동시 동작: Codex `write-handoff` skill이 노출된 상태(`exposedCodexSkills`에 포함)에서 자동 hook과 동시 실행 시 GitHub 코멘트와 `.claude/handoffs/`가 모두 갱신될 수 있음. Phase 1 Discovery에서 race 시나리오 측정.
- D7 — DEC-S6 B refined (Phase 1 결과): hook payload에 idle 필드 없음 → turn-counter (외부 state file 누적) + `transcript_path` mtime 결합으로 우회. C/D fallback 미발동. 단 외부 state file 누적 패턴이 dogfooding(Phase 5)에서 false trigger를 만들면 threshold 조정 또는 C로 추가 fallback.

## Execution Rules

- 본 PRD가 명시적으로 수정되지 않는 한 phase는 순서대로 완료한다.
- 어떤 phase든 시작 전에 master PRD + active phase file을 읽는다.
- PRD 파일만 active plan으로 사용한다. 경쟁하는 별도 체크리스트를 만들지 않는다.
- 사소한 애매함은 가장 합리적인 옵션을 고르고 assumption으로 기록한 뒤 계속 진행한다.
- 다음 항목에 한해서만 진행을 멈추고 도움을 요청한다: 접근 권한 부재, 비가역적 파괴 변경, 주요 요구사항 충돌, 보안/법률 관련 의미 있는 risk.
- 목표를 만족하는 최소·가역적 변경을 선호한다.
- 명백한 사유가 없는 한 기존 코드 패턴(epic #584 Codex 사본 정책, mkOutOfStoreSymlink 패턴, `_stop-dispatcher.sh` ordering shim)을 보존한다.
- 검증 방법은 risk와 가용 도구에 맞춰 선택한다 (`~/.claude/skills/plan-with-questions/references/validation-paths.md`).
- 각 phase 종료 시 본 PRD를 갱신하고 학습 결과에 따라 후속 phase를 수정한다.

## Phase Index

| Phase | Status | Objective | Validation Focus | File |
|---|---|---|---|---|
| Phase 1: Discovery | Complete | gitleaks 가용성 + idle/turn-counter PoC + branch-slug 규칙 + noise field 목록 + Claude Stop chain 위치 + write-handoff race 시나리오 + multi-worktree 빈도 조사 | static read-only checks + PoC 측정 | [phase-01-discovery](./prd-session-handoff-automation/phase-01-discovery.md) |
| Phase 2: handoff-lib + thin wrappers | Complete | 공통 sourced helper + Claude/Codex thin wrapper 4 script + drift fixture | bash unit test + secret/PII fixture corpus | [phase-02-helper-and-wrappers](./prd-session-handoff-automation/phase-02-helper-and-wrappers.md) |
| Phase 3: hook 등록 | Complete (nrs manual smoke만 Phase 5 통합) | Claude settings.json + Codex config.toml + dispatcher H2 ordering + nix module symlink | nix eval + lefthook eval-tests + codex-hook-fixtures | [phase-03-hook-registration](./prd-session-handoff-automation/phase-03-hook-registration.md) |
| Phase 4: secret/PII 3-layer + idempotent + PR diff 제외 | Not Started | allowlist + redaction + gitleaks staged ordering + idempotent diff check + chore(handoff) prefix + .gitattributes | secret fixture corpus + idempotent fixture + lefthook gitleaks | [phase-04-secret-and-prdiff](./prd-session-handoff-automation/phase-04-secret-and-prdiff.md) |
| Phase 5: dogfooding round-trip | Not Started | 9 시나리오 (same/cross-runtime/cross-machine + abnormal + multi-worktree + non-blocking + secret + write-handoff race) | manual + scripted dogfooding | [phase-05-dogfooding](./prd-session-handoff-automation/phase-05-dogfooding.md) |
| Phase 6: 정리 + follow-up | Not Started | write-handoff 처리 별도 이슈 + sync-codex-config 한계 노트 + Closeout (PRD 10-pass + review-impl overlay) | review-only | [phase-06-followup](./prd-session-handoff-automation/phase-06-followup.md) |

## Final Multi-Pass Review After All Phases

Phase 6 closeout에서 `~/.claude/skills/plan-with-questions/references/prd/multi-pass-review.md`의 PRD 10-pass + `~/.claude/skills/plan-with-questions/references/review-impl/implementation-review.md` overlay(6-classification 라벨링 + overbuilt 우선 분류)를 적용한다. auto-fix는 미사용 (NG-2 of plan-with-questions). 발견된 이슈는 메인 에이전트가 별도 승인 단계에서 처리하거나 follow-up issue로 deferred 기록.

## Open Questions

- OQ-1: `/write-handoff` skill 자체의 처리 결정 (폐기 vs advanced 잔존 vs 통합) — 별도 후속 이슈로 분리. hook system 1-2주 사용 패턴 관찰 후 결정.
- OQ-2: multi-worktree key 형식 — F1(branch-slug + hash) 시작. dogfooding에서 race 빈도 관찰 후 필요 시 F2(`<slug>.<worktree-id>.md`) 또는 F3(per-worktree subdir)로 승격.
- OQ-3: Codex SessionEnd가 향후 추가될 가능성 — upstream openai/codex tracking. 추가되면 별도 이슈로 DEC-S6 B(heuristic) → SessionEnd 직접 사용으로 마이그레이션.

## Change Log

- 2026-05-05: Initial PRD created. plan-with-questions for_prd 모드로 작성. 사용자 두 차례 인터뷰(이슈 #614 본문 + 본 세션 추가 인터뷰) + 외부 LLM 자문(Codex SessionEnd 부재 처리 등 5개 트레이드오프) + Devil's Advocate 4-bundle 리뷰(15 CONFIRMED + 1 NOT_AN_ISSUE) 결과 반영. 신규 결정 5개(DEC-S11~S15) 추가.
- 2026-05-05: Phase 1 Discovery 완료(macOS smoke만 Phase 5 이관). DEC-S6 B refined (turn-counter + transcript mtime), DEC-S11 ordering 확정. A-3 가정 부분 부정 + 우회 방식 명시. branch-slug + hash contract 명세. multi-worktree race 빈도 낮음(A-2 검증). `/write-handoff` Codex 노출 baseline 정정 + race 시나리오 Phase 5 시나리오 9 트래킹.
- 2026-05-05: Phase 2 Complete. handoff-lib.sh(11 함수 + SoT 상수) + 7 thin wrapper script(Claude 4 + Codex 3) + tests/test-handoff-hooks.sh(16 fixture) 작성. shellcheck 깨끗 + bash -n OK + fixture 16/16 PASS. handoff_full_snapshot_commit + handoff_resolve_bin helper 추가로 Claude SessionEnd ↔ Codex Stop heuristic-trigger 공통 로직 흡수.
- 2026-05-05: Phase 3 Complete (nrs manual smoke만 Phase 5 통합). settings.json Stop/SessionEnd/SessionStart 신규 entry 추가, _stop-dispatcher.sh H2 ordering 적용 + 헤더 rationale, config.toml [[hooks.SessionStart]] 추가, claude/codex default.nix mkOutOfStoreSymlink 7개. nixfmt + JSON/TOML/shellcheck + 회귀 fixture 모두 PASS.
