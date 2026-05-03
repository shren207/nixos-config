# Resume State

작성 중·구현 중인 plan을 다음 세션에서 정확한 단계로 이어가기 위한 메커니즘. `Resume From` enum 카탈로그 + baseline drift 검증 알고리즘 + 불변조건.

## Resume From enum 카탈로그

`Resume From` 필드는 자유문이 아니라 enum 값을 사용한다. enum은 `<mode>.<step_id>` 형식으로 기계적 식별 가능해야 한다.

### for_action

| Resume From | 진입 조건 |
|-------------|----------|
| `for_action.step1_validity` | 이슈 유효성 판단 (시작) |
| `for_action.step2_exploration` | 코드베이스 탐색 + 로컬 재현 |
| `for_action.step3_questions` | 질문 수집 |
| `for_action.step3_5_consulting` | Step 3.5 외부 자문 시작 (background 발사) |
| `for_action.step3_5_awaiting` | Step 3.5 결과 대기 (background 진행 중) |
| `for_action.step4_user_questions` | 사용자에게 질문 제시 (자문 결과 통합) |
| `for_action.step4_awaiting_user` | 사용자 답변 대기 |
| `for_action.step5_da` | Step 4.5에서 만든 공식 plan 파일을 context로 `/run-da for_plan` 호출 |
| `for_action.step6_da_apply` | Step 4.5에서 만든 같은 plan 파일에 DA 결과 반영 |
| `for_action.step7_plan_mode_entry` | 계획 추적 도구 진입 + 기존 plan 파일 바인딩 |
| `for_action.step8_plan_writing` | 기존 plan 파일 review/refine |
| `for_action.step9_approval` | 승인 요청 도구 호출 |
| `for_action.step9_awaiting_approval` | 사용자 승인 대기 |

### for_action Step 4.5와 resume

Step 4.5는 별도 `Resume From` enum을 만들지 않는다. 이 단계는 공식 `.claude/plans/<slug>.md` 파일을 atomic하게 초기화하고 즉시 다음 blocking step인 `for_action.step5_da`를 `Resume From`에 기록한다.

초기 plan 파일은 다음 resume 관련 값을 반드시 포함한다:

- `Resume From`: `for_action.step5_da`
- `Last Completed Step`: `for_action.step4_user_questions`
- `Baseline`: Step 4.5 파일 생성 시점의 branch/HEAD/dirty 값
- `DA State`: `PRE_DA`

Step 5/6 진행 중에는 [`plan-file-template.md`](./plan-file-template.md#da-state-값)의 `DA State`를 함께 사용한다:

- `PRE_DA` + `Resume From=for_action.step5_da`: DA를 아직 시작하지 않았으므로 Step 5로 진입한다.
- `RUNNING`: DA가 시작된 상태다. `Change Log`의 최신 DA Run ID와 started-at을 확인한다. 같은 active session에서 원 run이 아직 진행 중임을 확인할 수 있으면 기다리고, 세션 재개 후 active 여부를 확인할 수 없거나 durable verdict가 없으면 새 DA Run ID로 같은 plan 파일을 입력해 DA를 재실행한다. 나중에 도착한 이전 run verdict는 stale result로 기록하고 적용하지 않는다.
- `APPLYING` + `Resume From=for_action.step6_da_apply`: DA verdict를 수신했으므로 `Change Log`의 최신 DA Run ID와 일치하는 DA result path 또는 verdict 요약을 읽고 Step 6 반영 상태를 점검한다. 기록이 없거나 run id가 맞지 않으면 같은 plan 파일을 입력으로 DA를 재실행하고 Change Log에 재실행 사유를 기록한 뒤 반영한다.
- `CONFIRMED`/`SKIPPED`: Step 6 이후의 첫 미완료 blocking step으로 이동한다.
- `BLOCKED`/`NEEDS_USER`: 질문 도구로 사용자 판단을 요청하거나 하위 스킬 BLOCKED 계약을 따른다.

따라서 세션이 Step 5 직전이나 Step 6 반영 중 끊겨도 메인 LLM은 기존 plan 파일을 읽고 baseline drift 검증 후 `for_action.step5_da` 또는 `for_action.step6_da_apply`로 복귀한다.

### for_issue

`for_issue`는 산출물이 이슈(plan 파일 없음)라 본 enum은 적용되지 않는다. 진행 상태는 issue body 또는 `/write-handoff` 산출물에 기록된다. for_action 전환 시점부터는 `for_action.*` enum이 사용된다.

### for_prd

`for_prd`는 plan-with-questions가 Step 1-4와 Step 5-6을 거친 뒤 PRD 규약을 따라 `.claude/prds/prd-<feature>.md`에 직접 작성한다. `for_action` Step 4.5 plan 파일 초기화는 적용하지 않는다. PRD 작성 전에는 아래 `for_prd.*` enum을 사용하고, PRD 작성 후에는 PRD master 파일의 Document Status `Next Blocking Step` / `Last Completed Step`이 정본이다.

| Resume From | 진입 조건 |
|-------------|----------|
| `for_prd.candidate_detected` | task-size-routing 후보 감지 + 사용자 알림 대기 |
| `for_prd.step5_da` | PRD draft/context 기준 `/run-da for_plan` 호출 |
| `for_prd.step6_da_apply` | PRD draft/context와 candidate phase structure에 DA 결과 반영 |
| `for_prd.user_confirmed` | 사용자 동의 후 PRD 작성 직전 |

### for_prd PRD 작성 후 Next Blocking Step

PRD 작성 후의 진행은 PRD master Document Status에서 `Current Phase` / `Active Phase File` / `Status` / `Next Phase Materialization` / `Next Blocking Step` / `Last Completed Step` 필드로 추적한다. `Next Blocking Step`은 첫 미완료 blocking step만 가리키며, 아래 enum만 허용한다. `File Mode: Single`은 `PI-*` 7단계 chain을 사용하고 `PHASE-*` 값을 쓰지 않는다. `File Mode: Split`은 phase 구현/감사에 `PHASE-*` 값을 사용하고, 모든 phase checkpoint 이후 final closeout에서만 `PI-FINAL-REVIEW` 이후 값을 사용한다.

| Next Blocking Step | 진입 조건 |
|---|---|
| `N/A` | PRD 작성 전, 또는 모든 phase/final closeout 완료 |
| `PHASE-MATERIALIZE` | 승인된 phase-start materialization gate에 따라 phase 파일과 master materialization update 작성 필요 |
| `PHASE-IMPLEMENT` | active phase 구현 진행 필요 |
| `PHASE-COMMIT` | active phase 구현 변경 커밋 필요 |
| `PHASE-RUN-DA` | active phase diff 기준 `/run-da for_pr` 필요 |
| `PHASE-PARALLEL-AUDIT` | active phase diff 기준 `/parallel-audit` 필요 |
| `PHASE-END-PRD-SYNC` | active phase validation, phase-end review, Finding Disposition, master/phase PRD sync 필요 |
| `PHASE-END-COMMIT` | phase-end PRD sync 변경 커밋 checkpoint 필요 |
| `PI-IMPLEMENT` | single-file PRD 승인 범위의 구현 진행 필요 |
| `PI-COMMIT` | single-file PRD 구현 변경 커밋 필요 |
| `PI-RUN-DA` | single-file PRD diff 기준 `/run-da for_pr` 필요 |
| `PI-PARALLEL-AUDIT` | single-file PRD diff 기준 `/parallel-audit` 필요 |
| `PI-FINAL-REVIEW` | 모든 phase checkpoint 이후 final review gate 승인 또는 Final Multi-Pass Review 필요 |
| `PI-FOLLOWUP-COMMIT` | final review가 요구한 follow-up 변경 커밋 필요. clean review면 `Last Completed Step=PI-FOLLOWUP-COMMIT`으로 갱신하고 Change Log에 `PI-FOLLOWUP-COMMIT: N/A`를 기록한 뒤 `Next Blocking Step=PI-CREATE-PR`로 이동 |
| `PI-CREATE-PR` | final PR write gate 승인 또는 승인된 PR title/body GitHub write 필요 |

각 step 시작 전 `Next Blocking Step`을 현재 step으로 확정하고, 완료 즉시 `Last Completed Step`을 현재 step으로 갱신한 뒤 다음 blocking step을 기록한다.

Single-file PRD stable step contract:

Single-file mode의 `PI-*` dependency closure와 자동 수행 범위는 [`./post-implementation.md`](./post-implementation.md)의 7단계 표가 SSOT다. PRD master Document Status에는 같은 stable step ID를 `Next Blocking Step` / `Last Completed Step`에 그대로 기록한다.

Phase-scoped stable step contract (split mode only):

| Stable step ID | 수행 내용 |
|---|---|
| `PHASE-MATERIALIZE` | 승인된 phase file draft body를 phase 파일로 작성하고 master PRD `Active Phase File` / `Next Phase Materialization`을 갱신 |
| `PHASE-IMPLEMENT` | 해당 phase 구현 진행 |
| `PHASE-COMMIT` | 해당 phase 구현 커밋 |
| `PHASE-RUN-DA` | 해당 phase diff 기준 `/run-da for_pr` |
| `PHASE-PARALLEL-AUDIT` | 해당 phase diff 기준 `/parallel-audit` |
| `PHASE-END-PRD-SYNC` | phase validation, phase-end review, Phase-End Finding Disposition 표, phase 파일과 master PRD sync 반영 |
| `PHASE-END-COMMIT` | phase-end finding disposition이 모두 satisfied 또는 explicitly deferred인 상태에서 `PHASE-END-PRD-SYNC`가 만든 phase/master PRD 변경을 커밋하고 다음 phase-start materialization gate 또는 final closeout gate 전 checkpoint로 고정 |

Phase-scoped dependency closure:

| Stable step ID | Requires |
|---|---|
| `PHASE-MATERIALIZE` | 승인된 phase file draft body + 승인된 master PRD materialization update |
| `PHASE-IMPLEMENT` | `PHASE-MATERIALIZE` |
| `PHASE-COMMIT` | `PHASE-IMPLEMENT` |
| `PHASE-RUN-DA` | `PHASE-COMMIT` |
| `PHASE-PARALLEL-AUDIT` | `PHASE-RUN-DA` |
| `PHASE-END-PRD-SYNC` | `PHASE-PARALLEL-AUDIT` |
| `PHASE-END-COMMIT` | `PHASE-END-PRD-SYNC` + phase-end finding disposition table all satisfied/deferred |

Phase-scoped default display string:
`Phase-scoped 자동 수행: PHASE-MATERIALIZE, PHASE-IMPLEMENT, PHASE-COMMIT, PHASE-RUN-DA, PHASE-PARALLEL-AUDIT, PHASE-END-PRD-SYNC, PHASE-END-COMMIT (default)`

Phase-end remediation contract:
- Docs/PRD-only remediation이 승인된 phase scope 안에 머물면 `PHASE-END-PRD-SYNC`에 기록하고 `PHASE-END-COMMIT`으로 커밋한다.
- Implementation-code remediation은 기존 phase-scoped chain을 다시 탄다: `PHASE-IMPLEMENT` remediation -> `PHASE-COMMIT` -> `PHASE-RUN-DA` -> `PHASE-PARALLEL-AUDIT` -> `PHASE-END-PRD-SYNC` -> `PHASE-END-COMMIT`.
- Remediation 또는 deferred 결정이 승인된 phase scope를 넘으면 [`./output-templates.md#phase-remediation-approval-packet`](./output-templates.md#phase-remediation-approval-packet)으로 dependency-closed remediation/deferred scope와 관련 phase-scoped stable step ID를 다시 승인받는다. 요약·경로·checksum만으로 진행하지 않는다.

Split PRD approval gate contract:
- 모든 tracked write 승인은 승인 후 그대로 작성될 durable body 또는 minimal patch를 포함해야 한다. 요약·경로·checksum만 있는 packet이나 chunk는 tracked write, commit, PR write 승인으로 간주하지 않는다.
- for_prd Step 7 full PRD approval은 master PRD draft body, 최초 active phase file draft body, 즉시 생성할 추가 phase file draft body, approved automatic execution scope에만 적용된다. 미래 phase outline과 Phase Index row는 phase 구조 승인일 뿐 phase 파일 생성 승인이 아니다.
- Step 7 split approval은 final `PI-FINAL-REVIEW`, `PI-FOLLOWUP-COMMIT`, `PI-CREATE-PR`로 확장되지 않는다. final closeout은 모든 phase materialization과 `PHASE-END-COMMIT` checkpoint 후 별도 final closeout gates로 승인받는다.
- phase-start materialization gate는 current PRD state, prior phase checkpoint, phase file draft body, master PRD materialization update, phase-scoped automatic execution scope를 승인 표면에 포함해야 한다. 이 gate는 phase 파일 tracked write와 해당 phase-scoped 진행만 승인하며 final PR write로 확장되지 않는다.
- phase-remediation approval gate는 current phase state, remediation/deferred scope, target files, approved durable body 또는 minimal patch, approved steps, excluded steps를 표시해야 한다. Approved steps는 dependency-closed stable step ID 전체를 펼쳐 표시한다.
- final review gate는 final PRD state, final review/follow-up scope, `PI-FINAL-REVIEW`/`PI-FOLLOWUP-COMMIT` 범위만 승인한다. follow-up commit은 final review가 같은 승인 scope 안에서 요구한 변경으로 제한한다.
- final PR write gate는 final fixed diff state, PR write target, exact PR title/body, `PI-CREATE-PR` 범위만 승인한다. Exact PR body는 PRD/plan 같은 tracked file에 저장하지 않는다.

Initial split PRD materialization contract:
- for_prd Step 8이 Step 7에서 본문 전체가 승인된 최초 active phase 파일을 생성하면, 그 write는 initial `PHASE-MATERIALIZE` 완료로 간주한다.
- 이때 master PRD `Document Status`는 `Active Phase File`을 생성된 phase 링크로 설정하고, `Last Completed Step=PHASE-MATERIALIZE`, `Next Blocking Step=PHASE-IMPLEMENT`를 기록한다.
- 승인된 추가 phase 파일을 같은 Step 8에서 함께 materialize했다면 해당 phase는 Phase Index에 materialized link로 기록한다. 아직 본문 전체가 승인되지 않은 미래 phase는 `Pending phase-start approval`로 남긴다.
- Step 8이 최초 active phase 파일을 생성하지 않는 split PRD는 incomplete approval packet으로 간주하고 Post-Implementation에 진입하지 않는다.

PRD resume rules:
- `File Mode: Split` + `Next Blocking Step=PI-FINAL-REVIEW`에서는 같은 active runtime의 `FINAL_REVIEW_GATE_APPROVED` approval record가 있을 때만 승인된 `PI-FINAL-REVIEW` / `PI-FOLLOWUP-COMMIT` 범위를 실행한다. approval record가 없거나 현재 세션에서 확인할 수 없으면 먼저 final review gate를 다시 제시한다.
- `File Mode: Split` + `Next Blocking Step=PI-CREATE-PR`에서는 같은 active runtime의 최신 `FINAL_PR_WRITE_GATE_APPROVED` approval record와 exact approved title/body packet이 함께 있을 때만 승인된 `/create-pr apply-approved` 경로를 실행한다. approval record가 없거나, exact approved packet이 없거나, 현재 base/head/title tuple이 승인 tuple과 다르면 `/create-pr prepare`를 다시 수행하고 final PR write gate를 다시 제시한다. PRD/plan에 저장된 PR body artifact는 resumable approval marker로 인정하지 않는다. 기본 `/create-pr` 생성 경로로 body를 재생성해 바로 쓰지 않는다.
- `File Mode: Single` + `Next Blocking Step=PI-IMPLEMENT|PI-COMMIT|PI-RUN-DA|PI-PARALLEL-AUDIT|PI-FINAL-REVIEW|PI-FOLLOWUP-COMMIT|PI-CREATE-PR`는 Step 7에서 이미 승인된 Post-Implementation 자동 수행 범위로 재개하며, split phase-start gate나 split final closeout gate를 요구하지 않는다.
- split final closeout gate의 runtime approval record 형식은 [`./output-templates.md#final-closeout-gate-packet`](./output-templates.md#final-closeout-gate-packet)의 `Final gate runtime approval record`가 SSOT다.

Final PR write approval record is a runtime-only approval record, not a tracked PRD write and not a resumable marker. Inline chat text, `/tmp` paths, transient tool output, summaries, checksums, paths without the exact title/body, or any tracked PRD/plan artifact must not be treated as PR write approval.

Split PRD에서 다음 phase가 아직 materialized 되지 않았으면 `Active Phase File` 또는 `Next Phase Materialization`에 `Pending phase-start approval`을 표시하고, Phase Index의 해당 row가 정본 outline이 된다. 재개 시 이 상태를 보면 phase 파일을 추측해서 쓰지 않는다. 현재 master PRD, 완료된 phase 파일, 관련 context, 현재 repo 상태를 다시 읽어 phase file draft body와 master PRD materialization update를 재생성하고, 이전 materialized phase의 `PHASE-END-COMMIT` checkpoint를 확인한 뒤 [`./output-templates.md#phase-start-materialization-gate-packet`](./output-templates.md#phase-start-materialization-gate-packet)을 사용자에게 제시한다. 승인 후 phase 파일을 생성하면 `Active Phase File`을 링크로 교체하고 `Next Phase Materialization`을 다음 pending phase 또는 `N/A`로 갱신한다.

PRD 파일 작성 전의 `for_prd.step5_da` / `for_prd.step6_da_apply`는 durable file artifact를 전제하지 않는다. 세션이 끊긴 뒤 재개하면 transient draft/context와 DA verdict를 신뢰하지 않고 이슈 ref + Step 1-4 evidence를 다시 확인한 뒤 Step 5 DA부터 재실행한다. PRD 파일을 작성한 뒤에는 재실행 사유와 최종 verdict 요약을 master `Change Log`에 기록한다.

### Legacy DA State compatibility

기존 `.claude/plans/*`에는 새 enum이 아닌 legacy/free-form `DA State` 값이 있을 수 있다. 알 수 없는 값은 즉시 BLOCKED로 처리하지 않고 legacy 상태로 간주한다. `Resume From`, `Last Completed Step`, `Change Log`를 우선해 재개 위치를 판단하고, 다음에 Step 5/6 DA lifecycle에 진입할 때 새 enum(`PRE_DA`/`RUNNING`/`APPLYING`/...)으로 갱신한다. 세 필드로도 안전한 위치를 판단할 수 없으면 `NEEDS_USER`로 사용자 판단을 요청한다.

### Post-Implementation

New plan state writes must use the canonical `PI-*` stable step IDs from [`post-implementation.md`](./post-implementation.md). The `post_impl.*` values below are legacy resume aliases for older `.claude/plans/*` files only; normalize them to the matching `PI-*` value when the plan next records `Resume From` or `Last Completed Step`.

| Resume From | 진입 조건 |
|-------------|----------|
| `post_impl.implementation` | 변경 구현 (1번) |
| `post_impl.implementation_commit` | 구현 커밋 (2번) |
| `post_impl.run_da_for_pr` | `/run-da for_pr` (3번) |
| `post_impl.parallel_audit` | `/parallel-audit` (4번) |
| `post_impl.final_10pass` | Final Multi-Pass Review (5번) |
| `post_impl.review_commit` | 10-pass 반영 커밋 (6번, 수정 발생 시) |
| `post_impl.create_pr` | `/create-pr` (7번) |

Legacy alias mapping:

| Legacy Resume From | Canonical stable step ID |
|---|---|
| `post_impl.implementation` | `PI-IMPLEMENT` |
| `post_impl.implementation_commit` | `PI-COMMIT` |
| `post_impl.run_da_for_pr` | `PI-RUN-DA` |
| `post_impl.parallel_audit` | `PI-PARALLEL-AUDIT` |
| `post_impl.final_10pass` | `PI-FINAL-REVIEW` |
| `post_impl.review_commit` | `PI-FOLLOWUP-COMMIT` |
| `post_impl.create_pr` | `PI-CREATE-PR` |

## Baseline drift 검증 알고리즘

재개 시점에 plan 파일의 `Baseline` 필드와 현재 git 상태를 비교하여 drift를 감지한다. `for_action` plan의 최초 baseline은 Step 4.5 공식 plan 파일 초기화 시점에 기록한다.

### Baseline 필드 형식

```
branch=<branch_name>, HEAD=<short_sha7>, dirty=<clean|sha1_of_diff>
```

- `clean`: working tree에 unstaged/uncommitted 변경 없음.
- `<sha1>`: `git diff` 출력의 sha1 hash (첫 7자). dirty인 경우.

작성 시 명령:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
HEAD=$(git rev-parse --short HEAD)
# dirty hash는 working tree(diff) + staged(diff --cached) + untracked(porcelain)을 모두 포함한다.
# 이전 버전은 `git diff`만 썼고 staged/untracked 변경을 놓쳤다.
# git hash-object는 sha1sum/shasum 의존을 제거 (Git 자체가 hash 도구 제공).
STATUS_PAYLOAD=$( { git diff; git diff --cached; git status --porcelain=v1 --untracked-files=all; } )
if [ -z "$STATUS_PAYLOAD" ]; then
    DIRTY="clean"
else
    DIRTY=$(printf '%s' "$STATUS_PAYLOAD" | git hash-object --stdin | head -c 7)
fi
echo "branch=$BRANCH, HEAD=$HEAD, dirty=$DIRTY"
```

### 재개 시 비교 절차

1. plan 파일의 `Baseline` 파싱.
2. 현재 git 상태에서 같은 형식 산출.
3. 비교:
   - **동일**: `Resume From` enum 값으로 정확한 단계 점프.
   - **branch 다름**: 사용자에게 경고 + 작업 의도 확인 (다른 브랜치에서 작업 재개 의도일 수 있음).
   - **HEAD 다름**: drift 발생. Step 1-2 재실행 의무 (코드베이스 탐색 + 로컬 재현 결과가 무효일 수 있음). plan에 `DL` 추가:

     ```markdown
     ### DL-N: Baseline drift detected on resume

     - Status: accepted
     - Context: 재개 시점에 git HEAD가 baseline과 다름. (was=`<old>`, now=`<new>`)
     - Decision: Step 1-2 재실행 후 plan 본문 갱신.
     - Consequences: Resume From이 `for_action.step1_validity`로 reset됨.
     ```
   - **dirty 다름**: working tree 변경이 plan 작성 후 추가됨. 사용자에게 알림 + 추가 변경의 plan 통합 의도 확인.

## 동일 세션 progressive commit vs 재개 drift 구분

`Status=Implementing`인 plan을 같은 세션에서 phase별 commit으로 진행하는 경우, branch + HEAD 변경은 정상이다 (Phase 1 commit → Phase 2 commit → ... 자연 진행). 이때는 Baseline drift 처리 불필요 — 그냥 plan의 `Baseline`/`Last Updated`/`Last Completed Step`/`Resume From`/`Phase Progress`를 갱신한다.

**drift 알고리즘 적용 조건**:
- 재개 시점 = 메인 LLM 세션 컨텍스트가 단절된 상태에서 plan 파일을 다시 열 때.
- 신호: `Last Updated`가 오늘이 아니거나, `Status=Implementing`인데 메인 LLM이 진행 history를 메모리에 보유하지 않음.

**진행 중 commit 신호** (drift 처리 skip):
- 동일 세션에서 phase 단위 commit 후 다음 phase 진입.
- 메인 LLM이 직전 commit hash를 컨텍스트에 보유.
- plan의 `Change Log` 마지막 entry가 직전 commit 메시지와 일치.

## 불변조건

- **첫 미완료 blocking step**: `Resume From`은 항상 첫 번째 미완료 blocking step만 가리킨다 (이미 끝난 단계나 skip된 단계를 가리키지 않는다).
- **체크박스 evidence**: 완료 체크박스(`- [x]`)는 evidence 또는 validation note 없이 전환 금지. plan에 "Step 5 DA 완료"라 적으려면 DA verdict 또는 result file 경로가 함께 있어야 한다.
- **Last Updated 동기화**: `Last Updated`가 바뀌면 `Change Log`도 같은 날짜로 갱신된 entry가 있어야 한다.
- **Mode 전환은 DL**: `Mode` 필드가 바뀌면(`for_action` → `for_prd`) 반드시 Decision Log에 기록한다.
- **Baseline drift 처리 의무**: Baseline drift 감지 시 자동으로 Step 1-2 재실행 (메인 LLM 자체 판단으로 "drift는 무시해도 되겠다"는 금지 — 코드베이스 탐색 결과가 무효일 수 있음).

## 재개 호출 패턴 (사용자 입장)

다음 세션에서 사용자가 다음 중 하나로 시작하면 재개:

- 명시적: `"`.claude/plans/<path>.md` Resume From부터 이어가자"` 
- plan 파일 path만: `".claude/plans/<path>.md"` (메인 LLM이 Status / Resume From 읽고 판단)
- plan-with-questions 직접 재호출 + 같은 이슈 ref: 동일 ref면 기존 plan 발견 후 재개 모드

메인 LLM은 plan 파일 상단 `Document Status` 표를 먼저 읽고, Baseline drift 검증 → Resume From 점프 순으로 진행한다.

## Follow-up

- baseline drift 자동화 스크립트 (`scripts/check-plan-baseline.sh`) — 현재는 메인 에이전트가 수동 비교. 자동화 채택 여부는 사용자 follow-up 우선순위에 따른다.
