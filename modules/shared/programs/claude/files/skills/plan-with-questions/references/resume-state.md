# Resume State

**Status**: stub (Phase 3에서 본문 채움)

이 reference는 plan-with-questions 개편의 Phase 3(`plan-file-template + Resume From + Decision Log`) 산출물이다.

## Phase 3에서 채울 내용

### Resume From enum 카탈로그

기계적으로 식별 가능한 enum 값:

- `for_action.step1_validity`, `for_action.step2_exploration`, `for_action.step3_questions`
- `for_action.step3_5_consulting`, `for_action.step4_user_questions`
- `for_action.step5_da`, `for_action.step6_da_apply`
- `for_action.step7_plan_mode_entry`, `for_action.step8_plan_writing`, `for_action.step9_approval`
- `for_issue.step_i1_fanout`, `step_i2_fanin`, `step_i3_blackbox`, `step_i3_5_consulting`, `step_i4_loop`, `step_i5_create_issue`, `step_i6_handoff`
- `for_prd.phase_NN.{discovery,implementation,validation,review}`
- `post_impl.{run_da_for_pr, parallel_audit, final_10pass, reflection_commit, create_pr}`

### baseline drift 검증 알고리즘

재개 시:
1. plan 파일의 `Baseline` 필드 (branch + HEAD + dirty hash) vs 현재 git 상태 비교.
2. 같으면 `Resume From` 단계로 점프.
3. 다르면 Step 1-2 재실행 안내 + plan에 "Baseline drift detected: [상세]" 기록 (Decision Log DL 추가).

### 불변조건

- `Resume From`은 첫 번째 미완료 blocking step만 가리킨다.
- 완료 체크박스(`- [x]`)는 evidence 또는 validation note 없이 전환 금지.
- `Last Updated`가 바뀌면 `Change Log`도 같은 날짜로 갱신.
- mode 전환은 Decision Log에 기록.
- baseline 변경 감지 시 Step 1-2 재실행 의무.

## Phase 1 단계 임시 적용

Phase 3 구현 전까지는 plan 파일에 `Status`, `Mode`, `Last Updated`, `Resume From` 4개 필드만 기록한다. 나머지 메타데이터·enum 강제·baseline drift 알고리즘은 Phase 3 완료 후 적용된다.
