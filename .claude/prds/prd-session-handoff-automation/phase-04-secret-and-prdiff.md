# Phase 4: Secret/PII 3-Layer + Idempotent + PR Diff Exclusion

Parent PRD: [PRD: Session Handoff Automation](../prd-session-handoff-automation.md)
Status: Not Started
Last Updated: 2026-05-05

## Objective

snapshot에 secret/PII가 절대 commit되지 않도록 3 layer 방어를 완성한다 (allowlist + redaction + gitleaks staged scan, Phase 2의 helper에 이미 일부 구현됨). 그리고 의미 없는 변경 시 commit이 발생하지 않도록 idempotent diff check를 적용 (DEC-S7 E2). PR diff 오염 회귀를 차단하는 정책(`chore(handoff):` prefix + `.gitattributes linguist-generated` + PR template 가이드)을 적용 (DEC-S14).

## Context From Master PRD

- Goals covered: G-4 (3 layer 방어), G-5 (non-blocking).
- Success Criteria: SC-4 (secret/PII fixture corpus 차단), SC-6 (idempotent).
- Requirements covered: FR-7 (gitleaks 미설치 fallback), FR-8 (chore(handoff) prefix), NFR-3 (idempotent), NFR-4 (defense-in-depth).
- Key scenarios touched: Scenario 5 (Secret/PII redaction).

## Phase Discovery Gate

코드 편집 전에 재확인한다:
- [ ] 관련 코드/파일: Phase 2에서 작성한 `handoff-lib.sh`의 allowlist + redaction + gitleaks helper, `handoff-session-end.sh`의 staged ordering, `tests/test-handoff-hooks.sh`의 secret fixture corpus
- [ ] 관련 docs/spec/외부 참조: gitleaks docs (`protect --staged --no-banner --redact`), `.gitattributes` linguist-generated docs, repo `lefthook.yml`(pre-commit gitleaks 사용 — Layer 3)
- [ ] 관련 command 또는 도구: `gitleaks protect --staged`, `git diff --staged`, `git ls-files --others`
- [ ] Master PRD의 DEC-S5 P1 (gitleaks 미설치 시 commit 차단), DEC-S7 E2 (idempotent diff), DEC-S12 (allowlist), DEC-S13 (staged ordering), DEC-S14 (PR diff 제외) 전부 적용 대상
- [ ] 발견 사항이 후속 phase를 바꾸면 PRD 파일을 먼저 갱신

## Scope

### In Scope
- **Layer 1 — allowlist + redaction** (Phase 2 helper의 `handoff_write_snapshot` final 강화):
  - allowlist 외 모든 필드 제거
  - PII 패턴 redaction: 이메일(`<email>` → `<email-redacted>`), 전화번호(`010-NNNN-NNNN`), 주민번호 형태, 절대경로 (`$HOME/...` → `~/...`, repo 외 절대경로 → `<abs-path-redacted>`), env var 값 (특히 `*_TOKEN`/`*_KEY`/`*_SECRET` 변수의 값)
  - active-files의 절대경로 → repo-root 상대경로 변환
- **Layer 2 — gitleaks staged ordering** (Phase 2 helper의 `handoff_run_gitleaks` final 강화):
  - 작성 → redaction → `umask 077` 임시 파일 → allowlist + redaction 검증 → `git add -- .claude/handoffs/<slug>.md` → `gitleaks protect --staged --no-banner --redact` → 통과 시 commit, 실패 시 `git restore --staged .claude/handoffs/<slug>.md` + working tree 파일 quarantine
- **Layer 3 — pre-commit gitleaks** (lefthook 기존, 변경 없음 — defense-in-depth로 두 번째 staged scan)
- **Idempotent diff check** (DEC-S7 E2): `handoff-session-end.sh` 안에서 snapshot 작성 후 `handoff_compute_diff` 호출 → noise field 제외한 diff가 빈 경우 commit skip
- **PR diff 제외 정책** (DEC-S14):
  - commit prefix `chore(handoff):` 강제 (helper에서 commit message 생성 시 강제)
  - `.gitattributes`에 `.claude/handoffs/** linguist-generated=true` 추가 (GitHub UI에서 collapsed by default)
  - `CLAUDE.md` 또는 PR template에 squash 머지 시 `chore(handoff):` commit은 PR 본문에서 제외하는 가이드 추가
- **secret/PII fixture corpus 강화** (Phase 2 fixture 확장):
  - GitHub token, OpenAI API key, AWS access key, Stripe secret key, JWT 형태
  - 이메일/전화/주민번호 형태
  - 절대경로 (`/home/greenhead/...`, `/Users/greenhead/...`), env var 값 (`API_TOKEN=...`)
  - 3 layer 모두 통과 후 잔존 토큰이 없는지 확인

### Out of Scope
- helper의 기본 구조 변경 (Phase 2)
- hook 등록 변경 (Phase 3)
- dogfooding round-trip (Phase 5)

## Implementation Checklist

- [ ] `handoff-lib.sh`의 `handoff_write_snapshot` final: allowlist filter + PII redaction(이메일/전화/주민번호/절대경로/env var 값) 강화. fixture로 검증
- [ ] `handoff-lib.sh`의 `handoff_run_gitleaks` final: staged ordering 명확화 + 실패 시 unstage + quarantine 동작 확인. fixture로 검증
- [ ] `handoff-session-end.sh`에서 idempotent diff check 호출: noise field 제외 diff 빈 경우 commit skip. 시나리오별 fixture 추가 (timestamp만 변경, session-id만 변경, 둘 다 변경 + last-commit 동일 등)
- [ ] commit message helper 작성: `chore(handoff): session-end snapshot for <branch>` 형식 강제. body에 last-commit + active-files 요약 (allowlist 적용)
- [ ] `.gitattributes` 파일 생성/수정: `.claude/handoffs/** linguist-generated=true` 추가 (repo root). 기존 `.gitattributes` 있으면 append
- [ ] `CLAUDE.md` 또는 새 PR template에 squash merge 시 `chore(handoff):` commit 제외 가이드 추가
- [ ] `tests/test-handoff-hooks.sh` secret fixture corpus 확장: GitHub/OpenAI/AWS/Stripe/JWT/이메일/전화/주민번호/절대경로/env var 값 모두 포함. 3 layer 모두 차단 검증
- [ ] gitleaks 미설치 시뮬레이션 (`PATH=...`로 gitleaks 제거): commit 차단 + stderr 알림 + exit 0 검증
- [ ] gitleaks false negative 시뮬레이션: gitleaks가 놓칠 수 있는 패턴 (custom secret format)을 fixture로 삽입하고 Layer 1 redaction이 차단하는지 확인

## Validation Strategy

본 phase는 secret/PII 차단의 신뢰성이 핵심이다. risk: false negative(레이어 누설), idempotent 깨짐, PR diff 오염. 따라서 (a) secret fixture corpus를 광범위하게(GitHub/OpenAI/AWS/Stripe/JWT 등) 작성하고 3 layer 모두 통과해야 잔존 토큰 0건 (b) idempotent fixture로 noise field 제외 diff 동작 확인 (c) `.gitattributes` + commit prefix가 git/GitHub UI에서 의도한 효과 확인 (manual smoke). browser/visual/mobile은 N/A.

## Validation Checklist

- [ ] Static check: `bash -n` + `shellcheck` (helper + scripts), `.gitattributes` syntax valid
- [ ] 자동 test: `tests/test-handoff-hooks.sh`의 expanded fixture corpus 모두 통과
- [ ] API/CLI workflow: gitleaks staged scan이 실제 fixture에서 secret 차단, 미설치 시 commit 차단 확인
- [ ] Browser/UI E2E: N/A
- [ ] Agent/dev browser: N/A
- [ ] Mobile/app simulator: N/A
- [ ] Visual/screenshot: GitHub UI에서 `.claude/handoffs/` 파일이 collapsed by default 확인 (manual)
- [ ] Observability/logging: secret 차단 시 stderr에 충분한 진단 정보 (어느 layer가 차단했는지)
- [ ] Manual smoke check: 실제 chat content에 가짜 token을 넣어 SessionEnd 발화 → 3 layer 모두 차단 확인. idempotent 동작 (같은 chat 두 번 종료 시 두 번째 commit 없음) 확인
- [ ] Error/empty/permission/retry/rollback: gitleaks 미설치, scan 실패, redaction false negative, idempotent diff 모두 시뮬레이션

## Exit Criteria

- [ ] Phase objective 달성 (3 layer + idempotent + PR diff 제외 정책 적용)
- [ ] G-4 (secret/PII 3 layer) + SC-4 + SC-6 만족
- [ ] FR-7, FR-8, NFR-3, NFR-4 모두 검증
- [ ] Validation Checklist 완료
- [ ] secret fixture corpus 100% 차단 + 잔존 토큰 0건

## Phase-End Multi-Pass Review

다음 phase로 이동하기 전 순서대로 완료한다:
- [ ] 1. Intent/coverage review — G-4 + SC-4/6 + FR-7/8 + NFR-3/4 모두 매핑됨
- [ ] 2. Correctness review — happy path + edge case (gitleaks 미설치/false negative, idempotent 깨짐 케이스, allowlist 누락, redaction false negative) 모두 처리
- [ ] 3. Simplicity review — 3 layer 구조가 단순. 불필요한 layer 추가 없음
- [ ] 4. Code quality review — helper 함수 이름이 layer 책임을 명확히 나타냄, fixture 코퍼스가 reproducible
- [ ] 5. Duplication/cleanup review — Layer 2 (hook script gitleaks) + Layer 3 (lefthook gitleaks) 중복이 의도된 defense-in-depth임을 helper 주석에 명시
- [ ] 6. Security/privacy review — secret/PII fixture corpus가 실제 leak risk를 충분히 모사. **잔존 토큰 0건 검증**
- [ ] 7. Performance/load review — gitleaks scan 추가에 따른 latency 측정 (SessionEnd만 발화하므로 사용자가 인지하지 못하는 비차단)
- [ ] 8. Validation review — fixture corpus 광범위 + idempotent fixture + manual smoke 조합이 risk 모두 커버
- [ ] 9. Future-phase review — Phase 5 dogfooding 시나리오 8 (3 layer 차단)이 본 phase 결과를 검증할 수 있도록 fixture가 reproducible
- [ ] 10. PRD sync review — master PRD `Document Status`, `Change Log`, Phase Index의 Phase 4 Status 갱신

## Discoveries / Decisions

- (작성 예정 — Phase 4 진행 중 evidence 누적)

## Phase Change Log

- 2026-05-05: Phase file created (split mode 동시 생성).
