# Plan: codex-exec-supervised timeout budget 1800s 통일 + 측정 근거 부재 명시

## Document Status

| 필드 | 값 |
|------|-----|
| Status | Waiting On User (인수인계 대기 — 다른 머신에서 Phase 2부터 이어받음) |
| Mode | for_action |
| Source | https://github.com/greenheadHQ/nixos-config/issues/661 |
| Plan File | .claude/plans/codex-timeout-budget-1800s.md |
| Resume From | for_action.step9_approval (사용자 승인 후 Post-Implementation 1번 = Phase 2 구현 시작) |
| Last Completed Step | for_action.step6_da_apply |
| Current Phase | N/A |
| Phase Progress | N/A |
| Active Phase File | N/A |
| Last Updated | 2026-05-04 |
| Baseline | branch=issue/661, base=main tip "docs(claude-md): macOS BSD vs GNU 도구 라우팅 가이드 추가 (stat 케이스) (#660)", dirty=clean |
| External Consult | N/A (D1~D4 lock — Step 3.5 SKIP, DL-1 참조) |
| DA State | CONFIRMED |
| Pending User Questions | 0 |

## Problem (배경)

`codex-exec-supervised` wrapper의 timeout budget이 callsite별로 일관되지 않다. 측정 근거 부재 상태에서 false-positive timeout (exit 124) 위험이 있다.

- `modules/shared/scripts/codex-exec-supervised.sh:70` — wrapper default `${CODEX_EXEC_TIMEOUT_SECONDS:-600}` (10분).
- `modules/shared/scripts/codex-exec-supervised.sh:72` — hard cap 7200초 (2시간).
- `modules/shared/programs/claude/files/skills/plan-with-questions/references/consulting-step.md:141` — Step 3.5 consult-specific override `CODEX_EXEC_TIMEOUT_SECONDS=180` (1-3분).
- `consulting-step.md:156` 주석의 "1-3분 budget" 측정 근거 미기록.

upstream 보고에 따르면 `xhigh` reasoning + 큰 prompt에서 12-15분 지연 사례(openai/codex#9872)가 있으며, 600s wrapper default도 cover 못 하는 경우가 있다. Step 3.5의 180s는 더 좁은 budget이라 false-positive 가능성이 더 높다.

## Goals

- G-1: wrapper default + Step 3.5 consult budget을 1800초(30분)로 통일.
- G-2: hard cap 7200초는 D3 lock — supervisor fail-closed 상한으로 유지.
- G-3: budget 통일 근거(Codex `agents.job_max_runtime_seconds` 1800s fallback + openai/codex#9872 12-15분 사례)를 wrapper와 consulting-step.md에 명시.
- G-4: wrapper boundary validation을 검증하는 fixture 추가 (1800/7200/7201/0/-1/non-numeric).

## Non-Goals

- NG-1: wrapper의 `setsid + timeout --kill-after` 메커니즘 변경 (silent hang 방어 유지).
- NG-2: effort tier별 차등 budget 도입 (D1 보류 — 측정 누적 후 별도 issue).
- NG-3: Sentinel 무제한 escape (`CODEX_EXEC_TIMEOUT_SECONDS=0`) (supervisor fail-closed 약화).
- NG-4: callsite별 elapsed/rc/effort/prompt_bytes 계측 인프라 (후속 issue 후보).

## Success Criteria

- SC-1: `codex-exec-supervised --check`가 timeout binary, setsid binary, codex binary의 absolute path를 출력하며 exit 0으로 종료한다 (`--check` 출력에는 timeout seconds 값이 포함되지 않으므로 default 1800 적용 확인은 SC-2의 unset-env boundary fixture 또는 wrapper 파일 grep으로 수행한다 — Arbiter correctness-1 반영).
- SC-2: wrapper boundary fixture가 다음 케이스를 모두 검증한다:
  - **unset-env (default 1800s 적용)**: `unset CODEX_EXEC_TIMEOUT_SECONDS; "$supervised" --check` → exit 0 (default path 검증)
  - **explicit 1800 수용**: `CODEX_EXEC_TIMEOUT_SECONDS=1800 "$supervised" --check` → exit 0
  - **explicit 7200 수용 (cap 경계)**: → exit 0
  - **7201 실패 (cap+1)**: → exit 127, stderr에 "상한(7200)을 초과"
  - **0 실패 (양수 검증)**: → exit 127, "양수 정수만 허용"
  - **-1 실패 (음수)**: → exit 127
  - **`abc` 실패 (non-numeric)**: → exit 127
  - **신규 grep 보조 검증**: `grep -q ':-1800}' modules/shared/scripts/codex-exec-supervised.sh`로 default literal 확인 (Phase 5 정적 검증과 결합)
- SC-3: `consulting-step.md`, `for_action.md`, `tests/lib/codex-hook-expectations.sh` 본문에서 `1-3분`, `consult-specific 1-3분 budget`, `CODEX_EXEC_TIMEOUT_SECONDS=180`, `default 600`, `운영 budget 10분` 표현이 모두 제거되고 1800/30분으로 통일된다 (Arbiter regression-2 + correctness-2 반영).
- SC-4: `nrs` 빌드가 통과하여 새 wrapper가 Home Manager symlink로 반영된다.
- SC-5: 기존 `tests/test-codex-hook-fixtures.sh` invocation matrix(40초)와 live env(30초) 케이스는 그대로 통과한다 (회귀 없음).
- SC-6: 새 fixture 파일(`tests/test-codex-exec-supervised.sh`)은 호스트에 codex/setsid/timeout 부재 시 deterministic failure 대신 capability skip 패턴(WARN + return 0)으로 동작한다 (Arbiter regression-1 반영).

## Decisions

### D-1: wrapper default + Step 3.5 budget 통일

- 결정: 둘 다 1800초로 일치시킨다.
- 근거: Codex `agents.job_max_runtime_seconds` spawn agents fallback 1800초와 일치. upstream openai/codex#9872의 12-15분 지연 사례 cover. hang dwell time ≤ 30분 운영 정책.
- 출처: 이슈 #661 본문 D2 (사용자 lock).

### D-2: hard cap 7200초 유지

- 결정: `_validate_positive_int CODEX_EXEC_TIMEOUT_SECONDS ... 7200`은 변경하지 않는다.
- 근거: supervisor fail-closed 상한. 2시간 초과 정상 표본 없음. default 운영 budget(1800)을 초과하는 합법 작업의 escape는 raw codex exec 우회.
- 출처: 이슈 #661 본문 D3 (사용자 lock).

### D-3: effort tier별 차등 budget 도입 보류

- 결정: 단일 균일 1800s 유지. effort/prompt_bytes 차등은 future work.
- 근거: callsite별 elapsed p95/p99 측정 부재 상태에서 evidence-backed 결정 불가. false-positive 회피 우선.
- 출처: 이슈 #661 본문 D1 (사용자 lock).

### D-4: fixture 위치 — 별도 wrapper unit fixture 파일 분리 (재결정)

- 결정: `tests/test-codex-exec-supervised.sh`를 신설하여 wrapper boundary unit test 전용으로 둔다. `tests/test-codex-hook-fixtures.sh`에는 추가하지 않는다.
- 근거: hook fixture runner는 tomlkit bootstrap + hook sandbox + live codex matrix를 포함하며, wrapper env validation은 그 책임 경계 밖이다 (DA design-1). 통합 fixture에 boundary unit test를 섞으면 wrapper만 빠르게 회귀 검증하려 할 때 hook 인프라까지 끌고 가야 한다.
- 출처: Step 4 1차 답변 (통합) → Step 6 사용자 재결정 (분리). DL-3 supersedes 초기 D-4 안.

### D-5: wrapper L29-33 rationale 주석 — 기존 정보 보존

- 결정: 기존 fixture/oracle 상수 설명(`fixture/검증용 짧은 timeout은 호출자가 env로 명시한다 (예: invocation matrix는 INVOCATION_MATRIX_TIMEOUT_SECONDS oracle 상수로 40초 명시)`)을 유지하면서 1800초 운영 budget + openai/codex#9872 인용을 추가한다.
- 근거: callsite별 가이드 정보 손실 방지. 인수인계 가이드의 AFTER는 단순화 형태였으나 실측 코드의 풍부한 rationale을 유지하는 것이 codebase 가독성에 유리.
- 출처: Step 4 사용자 답변.

## 변경 대상 파일

| 파일 | 라인 수 | 수정 범위 |
|------|--------|-----------|
| `modules/shared/scripts/codex-exec-supervised.sh` | ~5줄 변경 | L28 default 주석, L29-33 rationale 주석, L35 hard cap 주석, L70 default 값 |
| `modules/shared/programs/claude/files/skills/plan-with-questions/references/consulting-step.md` | ~5줄 변경 | L137 주석, L141 호출 env, L156 옵션 설명 (측정 대상 구체화 포함 — Arbiter maintainability-2), L200 budget 설명, L236 validation criteria |
| `modules/shared/programs/claude/files/skills/plan-with-questions/modes/for_action.md` | 1줄 변경 | L64 Step 3.5 budget "1-3분" → "30분 이내" (Arbiter regression-2) |
| `tests/lib/codex-hook-expectations.sh` | ~2줄 변경 | L49 운영 budget "10분" → "30분", L54 wrapper default "600s" → "1800s" oracle 주석 갱신 (Arbiter correctness-2 + regression-2) |
| `tests/test-codex-exec-supervised.sh` | 신규 ~80줄 | wrapper unit fixture — boundary 7케이스 + capability skip 패턴 (DL-3 + Arbiter regression-1) |

## 실행 순서

1. **Phase 1 — 사전 확인 (실측 완료)**
   - `grep -nE 'CODEX_EXEC_TIMEOUT_SECONDS|...' modules/shared/scripts/codex-exec-supervised.sh` — L28/29/35/70/72/128 확인 (가이드와 일치).
   - `grep -nE '180|1-3분|consult-specific|budget' modules/shared/programs/claude/files/skills/plan-with-questions/references/consulting-step.md` — L137/141/156/200/236 확인.
   - `tests/test-codex-hook-fixtures.sh` 기존 fixture 패턴 확인 — `INVOCATION_MATRIX_TIMEOUT_SECONDS=40`, `LIVE_CODEX_TIMEOUT_SECONDS=30` (영향 없음 — D2 cap도 변경 없음).

2. **Phase 2 — wrapper script 변경** (`modules/shared/scripts/codex-exec-supervised.sh`)
   - L70: `${CODEX_EXEC_TIMEOUT_SECONDS:-600}` → `${CODEX_EXEC_TIMEOUT_SECONDS:-1800}`.
   - L28: header 주석 갱신 (default 600 (10분) → 1800 (30분; Codex `agents.job_max_runtime_seconds` worker fallback 1800초와 일치 — 출처는 https://developers.openai.com/codex/config-reference 의 agents 섹션. raw schema에는 `default: 1800`이 명시되지 않으므로 Codex config-reference 문서를 정본 근거로 인용한다 — Arbiter correctness-3 반영).
   - L29-33: rationale 주석 갱신 — **기존 callsite 설명(`reviewer/Arbiter/Intensity/fan-out/consult`) + fixture/oracle 상수 명시(`INVOCATION_MATRIX_TIMEOUT_SECONDS=40`)는 보존**하고, 운영 budget을 30분으로 갱신 + upstream openai/codex#9872 12-15분 인용 추가.
   - L35: hard cap 주석 갱신 — `상한 7200초 (2시간 — 어떤 reasoning level도 cover).` → `상한 7200초 (2시간 — supervisor fail-closed 상한. default 운영 budget(1800초)을 초과하는 합법 작업의 escape는 raw codex exec 우회로 처리).`.

3. **Phase 3 — consulting-step.md 변경** (D1~D4 lock 문서)
   - L141: `CODEX_EXEC_TIMEOUT_SECONDS=180` → `CODEX_EXEC_TIMEOUT_SECONDS=1800`.
   - L137: `180으로 1-3분 budget 강제 (consult-specific override).` → `1800으로 wrapper default와 동일한 30분 budget 적용 (consult-specific 단축 override 폐지 — 측정 누적 후 재평가 대상).`.
   - L156: 옵션 설명에서 `consult-specific 1-3분 budget. wrapper default(600s = 10분)와 분리하여 자문 호출의 짧은 budget을 강제한다.` → `wrapper default(1800s = 30분)와 동일. Step 3.5 consult는 high/xhigh reasoning + 자문 schema 처리에 30분까지 허용한다. consult-specific 단축 override는 callsite elapsed p95/p99 측정이 누적된 뒤 재평가 대상이다 (Arbiter maintainability-2 반영 — 측정 대상 구체화).`. timeout 시 fallback 동작 설명은 기존 그대로 유지.
   - L200: budget 설명 `1-3분 (high)` → `30분 이내 (high/xhigh 모두)`.
   - L236: validation criteria `1-3분 내 결과 도착` → `30분 이내 결과 도착`.

4. **Phase 4 — wrapper unit fixture 신설** (`tests/test-codex-exec-supervised.sh` — DL-3 + Arbiter regression-1)
   - 새 파일 신설 (책임 경계 분리 — hook fixture runner와 무관한 wrapper env validation 전용).
   - **Capability skip 패턴**: 시작부에 `command -v codex >/dev/null && command -v setsid >/dev/null && command -v timeout >/dev/null` 또는 wrapper의 `--check` exit code로 dependency 가용성 probe. 부재 시 `WARN: codex/setsid/timeout 부재 — skip` 출력 후 exit 0 (LIVE_MODE skip 패턴 재사용).
   - **Test cases (7개)**:
     - `test_unset_env_default_path`: `unset CODEX_EXEC_TIMEOUT_SECONDS; "$supervised" --check` → exit 0 (default 1800 path 검증)
     - `test_explicit_1800_accepted`: exit 0
     - `test_explicit_7200_accepted`: exit 0 (cap 경계)
     - `test_explicit_7201_rejected`: exit 127, stderr "상한(7200)을 초과"
     - `test_zero_rejected`: exit 127, stderr "양수 정수만 허용"
     - `test_negative_rejected`: exit 127
     - `test_non_numeric_rejected`: exit 127
   - **함수명 명확화**: "1800 default 검증"이 아닌 "1800 explicit override 수용 검증"임을 함수명에서 구분 (Arbiter maintainability-1).
   - `supervised` resolution: `command -v codex-exec-supervised` 또는 `$REPO_ROOT/modules/shared/scripts/codex-exec-supervised.sh` (기존 fixture 패턴 재사용).
   - 실행 entry: `bash tests/test-codex-exec-supervised.sh`. 기존 `tests/test-codex-hook-fixtures.sh`는 변경 없음.

5. **Phase 5 — 정적 검증**
   - `grep -q ':-1800}' modules/shared/scripts/codex-exec-supervised.sh`
   - `grep -q 'CODEX_EXEC_TIMEOUT_SECONDS=1800' modules/shared/programs/claude/files/skills/plan-with-questions/references/consulting-step.md`
   - `! grep -q ':-600}' modules/shared/scripts/codex-exec-supervised.sh`
   - `! grep -q 'CODEX_EXEC_TIMEOUT_SECONDS=180\b' modules/shared/programs/claude/files/skills/plan-with-questions/references/consulting-step.md`
   - `! grep -q '1-3분' modules/shared/programs/claude/files/skills/plan-with-questions/references/consulting-step.md`
   - `! grep -q '1-3분' modules/shared/programs/claude/files/skills/plan-with-questions/modes/for_action.md` (Arbiter regression-2)
   - `! grep -qE '(default 600|운영 budget.*10분)' tests/lib/codex-hook-expectations.sh` (Arbiter correctness-2 + regression-2)
   - `grep -q '7200' modules/shared/scripts/codex-exec-supervised.sh` (D2 lock 확인)

6. **Phase 6 — 동적 검증**
   - 새 wrapper unit fixture 실행: `bash tests/test-codex-exec-supervised.sh`.
   - `nrs` 빌드 — 새 wrapper가 Home Manager로 symlink되는지 확인.
   - `codex-exec-supervised --check` — `OK (timeout=<path> setsid=<path> codex=<path>)` 형태 출력 확인 (timeout seconds 값은 출력에 없음 — Arbiter correctness-1 반영).

7. **Phase 7 — 비회귀 확인**
   - `grep -rn 'CODEX_EXEC_TIMEOUT_SECONDS' modules/ tests/` — `consulting-step.md` (1800), `tests/test-codex-hook-fixtures.sh` (live 30s, invocation 40s), 새 `tests/test-codex-exec-supervised.sh` (boundary 케이스) 외 다른 명시적 override가 있으면 정합성 검토. 없으면 통과.
   - `grep -rnE '(180\b|600\b|1-3분|10분)' tests/lib/ modules/shared/programs/claude/files/skills/plan-with-questions/` — stale 인용 잔존 시 추가 정리.

## Validation Strategy

`~/.claude/skills/plan-with-questions/references/validation-paths.md` catalog 기준 risk-appropriate mix:

- **정적 검증 (grep)**: BEFORE/AFTER 문자열 부재·존재 단언으로 회귀 빠르게 catch (Phase 5). 비용 거의 없음.
- **wrapper unit fixture**: `--check` mode로 boundary 6개 케이스 검증 (Phase 4·6). codex 호출 없이 빠름.
- **빌드 검증**: `nrs` 통과로 Nix wrapper의 timeout/setsid binary path 주입이 정상 동작하는지 확인 (Phase 6).
- **수동 smoke**: `codex-exec-supervised --check` 직접 호출 (Phase 6).
- **비회귀 grep**: 다른 callsite에 명시적 override 잔존 여부 cross-check (Phase 7).

라이브 codex 호출 회귀 테스트는 비용 대비 효익이 낮다 (D2 cap 변경 없음 + invocation matrix 40s는 영향 없음 — 새 default 1800은 invocation matrix가 명시 override하므로 도달 안 함). 라이브 회귀는 수행하지 않는다.

## 사이드이펙트 + 대응

| 영향 | 대응 |
|------|------|
| 다른 callsite (run-da reviewer/Auditor/Arbiter, codex-fan-out, parallel-audit, using-codex-exec generic template) wrapper default를 사용 — 600 → 1800 자동 상향 | Phase 7 grep으로 명시적 override 잔존 여부 확인. 없으면 자동 상향이 의도. 있으면 정합성 검토 후 별도 결정. |
| `tests/test-codex-hook-fixtures.sh` 기존 invocation matrix 40초 / live 30초 fixture | 영향 없음 — 두 케이스는 명시적 env override로 default 무시. D2 cap 변경 없음. |
| Step 3.5 timeout이 더 길어져 false-positive 감소 + 사용자 대기 시간 증가 가능 | timeout 시 fallback (자문 없이 Step 4 진행 + `[UNVERIFIED: timed out]`) 메커니즘은 그대로 유지. 사용자 대기 의사 확인 옵션도 보존. |
| Hard cap 7200 초과 합법 작업의 escape 경로 모호성 | wrapper L35 주석에 "raw codex exec 우회로 처리" 명시 (Phase 2 변경). 코드 변경 없음. |

## 롤백 가능성

- 단일 PR로 묶어 git revert 단위로 롤백 가능.
- D1~D4 lock 결정에 변동 없음을 가정. force push 사용하지 않음.
- 만약 30분 budget이 운영 환경에서 hang dwell time을 너무 길게 만들면 wrapper default만 단일 PR로 되돌릴 수 있다 (D2 cap은 그대로).

## Open Questions

- [ ] Phase 7에서 `tests/lib/codex-hook-expectations.sh`, `for_action.md`, `consulting-step.md` 외 다른 위치에 wrapper default 600s / Step 3.5 budget 180s / 1-3분 / 10분 표현이 박제되어 있는지 추가 확인 — 없으면 closed. [UNVERIFIED until Phase 7]

## Decision Log (ADR 미니)

### DL-1: Step 3.5 외부 자문 SKIP

- **Status**: accepted
- **Context**: 이슈 #661 본문이 D1~D4 결정과 변경 라인을 lock 상태로 들어왔다. 인수인계 코멘트도 "결정 lock 존중. 새 trade-off는 별도 issue로 분리" 명시.
- **Decision**: Step 3.5 외부 LLM 자문 호출을 SKIP한다. 메인 LLM은 trade-off 분석을 수행하지 않고 lock된 D1~D4를 plan에 그대로 반영한다. consulting-step.md 자체가 본 plan의 변경 대상이므로 self-reference 우려도 있다.
- **Consequences**:
  - de-anchoring 전처리 없음 — 단, lock된 결정이라 anchoring 자체가 비목표.
  - 사용자가 추후 D1 (effort tier 차등) 재평가 시 별도 issue로 분리하여 자문 호출.
  - plan 본문은 Step 1-2 실측 + Step 4 사용자 답변만 evidence로 사용.
- **External Consult**: N/A.

### DL-2: fixture 위치 (기존 통합 vs 신규 분리) — 기존 통합 [SUPERSEDED]

- **Status**: superseded
- **Context**: 인수인계 가이드는 두 옵션 모두 `[UNVERIFIED]`로 두었다. wrapper boundary fixture는 sandbox 의존 없이 빠르므로 통합 entry point 유지가 자연스럽다.
- **Decision**: `tests/test-codex-hook-fixtures.sh`에 새 test 함수 + run_test 등록.
- **Consequences**:
  - 기존 fixture entry point 일관 유지.
  - sandbox/oracle 인프라 재사용 가능 — 단, `--check` 모드라 의존 없음.
- **External Consult**: N/A (사용자 답변 lock).
- **Superseded By**: DL-3.

### DL-3: fixture 위치 — 별도 wrapper unit 파일 분리

- **Status**: accepted
- **Context**: 계획 검토 단계에서 Design 관점 검토자가 책임 경계 분리를 권고. hook fixture runner는 tomlkit bootstrap + hook sandbox + live codex matrix를 포함하지만 wrapper env validation은 그 책임 경계 밖. 검증자도 같은 권고를 confirmed로 판정.
- **Decision**: `tests/test-codex-exec-supervised.sh`를 신설하여 wrapper boundary unit test 전용으로 둔다. `tests/test-codex-hook-fixtures.sh`에는 추가하지 않는다. 사용자가 Step 6에서 권고 수용으로 재결정.
- **Consequences**:
  - 향후 wrapper 회귀만 빠르게 검증할 때 hook 인프라(tomlkit 등) 의존 없이 실행 가능.
  - 새 fixture 파일에 capability skip 패턴(codex/setsid/timeout 부재 시 WARN+exit 0) 추가 — 검토자 권고 반영.
  - 기존 `tests/test-codex-hook-fixtures.sh`는 변경 없음 (회귀 영향 없음).
  - hook fixture와 wrapper unit fixture 두 entry point 병존 — CI에서 둘 다 실행해야 한다 (현재 nrs는 fixture를 직접 실행하지 않으므로 영향 없음).
- **External Consult**: N/A (검토자 권고 + 사용자 재결정).

### DL-4: 검토자 권고 자동 반영

- **Status**: accepted
- **Context**: 계획 검토 단계의 4개 관점(Correctness, Design, Regression, Maintainability) 각각에서 confirmed 판정을 받은 권고들이 수집됐다. 재판정 트리거 조건에 해당하는 항목은 없었다.
- **Decision**: 7건은 자동 반영(SC-1 표현 갱신, 변경 surface 확장, fixture capability skip, 측정 대상 구체화, fixture 함수명 명확화, agents.job_max_runtime_seconds 출처 보강), Design 관점의 fixture 분리 권고만 사용자 lock 답변과 충돌하여 질문 도구로 사용자 재결정 → 권고 수용 (DL-3).
- **Consequences**:
  - 변경 surface가 3 파일에서 5 파일로 확장 (`tests/lib/codex-hook-expectations.sh`, `for_action.md` 추가).
  - Phase 4가 통합 fixture 추가 → 신규 fixture 파일 신설로 변경.
  - SC-1 검증 방법이 `--check` 출력 의존에서 wrapper grep + fixture 결과로 분리.
  - upstream 인용 출처가 raw schema → Codex 공식 config-reference 문서로 보강.
- **External Consult**: N/A.

## Change Log

- 2026-05-04: Step 4.5 plan 파일 초기화. Step 1-2 실측 라인 번호 + Step 4 사용자 답변 (Q1=기존 fixture 통합, Q2=rationale 정보 보존) 반영. 검토 단계 진입 전 상태.
- 2026-05-04: 계획 검토 단계 완료 → 4개 관점 권고 8건 수집 → 검증자가 모두 confirmed 판정. Design 관점의 fixture 분리 권고는 사용자 재결정으로 수용 (DL-2 supersede → DL-3 accepted). 나머지 7건 자동 반영 → SC-1 표현 갱신, SC-2/SC-3/SC-6 추가, 변경 대상에 `tests/lib/codex-hook-expectations.sh` + `for_action.md` 추가, Phase 2-3-4-5-7 본문 갱신, agents.job_max_runtime_seconds 출처를 Codex config-reference로 보강. 검토 단계 완료, Step 6 반영 완료.
- 2026-05-04: 사용자 explicit stop — 다른 맥북으로 인수인계. Status=Waiting On User, Resume From=for_action.step9_approval. 본 세션은 plan 파일 commit + push까지만 수행하고 Post-Implementation 1번(Phase 2 구현)은 시작하지 않는다.

## Post-Implementation 자동 수행 범위

`~/.claude/skills/plan-with-questions/references/post-implementation.md` 1~7번 절차를 자동 수행 (default). 생략 단계 없음. 자동 진행 범위는 tracked write·local commit·GitHub PR write를 포함한다.
