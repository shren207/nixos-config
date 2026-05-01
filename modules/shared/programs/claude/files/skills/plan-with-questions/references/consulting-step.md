# Step 3.5: 외부 LLM 기술 자문

**Status**: stub (Phase 2에서 본문 채움)

이 reference는 plan-with-questions 개편의 Phase 2(`Step 3.5 외부 자문 단계 신설`) 산출물이다. Phase 1 progressive disclosure 추출 시 broken link 회피를 위해 stub으로 생성되었다.

## Phase 2에서 채울 내용

- **입력 schema** (codex exec 프롬프트 구조):
  - 작업 목표, resolved issue 요약, Step 2에서 직접 확인한 evidence, 기존 패턴, 제약, unresolved decision 목록, 후보 옵션, validation surface, non-goals.
  - 메인 LLM의 추천·선호 표현 제외. 사용자가 미이해 상태에서 수락한 선택은 `user-proposed candidate`로만 표시.
- **출력 JSON schema**:
  ```
  decision_id, decision_type, user_question
  options: [{ id, description, evaluation_matrix, disqualifiers, evidence_gaps }]
  evaluation_matrix: { 요구충족, 구현비용, 되돌리기쉬움, 운영위험, 검증가능성, 주요unknown, 비용시간추정 }
  validation_needed, ask_user_only_if, can_agent_decide_if
  ```
  점수 합산, 순위, "Recommended", "Best", "Default" 라벨 금지.
- **codex exec 호출 명령 템플릿** + no-write boundary.
- **Anti-anchoring 4 표시 규칙** (필수):
  1. "(Recommended)" 라벨 금지.
  2. 옵션 순서를 decision_id seed로 매 호출마다 셔플.
  3. "이 선택이 틀릴 수 있는 조건"(disqualifiers)을 옵션마다 명시.
  4. 옵션 보이기 전 "어떤 기준이 가장 중요한가?" 먼저 묻는 judgment-first 패턴 (Buçinca et al. 2021).
- **judgment-first 질문 템플릿**.
- **background timing 패턴**: Step 3 종료 직후 발사, 1-3분 budget, 결과 도착 시 Step 4 진입.

## Phase 1 단계 임시 적용

Phase 2 구현 전까지는 메인 LLM이 Step 3 결과를 직접 사용자에게 제시하되 **anti-anchoring 4 규칙은 즉시 적용**한다 ([`output-templates.md`](./output-templates.md#step-4--step-i-4-질문-패턴) 참조).
