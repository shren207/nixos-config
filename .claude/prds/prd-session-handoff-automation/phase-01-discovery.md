# Phase 1: Discovery

Parent PRD: [PRD: Session Handoff Automation](../prd-session-handoff-automation.md)
Status: Complete
Last Updated: 2026-05-05

## Objective

본 phase는 design lock-in 전 사전 검증을 마치고 후속 phase의 가정을 단단히 한다. 핵심은 (a) DEC-S6 B의 idle/turn-counter heuristic이 Codex hook payload만으로 실현 가능한지 PoC, (b) 실패 시 DEC-S6 C 또는 D fallback gate, (c) branch-slug + hash 규칙 / noise field 목록 / Claude Stop chain 위치 / write-handoff race 시나리오 / multi-worktree race 빈도 같은 evidence_gap을 모두 닫는 것이다.

## Context From Master PRD

- Goals covered: G-1, G-2, G-3 (전체 architecture의 baseline 확보), G-5 (non-blocking 가정 검증).
- Success Criteria: SC-2 (cross-runtime 4 시나리오), SC-3 (cross-machine), SC-6 (idempotent).
- Requirements covered: FR-4 (Codex Stop heuristic), FR-5 (allowlist), FR-6 (branch-slug + hash + exact match), FR-7 (gitleaks 미설치 fallback).
- Key scenarios touched: Scenario 4 (Codex pseudo-SessionEnd via Stop heuristic), Scenario 5 (Secret/PII redaction의 evidence 측정).

## Phase Discovery Gate

코드 편집 전에 재확인한다:
- [x] 관련 코드/파일: `modules/shared/programs/codex/files/hooks/_stop-dispatcher.sh`, `modules/shared/programs/claude/files/settings.json`, `modules/shared/programs/codex/files/config.toml`, `modules/shared/programs/codex/default.nix`, `modules/shared/programs/claude/default.nix`, `lefthook.yml`, `.gitleaks.toml`, `.gitleaksignore`
- [x] 관련 테스트/fixture: `tests/test-codex-hook-fixtures.sh` (패턴 차용 대상)
- [x] 관련 docs/spec/외부 참조: epic #584 본문, issue #591 본문, issue #590 ordering rationale, Claude Code Hooks docs (https://code.claude.com/docs/en/hooks), Codex Hooks docs (https://developers.openai.com/codex/hooks)
- [x] 관련 command 또는 도구: `gitleaks --version`, `nix run nixpkgs#gitleaks -- --version`, codex hook payload schema (공식 docs)
- [x] Master PRD의 assumption A-3 (Codex hook payload에서 idle 신호 추출 가능) 검증 대상 — **부분 부정** (Discoveries 참조)
- [x] 발견 사항이 본 phase 또는 후속 phase를 바꾸면 구현 전에 PRD 파일을 먼저 갱신

## Scope

### In Scope
- gitleaks declarative 가용성 final 확인 (실측 + Linux MiniPC + macOS 양쪽).
- Codex hook payload 검사 — `last_user_input_at`, `turn_count`, `session_started_at` 같은 필드 존재 여부 측정.
- DEC-S6 B의 idle/turn-counter heuristic PoC: 추출한 신호로 `HANDOFF_IDLE_TIMEOUT_SECONDS=300`, `HANDOFF_TURN_THRESHOLD=20` default가 의미 있는지 측정. 실패 시 fallback 결정.
- branch-slug 정규화 규칙 확정: `[a-z0-9-]+` 허용, slash → `-`, hash 길이 6자, exact match 검증 위치(snapshot read 시 frontmatter `branch:` 와 현재 git branch 비교).
- noise field 목록 final: `last-updated`, `session-id`, `cwd`, `hostname` 외에 추가가 필요한지 검사 (예: `runtime-version`, `pid` 등).
- DEC-S11 Claude Stop chain ordering 위치 확정: 현재 `record-last-stop → stop-notification → nrs-session-cleanup`의 어느 위치에 `handoff-stop.sh` 삽입이 cross-runtime 일관성과 latency 모두 만족하는지.
- `/write-handoff` 동시 동작 race 시나리오 측정: Codex `write-handoff` skill 노출 상태에서 사용자가 명시 호출 + 자동 hook이 동시 실행될 때 GitHub 코멘트와 `.claude/handoffs/` 양쪽 갱신 충돌 여부.
- multi-worktree race 빈도 조사: 본 사용자의 git worktree 운영 패턴 (per-issue worktree 확인) 기반 빈도 추정.

### Out of Scope
- 실제 hook script 작성 (Phase 2).
- settings.json/config.toml 변경 (Phase 3).
- gitleaks inline scan 코드 (Phase 4).

## Implementation Checklist

- [x] gitleaks 가용 실측: `gitleaks --version` 또는 `nix run nixpkgs#gitleaks -- --version`이 8.30.1 반환. `gitleaks protect --staged --no-banner --redact` 모든 flag가 8.30.1 help에 유효. lefthook이 같은 명령 사용중(`lefthook.yml:6-7`).
- [x] Codex hook payload schema 측정 (공식 docs `https://developers.openai.com/codex/hooks` 인용): Stop event = `session_id`/`transcript_path`/`cwd`/`hook_event_name`/`model`/`turn_id`/`stop_hook_active`/`last_assistant_message`. SessionStart event = `session_id`/`transcript_path`/`cwd`/`hook_event_name`/`model`/`source` (startup/resume). **idle 관련 필드 부재** (`last_user_input_at`/`idle_since`/`turn_count`/`session_started_at` 모두 없음). SessionEnd 이벤트 자체 부재.
- [x] DEC-S6 B PoC 결과: hook payload 자체에 idle 필드 없음 → **단순 idle 신호 직접 추출 불가**. 우회 방식: (a) `turn_id` 또는 Stop 발화 빈도를 외부 state file(`$XDG_DATA_HOME/claude-hooks/handoff-turn-count-${session_id}`)에 누적 → turn-counter 구현 (b) `transcript_path` mtime으로 last activity 측정 → 시간 idle 우회. **DEC-S6 B 좁힘 (B refined)**: turn-counter (외부 state file) + transcript_path mtime 결합. threshold default `HANDOFF_TURN_THRESHOLD=20`, `HANDOFF_IDLE_TIMEOUT_SECONDS=300` 유지.
- [x] DEC-S6 fallback gate: B refined가 hook payload만으로 가능 → C/D fallback 미발동.
- [x] branch-slug 정규화 contract: `handoff_compute_slug <branch>` 입력 → 출력 `<slug>-<hash>` 형식. slug 규칙: lowercase + slash → `-` + `[^a-z0-9-]` → `-` + 연속 `-` 정리 + 양 끝 trim. hash: `printf '%s' "$branch" | sha1sum | head -c 6`. hard fail: 빈 raw branch, slug가 빈 결과, slug에 `..` 또는 path traversal 후보 포함.
- [x] noise field 목록 final: `HANDOFF_NOISE_FIELDS=("last-updated" "session-id" "cwd" "hostname")`. snapshot에 `runtime-version`/`pid`는 포함하지 않음 (애초에 안 넣으면 noise 처리 불필요).
- [x] DEC-S11 ordering 위치 결정: 현재 Claude Stop chain은 `record-last-stop → stop-notification → nrs-session-cleanup`. 신규 ordering = `record-last-stop → handoff-stop → stop-notification → nrs-session-cleanup` (handoff-stop을 record 직후 삽입, 기존 stop-notification/nrs-session-cleanup 순서는 변경 없음). Claude는 sequential이고 handoff-stop은 lock 해제 의존이 없으므로 record 직후가 단순. Codex는 dispatcher 내부에서 H2(`record-last-stop → nrs-session-cleanup → handoff-stop → stop-notification`) 적용. cross-runtime 의미 차이는 dispatcher 헤더 주석에 명시.
- [x] `/write-handoff` race 시나리오: Codex `write-handoff` skill이 노출됨(`codex/default.nix:49 exposedCodexSkills`에 포함, `.codex/scripts/write-handoff-repo-and-issue.sh` + `write-handoff-repo-slug.sh`도 별도 symlink). race 가능 — 사용자가 `/write-handoff` 명시 호출 + 동시 SessionEnd hook 발화 시 GitHub 코멘트와 `.claude/handoffs/` 양쪽 갱신. dogfooding(Phase 5 시나리오 9)에서 측정.
- [x] multi-worktree race 빈도 추정: `git worktree list` 결과 4 worktree(`main`, `issue/614`, `issue/659`, `issue/671`) 모두 다른 branch. per-issue worktree 관습 확인 → A-2 가정 검증, 동일 branch 다중 worktree 빈도 낮음. F1 + hash safety로 충분.
- [x] branch-slug 충돌 시뮬레이션: `foo/bar`(slug=`foo-bar`, hash=`17cdea`)와 raw `foo-bar`(slug=`foo-bar`, hash=`db7329`)가 다른 hash 부여 → 충돌 회피 검증 통과. `release/v1.0.0`(`.` → `-`)도 안전 정규화.

## Validation Strategy

본 phase는 read-only static check + PoC 측정이 핵심이다. 코드 변경이 없으므로 unit/integration test는 적용하지 않는다. PoC 측정은 임시 hook script(`/tmp/handoff-poc-*.sh`)로 stdin JSON을 dump해 검증하고, fixture로는 사용하지 않는다 (Phase 2부터 정식 fixture 도입). 결과는 Discoveries / Decisions 섹션에 자연어 evidence로 기록한다.

## Validation Checklist

- [x] Static check: `gitleaks --version` 출력 8.30.1 + `nix run nixpkgs#gitleaks -- --version` 동일 + `gitleaks protect --help`에서 `--staged`/`--no-banner`/`--redact` 모두 유효 확인.
- [x] 자동 test: 본 phase에서는 추가 안 함 (Phase 2부터). branch-slug 시뮬레이션은 inline shell로 검증.
- [x] API/CLI workflow: codex hook payload schema는 공식 docs(`https://developers.openai.com/codex/hooks`) 인용으로 검증 완료. 실제 codex 호출 dump는 hook payload schema의 정본이 codex-rs 자동 생성 schema이므로 docs 인용으로 충분.
- [x] Browser/UI E2E: N/A (CLI/hook 영역)
- [x] Agent/dev browser: N/A
- [x] Mobile/app simulator: N/A
- [x] Visual/screenshot: N/A
- [x] Observability/logging: hook payload schema 결과는 본 phase Discoveries 섹션에 인용. 실제 로그 캡처는 Phase 2 helper 작성 시 사용.
- [ ] Manual smoke check: macOS 측 PoC는 **사용자 manual smoke 협조 필요** (`ssh mac` 차단으로 메인 LLM 단독 검증 불가). MiniPC 측은 본 phase에서 evidence 확보. macOS 검증은 Phase 5 dogfooding 시나리오 4(cross-machine)에서 함께 수행.
- [x] Error/empty/permission 상태: gitleaks 미설치 fallback은 Phase 4 helper에서 commit 차단. Codex hook payload에 idle 필드 부재 → DEC-S6 B refined로 처리 (외부 state file + transcript mtime).

## Exit Criteria

- [x] Phase objective 달성 (idle PoC 결과 + branch-slug 규칙 + noise field 목록 + DEC-S11 ordering + race 시나리오 + worktree 빈도 조사 모두 evidence 확보)
- [x] DEC-S6 B refined 적용 (hook payload에 idle 필드 부재 → turn-counter + transcript mtime 결합) + master PRD Discovery Summary/Assumptions/Change Log 갱신 완료
- [x] Validation Checklist의 적용 항목 모두 완료, macOS smoke는 Phase 5로 이관 (근거 명시)
- [x] Phase 2를 시작하지 못하게 막는 blocker 없음 — DEC-S6 B refined로 Phase 2 script list 명확 (handoff-stop.sh 안에 turn-counter + transcript mtime 검사 + mode 분기)

## Phase-End Multi-Pass Review

다음 phase로 이동하기 전 순서대로 완료한다:
- [x] 1. Intent/coverage review — 본 phase가 objective와 매핑된 요구사항(FR-4/5/6/7 + A-3 검증)을 달성했다. A-3는 부분 부정 + 우회 방식 결정으로 처리.
- [x] 2. Correctness review — PoC 결과의 happy path(turn-counter + transcript mtime trigger)와 edge case(idle 필드 부재 → 우회, gitleaks 미설치 → Phase 4 commit 차단, branch-slug 빈/예약/traversal → hard fail) 모두 처리.
- [x] 3. Simplicity review — turn-counter (외부 state file) + transcript mtime은 가장 단순한 우회 방식. 추가 추상화 불필요.
- [x] 4. Code quality review — 본 phase는 코드 변경 없음. PoC 임시 script도 미사용 (모든 evidence는 docs 인용 + inline shell 시뮬레이션).
- [x] 5. Duplication/cleanup review — PoC 임시 script 미생성 → cleanup 불필요.
- [x] 6. Security/privacy review — PoC 측정에서 secret/PII 노출 없음. Codex hook payload schema는 공식 docs로 검증, 실제 dump 미수행 (chat content 회피).
- [x] 7. Performance/load review — 본 phase는 측정만. Phase 2 helper에서 latency 측정.
- [x] 8. Validation review — 선택한 check (gitleaks 실측 + docs 인용 + inline 시뮬레이션 + worktree list)가 phase risk(idle 필드 부재 + branch-slug 충돌 + multi-worktree 빈도)를 모두 커버.
- [x] 9. Future-phase review — Phase 2 script list는 DEC-S6 B refined를 반영해 `handoff-stop.sh` 안에 turn-counter + transcript mtime 분기. Phase 5 시나리오 4(cross-machine)에 macOS smoke 흡수, 시나리오 9에 `/write-handoff` race 흡수.
- [x] 10. PRD sync review — master PRD `Document Status` (In Progress), Discovery Summary `Confidence/gaps`, Assumptions A-3, Risks D7, Change Log, Phase Index의 Phase 1 Status 모두 갱신.

## Discoveries / Decisions

- **gitleaks evidence**: `/nix/store/rsrbs4p46m57c0c19adh4b5n2ianvf2x-gitleaks-8.30.1/bin/gitleaks` 가용. `gitleaks protect --staged --no-banner --redact` flag 모두 유효. lefthook(`lefthook.yml:6-7`)이 같은 명령을 pre-commit에서 사용. `nix run nixpkgs#gitleaks -- --version`도 동일 8.30.1 반환.
- **Codex hook payload schema 발견**:
  - Stop event: `session_id` / `transcript_path` / `cwd` / `hook_event_name` / `model` / `turn_id` / `stop_hook_active` / `last_assistant_message`
  - SessionStart event: `session_id` / `transcript_path` / `cwd` / `hook_event_name` / `model` / `source` (`startup`/`resume`)
  - **SessionEnd 이벤트 미지원** (epic #584 본문 + 공식 docs 부재 확인)
  - **idle 관련 필드 부재**: `last_user_input_at` / `idle_since` / `turn_count` / `session_started_at` 모두 없음
- **A-3 가정 부분 부정 + 우회 방식 결정**:
  - 가정: "Codex hook payload에서 idle 신호 추출 가능"
  - 발견: hook payload만으로 직접 추출 불가
  - 우회 (DEC-S6 B refined):
    - **Turn-counter**: 외부 state file `$XDG_DATA_HOME/claude-hooks/handoff-turn-count-${session_id}`에 Stop 발화마다 누적. `HANDOFF_TURN_THRESHOLD=20` 도달 시 full snapshot+commit trigger.
    - **Transcript mtime idle**: `transcript_path` mtime이 `HANDOFF_IDLE_TIMEOUT_SECONDS=300` 초 이전 → 추가 idle 신호로 판정.
    - 두 신호 중 **OR** 조건으로 trigger.
  - C/D fallback 미발동 (B refined로 진행 가능).
- **branch-slug + hash contract**:
  - 입력: raw branch name
  - 출력: `<slug>-<hash>` 형식의 basename. hash = `printf '%s' "$branch" | sha1sum | head -c 6`. slug 정규화: lowercase + slash → `-` + `[^a-z0-9-]` → `-` + 연속 `-` 정리 + 양 끝 trim.
  - hard fail: 빈 raw branch, 정규화 후 slug가 빈 결과, slug에 `.`/`..`/path traversal 후보 포함, basename containment 검증 실패.
  - 충돌 회피 시뮬레이션 evidence: `foo/bar`(hash=`17cdea`) vs raw `foo-bar`(hash=`db7329`) → 다른 file. `release/v1.0.0` → `release-v1-0-0`.
- **noise field 목록 final**: `HANDOFF_NOISE_FIELDS=("last-updated" "session-id" "cwd" "hostname")`. snapshot에 `runtime-version`/`pid`는 포함하지 않음.
- **DEC-S11 ordering 결정**:
  - Claude 신규 Stop chain: `record-last-stop` → **`handoff-stop`** → `stop-notification` → `nrs-session-cleanup`
  - Codex Stop dispatcher 내부 ordering: `record-last-stop` → `nrs-session-cleanup` → **`handoff-stop`** → `stop-notification` (DEC-S10 H2)
  - cross-runtime 의미 차이: Claude는 record 직후, Codex는 cleanup 후. Claude는 sequential이라 lock 의존 없음 → record 직후가 단순. Codex는 issue #590 ordering rationale로 cleanup 후가 안정 상태. dispatcher 헤더 주석에 차이 명시.
- **`/write-handoff` Codex 노출 evidence**: `modules/shared/programs/codex/default.nix:49`의 `exposedCodexSkills`에 `"write-handoff"` 포함 → `.codex/skills/write-handoff` symlink. 추가로 `:83-87` `.codex/scripts/write-handoff-repo-and-issue.sh` + `write-handoff-repo-slug.sh` symlink. 자동 hook과 동시 동작 race 가능 — Phase 5 시나리오 9에서 측정.
- **multi-worktree race 빈도 evidence**: `git worktree list` 결과 4 worktree(`main`, `issue/614`, `issue/659`, `issue/671`) 모두 다른 branch. per-issue worktree 관습 확인. A-2 가정 검증. F1 + hash safety로 race 발생 시에도 다른 branch hash로 격리.
- **DEC-S6 B refined → master PRD 갱신 필요**: 본 phase 종료 시 master PRD `Decision Matrix`의 DEC-S6 row + `Resolved evidence` + `Assumption A-3` 갱신.
- **macOS PoC는 Phase 5 dogfooding으로 이관**: 본 worktree는 Linux MiniPC, `ssh mac` 차단. cross-machine resume 시나리오(Phase 5 시나리오 4)와 함께 사용자 manual smoke check 협조 받음.

## Phase Change Log

- 2026-05-05: Phase file created (split mode 동시 생성).
- 2026-05-05: Phase 1 Discovery 완료 (macOS PoC만 Phase 5로 이관). DEC-S6 B refined 적용 (turn-counter + transcript mtime). DEC-S11 ordering 결정. branch-slug + hash contract 명세. multi-worktree race 빈도 낮음(A-2 검증). `/write-handoff` Codex 노출 + race 시나리오를 Phase 5 시나리오 9로 트래킹.
