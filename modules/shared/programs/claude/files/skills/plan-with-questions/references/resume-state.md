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
| `for_action.step5_da` | `/run-da for_plan` 호출 |
| `for_action.step6_da_apply` | DA 결과 반영 |
| `for_action.step7_plan_mode_entry` | 계획 추적 도구 진입 |
| `for_action.step8_plan_writing` | 계획 파일 작성 |
| `for_action.step9_approval` | 승인 요청 도구 호출 |
| `for_action.step9_awaiting_approval` | 사용자 승인 대기 |

### for_issue

| Resume From | 진입 조건 |
|-------------|----------|
| `for_issue.step_i1_fanout` | fan-out 레퍼런스 수집 |
| `for_issue.step_i2_fanin` | fan-in 결과 통합 |
| `for_issue.step_i3_blackbox` | 블랙박스 체크리스트 생성 |
| `for_issue.step_i3_5_consulting` | Step I-3.5 외부 자문 (트레이드오프 1+) |
| `for_issue.step_i4_loop` | 스무고개 루프 (라운드별) |
| `for_issue.step_i5_create_issue` | 이슈 생성 (`/create-issue`) |
| `for_issue.step_i6_handoff` | for_action 전환 제안 + write-handoff |

(for_issue는 산출물이 이슈이므로 plan file의 Resume From은 사용하지 않지만, 기록용으로 enum은 정의한다.)

### for_prd (Phase 4에서 정밀화)

| Resume From | 진입 조건 |
|-------------|----------|
| `for_prd.discovery` | for_prd 후보 감지 + 사용자 알림 |
| `for_prd.phase_NN.discovery` | Phase N의 Discovery Gate |
| `for_prd.phase_NN.implementation` | Phase N의 Implementation Checklist |
| `for_prd.phase_NN.validation` | Phase N의 Validation |
| `for_prd.phase_NN.review` | Phase N의 Phase-end review |
| `for_prd.final_review` | 모든 phase 완료 후 Final 10-pass |

`NN`은 두 자리 숫자 (`01`, `02`, ...).

### Post-Implementation

| Resume From | 진입 조건 |
|-------------|----------|
| `post_impl.implementation` | 변경 구현 (1번) |
| `post_impl.implementation_commit` | 구현 커밋 (2번) |
| `post_impl.run_da_for_pr` | `/run-da for_pr` (3번) |
| `post_impl.parallel_audit` | `/parallel-audit` (4번) |
| `post_impl.final_10pass` | Final Multi-Pass Review (5번) |
| `post_impl.review_commit` | 10-pass 반영 커밋 (6번, 수정 발생 시) |
| `post_impl.create_pr` | `/create-pr` (7번) |

## Baseline drift 검증 알고리즘

재개 시점에 plan 파일의 `Baseline` 필드와 현재 git 상태를 비교하여 drift를 감지한다.

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
DIRTY=$(git diff | sha1sum | head -c 7 2>/dev/null || git diff | shasum | head -c 7)
[ -z "$(git diff)" ] && DIRTY="clean"
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
     - Consequences: Resume From이 `step1_validity`로 reset됨.
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

## Phase 4 / Phase 5 보강 예정

- `for_prd` enum 정밀화 (Phase 4에서 phase 자동 트리거 + phase-end review의 enum 확장).
- baseline drift 자동화 스크립트 (`scripts/check-plan-baseline.sh` 검토 — Phase 5에서 결정).
