# Phase 2: handoff-lib + thin wrappers

Parent PRD: [PRD: Session Handoff Automation](../prd-session-handoff-automation.md)
Status: Complete
Last Updated: 2026-05-05

## Objective

DEC-S9 G2 + sourced helper 결정에 따라 공통 로직을 `handoff-lib.sh`에 추출하고, thin wrapper(`handoff-stop.sh`, `handoff-session-end.sh`, `handoff-session-start.sh`)를 작성한다.

**SoT 정책 정정** (직전 fix 반영): handoff-lib.sh는 Claude SoT 단일 file이며, Codex hook 디렉토리(`~/.codex/hooks/handoff-lib.sh`)는 nix module이 Claude source에 mkOutOfStoreSymlink (pinning-patterns.sh와 동일 패턴). 본 phase에 처음 도입한 양쪽 사본 정책은 후속 fix에서 single-SoT로 단순화됨. 따라서 drift fixture는 single-SoT 정책 검증으로 변경(Codex repo source copy 부재 확인)되고 byte-identical 비교는 의미 없다. wrapper(handoff-stop / handoff-session-start)는 entrypoint별 Codex 가드 차이가 있어 별도 사본을 유지한다.

## Context From Master PRD

- Goals covered: G-2 (양쪽 동일 SoT), G-5 (non-blocking).
- Success Criteria: SC-1 (SessionStart stdout 주입), SC-4 (secret/PII 3 layer 첫 layer = allowlist + redaction을 helper에서 구현), SC-5 (non-blocking), SC-6 (idempotent).
- Requirements covered: FR-2 (Stop metadata-only), FR-3 (SessionEnd full snapshot), FR-4 (Codex Stop heuristic 분기), FR-5 (allowlist), FR-6 (branch-slug + hash + exact match), FR-7 (gitleaks 미설치 fallback).
- Key scenarios touched: Scenario 4 (Codex pseudo-SessionEnd via Stop heuristic), Scenario 5 (Secret/PII redaction).

## Phase Discovery Gate

코드 편집 전에 재확인한다:
- [x] 관련 코드/파일 (참조 패턴): `modules/shared/programs/claude/files/hooks/record-last-stop.sh`, `nrs-session-cleanup.sh`, `stop-notification.sh`, `modules/shared/programs/codex/files/hooks/_stop-dispatcher.sh`, `modules/shared/programs/codex/files/hooks/record-last-stop.sh` (Codex 사본 패턴 — `CLAUDECODE`/`CODEX_PROGRAMMATIC` early-exit 가드 참고)
- [x] 관련 테스트/fixture: `tests/test-codex-hook-fixtures.sh`, `tests/test-handoff-hooks.sh` (신규)
- [x] 관련 docs/spec/외부 참조: Claude/Codex Hooks docs, gitleaks usage docs, zsh-vs-bash 호환성 (CLAUDE.md "Bash tool 환경" 참고 — 본 hook은 모두 `#!/usr/bin/env bash`로 작성)
- [x] 관련 command 또는 도구: `gitleaks protect --staged --no-banner --redact`, `mktemp -d`, `umask 077`
- [x] Master PRD의 DEC-S6 결과 — B refined (turn-counter + transcript mtime) 적용. Phase 2 script list = handoff-lib + handoff-stop + handoff-session-end + handoff-session-start. Codex thin wrapper도 동일 (SessionEnd 제외)
- [x] 발견 사항이 후속 phase를 바꾸면 PRD 파일을 먼저 갱신

## Scope

### In Scope
- `modules/shared/programs/claude/files/hooks/handoff-lib.sh` 작성 (공통 pure helper):
  - `handoff_compute_slug <branch>` — slug + hash, hard fail
  - `handoff_write_snapshot <slug-with-hash> <args...>` — allowlist + redaction
  - `handoff_compute_diff <file>` — noise field 제외 후 diff
  - `handoff_run_gitleaks <staged>` — staged scan + 실패 시 unstage + quarantine
  - `HANDOFF_NOISE_FIELDS` 배열 SoT
  - `HANDOFF_IDLE_TIMEOUT_SECONDS` (default 300), `HANDOFF_TURN_THRESHOLD` (default 20) env var fallback default
  - PII redaction 헬퍼 (이메일/전화/절대경로/env var 패턴)
- `modules/shared/programs/claude/files/hooks/handoff-stop.sh` (mode 분기 entry, Claude 매 Stop 시 metadata-only)
- `modules/shared/programs/claude/files/hooks/handoff-session-end.sh` (Claude SessionEnd 전용 full snapshot + redaction + add + gitleaks --staged + commit)
- `modules/shared/programs/claude/files/hooks/handoff-session-start.sh` (snapshot 존재 시 stdout I2 형식 출력)
- Codex 사본 또는 동일 file symlink (Phase 1 결과에 따라):
  - `modules/shared/programs/codex/files/hooks/handoff-stop.sh` (idle/turn-counter heuristic 검사 + mode 분기. Codex 가드 `CLAUDECODE`/`CODEX_PROGRAMMATIC` early-exit)
  - `modules/shared/programs/codex/files/hooks/handoff-session-start.sh` (Codex 가드)
  - (Codex SessionEnd 미지원이므로 `handoff-session-end.sh`는 Claude 전용)
- `tests/test-handoff-hooks.sh` (drift fixture + secret/PII fixture corpus + non-blocking 시뮬레이션 + branch-slug 충돌 시뮬레이션 + idempotent diff 시뮬레이션)

### Out of Scope
- settings.json / config.toml hook 등록 (Phase 3)
- nix module symlink 선언 (Phase 3)
- gitleaks staged ordering의 commit/PR diff 정책 (Phase 4)
- dogfooding round-trip (Phase 5)

## Implementation Checklist

- [x] `handoff-lib.sh` 작성: 공통 pure helper(`compute_slug`/`redact`/`increment_turn`/`reset_turn`/`should_trigger_full`/`compute_diff`/`run_gitleaks`/`write_snapshot`/`full_snapshot_commit`/`parse_session_id`/`parse_transcript_path`/`resolve_bin`) + SoT 상수(`HANDOFF_NOISE_FIELDS`/`HANDOFF_IDLE_TIMEOUT_SECONDS`/`HANDOFF_TURN_THRESHOLD`).
- [x] `handoff-stop.sh` (Claude) 작성: stdin JSON read → turn-counter 증가만 (commit 없음). full snapshot은 SessionEnd가 담당. non-blocking + exit 0.
- [x] `handoff-stop.sh` (Codex 사본) 작성: Codex 가드(CLAUDECODE/CODEX_PROGRAMMATIC) + `handoff_should_trigger_full` 검사 → trigger 시 `handoff_full_snapshot_commit "codex"` 호출 + turn reset.
- [x] `handoff-session-end.sh` (Claude) 작성: `handoff_full_snapshot_commit "claude-code"` 위임 + turn reset. helper 내부에서 allowlist + redaction + add + gitleaks --staged + commit (`chore(handoff): session-end snapshot for <branch>`) + 실패 시 unstage + quarantine.
- [x] `handoff-session-start.sh` (Claude/Codex 양쪽) 작성: snapshot 파일 존재 + frontmatter `branch:` exact match 검증 → stdout I2 형식 출력 + source=`clear` 시 stale marker. 부재 시 silent exit.
- [x] Codex 가드: 모든 Codex 사본 hook script 시작 시 `[ "${CLAUDECODE:-}" = "1" ] || [ "${CODEX_PROGRAMMATIC:-}" = "1" ]`이면 early-exit 0.
- [x] `tests/test-handoff-hooks.sh` 작성: 16 fixture (drift sha, compute_slug 6 case, redact 5 case, should_trigger_full 2 case, run_gitleaks missing 1 case, non-blocking 1 case). 모두 PASS.

## Validation Strategy

본 phase는 helper + 4 script + 1 fixture 신규 작성이다. risk: bash 호환성, secret/PII 누수, idempotent 깨짐, non-blocking 깨짐. 따라서 (a) bash unit test로 happy path + edge case 검증 (b) secret/PII fixture corpus로 redaction 보장 (c) idempotent fixture로 noise field 제외 비교 검증. integration test는 settings.json 등록 후 Phase 3에서 처리. browser/UI/visual은 N/A.

## Validation Checklist

- [x] Static check: `bash -n` 7 script 모두 OK + `shellcheck -S warning` 깨끗 (SC2221/SC2222 case pattern 단순화 + SC2088 disable 주석)
- [x] 자동 test: `bash tests/test-handoff-hooks.sh` 16 pass / 0 fail
- [x] API/CLI workflow: `handoff_run_gitleaks` 미설치 fallback fixture에서 staged unstage + quarantine 검증
- [x] Browser/UI E2E: N/A
- [x] Agent/dev browser: N/A
- [x] Mobile/app simulator: N/A
- [x] Visual/screenshot: N/A
- [x] Observability/logging: helper stderr 메시지 — `gitleaks 미설치 — commit 차단 + quarantine`, `gitleaks scan 차단 — unstage + quarantine`, `core tool missing — commit 차단`, `raw branch traversal candidate=<x>` 등 진단 정보 명시
- [x] Manual smoke check: test fixture가 임시 git repo에서 helper 호출하며 quarantine 동작 검증 (manual smoke의 자동화 상응)
- [x] Error/empty/permission/retry/rollback: gitleaks 미설치 → unstage + quarantine + return 1 (호출 측 exit 0), lib 부재 → entry exit 0, raw branch 빈/traversal/empty slug → hard fail return 2

## Exit Criteria

- [x] Phase objective 달성 (helper + 7 script(Claude 4 + Codex 3) + fixture 모두 작성)
- [x] FR-2/3/4/5/6/7 구현됨 (registration은 Phase 3에서 진행)
- [x] Validation Checklist 완료, N/A 항목은 근거 명시
- [x] Phase 3 시작에 필요한 모든 script 파일 존재 + chmod +x 적용

## Phase-End Multi-Pass Review

다음 phase로 이동하기 전 순서대로 완료한다:
- [x] 1. Intent/coverage review — FR-2(metadata-only)/FR-3(SessionEnd full snapshot)/FR-4(Codex Stop heuristic 분기)/FR-5(allowlist)/FR-6(branch-slug+hash exact match)/FR-7(gitleaks fallback) 모두 구현
- [x] 2. Correctness review — happy + edge case 처리: gitleaks 미설치 → quarantine, branch-slug 빈/traversal/충돌 → hard fail/다른 hash, idempotent diff (noise field 제외 빈 diff면 commit skip), redaction (이메일/전화/주민번호/$HOME/env-var)
- [x] 3. Simplicity review — helper(11 함수) + thin wrapper(7 entry) 구조 단순. 불필요 추상화 없음. handoff_full_snapshot_commit 추출로 Claude SessionEnd + Codex Stop heuristic이 동일 helper 공유
- [x] 4. Code quality review — 함수명/매개변수 일관(snake_case + handoff_ prefix). 헤더 주석에 SoT 위치(HANDOFF_NOISE_FIELDS / HANDOFF_IDLE_TIMEOUT_SECONDS / HANDOFF_TURN_THRESHOLD), DEC-S6/S7/S8/S9/S10/S11/S12/S13/S14 reference 명시
- [x] 5. Duplication/cleanup review — Claude/Codex 사본 차이는 entrypoint(handoff-stop의 가드 + heuristic 분기)만. helper는 동일 content (drift fixture가 cmp -s로 검증)
- [x] 6. Security/privacy review — Phase 2 base redaction(이메일/전화/주민번호/$HOME/env-var) fixture에서 차단 검증. Phase 4에서 corpus 확장으로 GitHub/OpenAI/AWS/Stripe/JWT 추가. gitleaks 미설치 fallback이 commit 차단 + quarantine으로 안전 우선
- [x] 7. Performance/load review — Stop hook은 turn-counter 외부 file write 1회만 (ms 단위). SessionEnd full snapshot+redaction+gitleaks staged scan은 사용자 인지 못 하는 비차단. NFR-1 만족 추정
- [x] 8. Validation review — 16 fixture가 8 카테고리(drift/slug/redact/turn-counter/gitleaks-missing/non-blocking 등) 커버. lefthook + nix eval은 Phase 3
- [x] 9. Future-phase review — Phase 3의 hook 등록 entry는 본 phase script 이름과 일치 (`handoff-stop.sh`/`handoff-session-end.sh`/`handoff-session-start.sh`/`handoff-lib.sh`)
- [x] 10. PRD sync review — master PRD `Document Status` Current Phase=Phase 3, Phase Index Phase 2 Status=Complete, Change Log 갱신

## Discoveries / Decisions

- **handoff_full_snapshot_commit helper 추출**: Claude SessionEnd entry + Codex Stop heuristic-trigger가 같은 로직을 공유하므로 helper에 통합. SessionEnd는 wrapper, Codex Stop은 trigger 검사 후 호출. DEC-S9 G2 + sourced helper 정신 강화.
- **handoff_resolve_bin helper 추가**: PATH 조작 환경(test의 미설치 시뮬레이션 포함)에서 git/rm 같은 core tool을 안전하게 resolve. system path fallback (`/usr/bin`, `/bin`, `/usr/local/bin`, `/run/current-system/sw/bin`).
- **shellcheck 정리**: case pattern 단순화 (raw `..` 차단 + 절대경로 prefix 차단으로 분리), test의 tilde literal에 SC2088 disable.
- **fixture 16/16 PASS** evidence: drift(1) + compute_slug(6 case) + redact(5 case) + turn-counter(2) + gitleaks-missing(1) + non-blocking(1) = 16.

## Phase Change Log

- 2026-05-05: Phase file created (split mode 동시 생성).
- 2026-05-05: handoff-lib.sh + 7 hook script(Claude 4 + Codex 3) + tests/test-handoff-hooks.sh(16 fixture) 작성. shellcheck 깨끗 + bash -n OK + fixture 16/16 PASS. handoff_full_snapshot_commit/handoff_resolve_bin helper 추가. Phase 2 Complete.
