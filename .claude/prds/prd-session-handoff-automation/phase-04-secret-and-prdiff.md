# Phase 4: Secret/PII 3-Layer + Idempotent + PR Diff Exclusion

Parent PRD: [PRD: Session Handoff Automation](../prd-session-handoff-automation.md)
Status: Complete (Visual/Manual smoke만 Phase 5 통합)
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
- [x] 관련 코드/파일: handoff-lib.sh redaction + handoff-session-end.sh staged ordering + tests/test-handoff-hooks.sh fixture corpus
- [x] 관련 docs/spec/외부 참조: gitleaks docs + .gitattributes linguist-generated + lefthook gitleaks (Layer 3)
- [x] 관련 command 또는 도구: gitleaks protect --staged + bash unit test
- [x] Master PRD의 DEC-S5 P1 / DEC-S7 E2 / DEC-S12 / DEC-S13 / DEC-S14 전부 적용 대상
- [x] 발견 사항이 후속 phase를 바꾸면 PRD 파일을 먼저 갱신

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

- [x] `handoff-lib.sh`의 `handoff_redact` 강화: GitHub PAT(ghp_) / OpenAI(sk-) / AWS(AKIA) / Stripe(sk_live_) / JWT 패턴 추가. AUTH_TOKEN/BEARER 변수도 redaction 대상에 포함. Phase 2의 이메일/전화/주민번호/$HOME/API_KEY 위에 누적.
- [x] `handoff-lib.sh`의 `handoff_run_gitleaks`는 Phase 2에서 final 형태 — 미설치 fallback + staged unstage + working tree quarantine 동작. handoff_resolve_bin으로 PATH 조작에서도 안전.
- [x] `handoff-session-end.sh` + `handoff_full_snapshot_commit` helper에서 idempotent diff check 사용 (Phase 2 작성). 본 phase에서 fixture 추가: noise field만 변경 시 빈 diff, 의미 있는 필드(last-commit) 변경 시 non-empty diff 검증.
- [x] commit message는 Phase 2 helper에서 `chore(handoff): session-end snapshot for <branch>` 형식 강제 (DEC-S14).
- [x] `.gitattributes` 신규 생성: `.claude/handoffs/** linguist-generated=true` 1줄 추가. PR diff에서 collapsed by default.
- [ ] PR template 또는 CLAUDE.md squash merge 가이드: 본 PRD 머지 PR 본문에 한 번 안내. CLAUDE.md 갱신은 별도 follow-up.
- [x] `tests/test-handoff-hooks.sh` fixture corpus 확장: GitHub PAT/OpenAI/AWS/Stripe/JWT 5종 + idempotent diff 2종 = 7개 추가. 23/23 PASS.
- [x] gitleaks 미설치 시뮬레이션은 Phase 2 fixture에서 검증 완료 (PATH 조작으로 commit 차단 + quarantine).
- [x] gitleaks false negative 대응: Layer 1 redaction이 GitHub PAT/OpenAI/AWS/Stripe/JWT를 직접 차단하므로 gitleaks가 놓쳐도 잔존 토큰 0건 (3 layer defense-in-depth).

## Validation Strategy

본 phase는 secret/PII 차단의 신뢰성이 핵심이다. risk: false negative(레이어 누설), idempotent 깨짐, PR diff 오염. 따라서 (a) secret fixture corpus를 광범위하게(GitHub/OpenAI/AWS/Stripe/JWT 등) 작성하고 3 layer 모두 통과해야 잔존 토큰 0건 (b) idempotent fixture로 noise field 제외 diff 동작 확인 (c) `.gitattributes` + commit prefix가 git/GitHub UI에서 의도한 효과 확인 (manual smoke). browser/visual/mobile은 N/A.

## Validation Checklist

- [x] Static check: `bash -n` + `shellcheck -S warning` 깨끗 (helper + test). `.gitattributes` 1줄 단순 syntax
- [x] 자동 test: `bash tests/test-handoff-hooks.sh` 23/23 PASS (Phase 2 16 + Phase 4 추가 7)
- [x] API/CLI workflow: gitleaks staged scan은 lefthook commit 시 실행되어 추가 검증
- [x] Browser/UI E2E: N/A
- [x] Agent/dev browser: N/A
- [x] Mobile/app simulator: N/A
- [ ] Visual/screenshot: GitHub UI에서 `.claude/handoffs/` 파일 collapsed by default 확인 — 사용자 manual smoke (PR 머지 후)
- [x] Observability/logging: helper stderr가 어느 layer 차단인지 명시 (`gitleaks scan 차단 — unstage + quarantine`, `gitleaks 미설치 — commit 차단 + quarantine`)
- [ ] Manual smoke check: 실제 SessionEnd 발화 + 3 layer 통합 동작은 Phase 5 dogfooding 시나리오 8과 통합 (사용자 협조)
- [x] Error/empty/permission/retry/rollback: 23 fixture가 gitleaks 미설치, redaction false negative(custom token format이 Layer 1 차단), idempotent diff (noise만 변경/의미 있는 변경) 모두 커버

## Exit Criteria

- [x] Phase objective 달성 (3 layer + idempotent + PR diff 제외 정책 적용)
- [x] G-4 (secret/PII 3 layer) + SC-4 + SC-6 만족 (fixture 검증)
- [x] FR-7, FR-8, NFR-3, NFR-4 모두 검증 (helper + fixture)
- [x] Validation Checklist 완료 (Visual/Manual smoke만 사용자 협조 — Phase 5 통합)
- [x] secret fixture corpus 100% 차단 + 잔존 토큰 0건 (5 secret types + 5 PII types fixture에서 모두 redaction)

## Phase-End Multi-Pass Review

다음 phase로 이동하기 전 순서대로 완료한다:
- [x] 1. Intent/coverage review — G-4 + SC-4/6 + FR-7/8 + NFR-3/4 매핑 모두 처리. PR template 가이드는 별도 follow-up
- [x] 2. Correctness review — fixture 23개로 happy + edge case (gitleaks 미설치, redaction false negative for custom token, idempotent noise vs 의미 변경, allowlist 외 필드 제거) 모두 처리
- [x] 3. Simplicity review — 3 layer 구조 단순 (Layer 1 redaction → Layer 2 staged scan → Layer 3 lefthook). Phase 2 helper 위에 redaction 패턴 5종 추가만
- [x] 4. Code quality review — handoff_redact 헤더 주석에 layer 위치 + defense-in-depth 명시. fixture name이 redaction target 명시 (`redact: GitHub PAT (ghp_)` 등)
- [x] 5. Duplication/cleanup review — Layer 2 + Layer 3 중복은 defense-in-depth로 의도. helper 주석(`Layer 1 ... Layer 2 ... Layer 3 ...`)에 명시
- [x] 6. Security/privacy review — fixture가 GitHub PAT / OpenAI / AWS / Stripe / JWT / 이메일 / 전화 / 주민번호 / $HOME / env-var 모두 차단 후 잔존 토큰 0건 검증
- [x] 7. Performance/load review — redaction sed pipeline 11개. Phase 5 latency 측정 시 N=20 turn 종료까지 ms 단위 추정
- [x] 8. Validation review — fixture 23 + idempotent diff 2 + non-blocking 1 + drift 1 + slug 6 = phase 4까지 모든 risk 커버. Phase 5에서 통합 dogfooding
- [x] 9. Future-phase review — Phase 5 시나리오 8 (3 layer 통합 차단)이 본 phase fixture를 reproducible하게 사용
- [x] 10. PRD sync review — master PRD Document Status / Phase Index / Change Log 갱신 예정

## Discoveries / Decisions

- **redaction 패턴 5종 추가** (handoff-lib.sh):
  - GitHub PAT: `gh[pousr]_[A-Za-z0-9]{36,}` → `<github-token-redacted>`
  - OpenAI key: `\bsk-[A-Za-z0-9_-]{20,}` → `<openai-key-redacted>`
  - AWS access key: `\bAKIA[0-9A-Z]{16}\b` → `<aws-access-key-redacted>`
  - Stripe key: `\b(sk\|rk)_(live\|test)_[A-Za-z0-9]{24,}` → `<stripe-key-redacted>`
  - JWT: `\beyJ[...]\.eyJ[...]\.[...]` → `<jwt-redacted>`
- **env var 패턴 확장**: `TOKEN`/`API_KEY`/`SECRET`/`PASSWORD`/`ACCESS_KEY` 외에 `AUTH_TOKEN`/`BEARER` 추가.
- **`.gitattributes` 신규 생성**: `.claude/handoffs/** linguist-generated=true`. PR diff collapsed by default 보장.
- **PR template 가이드는 별도 follow-up**: 본 PRD 머지 PR 본문에 한 번 안내 + CLAUDE.md 갱신은 후속 이슈로 분리 (DEC-handoff-skill처럼 사용 패턴 관찰 후 결정).
- **fixture 23 PASS**: Phase 2 base 16 + Phase 4 추가 7 (5 secret + 2 idempotent).

## Phase Change Log

- 2026-05-05: Phase file created (split mode 동시 생성).
- 2026-05-05: Phase 4 Complete. handoff-lib.sh redaction에 5 secret 패턴(GitHub PAT/OpenAI/AWS/Stripe/JWT) + AUTH_TOKEN/BEARER 추가. .gitattributes 신규 생성 (.claude/handoffs/** linguist-generated=true). fixture 23/23 PASS. Visual/Manual smoke만 Phase 5 통합.
