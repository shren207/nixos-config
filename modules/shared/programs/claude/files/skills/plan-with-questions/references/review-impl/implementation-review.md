# Implementation 9-pass Review (review-only)

`plan-with-questions`의 review-impl reference 중 **실행 절차** 영역. `for_action` Post-Implementation 5번 Final review와 `for_prd` Final 통합 review에서 PRD Final 10-pass와 함께 적용하는 9개 패스 체크리스트를 정의한다. 본 reference는 **review-only**다 (NG-2: auto-fix 미채택). 보고만 산출하며 적용·정렬·제거 같은 tracked write는 메인 에이전트가 사용자 승인된 remediation 단계에서 수행한다.

## 다른 축과의 관계

| 축 | 시점 | 정의 위치 | 비고 |
|---|---|---|---|
| **6-classification** | requirement 상태 판정 (taxonomy) | [`requirement-status.md`](./requirement-status.md) | 본 9-pass와 다른 축. requirement → 구현 매핑을 6 라벨로 분류 |
| **9-pass review-only** | Implementation review 절차 | 본 파일 | 구현물 전반에 대한 9개 관점 체크 |
| **PRD Final 10-pass** | PRD closeout review | [`../prd/multi-pass-review.md`](../prd/multi-pass-review.md) | 9-pass와 다른 축 (Cross-phase integration / Validation 선택 / Documentation / PRD Closeout 포함) |
| **Phase-End 10-pass** | phase 종료 review | [`../prd/phase-template.md`](../prd/phase-template.md) Phase-End | PRD Final 10-pass와 동형, phase 단위 |

본 9-pass는 **PRD Final 10-pass와 다른 축**이며, Final review 시점에 두 축을 함께 수행한다 (대체 아님).

## 적용 시점

- `for_action` 모드: Post-Implementation 5번 Final review (PRD/spec 산출물이 있는 경우 PRD Final 10-pass와 함께).
- `for_prd` 모드: phase 종료 시 PRD Phase-End 10-pass + 6-classification, Final 시 PRD Final 10-pass + 본 9-pass 통합.
- review-only이므로 입력은 **이미 작성·구현된 코드 + 문서**다. 계획·설계 단계 review는 [`../../../run-da/SKILL.md`](../../../run-da/SKILL.md) `for_plan` 모드를 사용한다.

## Input / Output

- Input: PRD master 파일 + phase 파일 + 변경 코드 (구현 후 diff 또는 main 대비 전체 코드).
- Output: 보고. 각 pass별 PASS/FAIL/N/A + 발견 사항 + 6-classification 분류(가능 시).
- 적용은 메인 에이전트가 별도 승인 단계에서 수행 (auto-fix 미사용, NG-2).

## 9-pass 체크리스트

다음 순서로 9개 패스를 수행한다.

1. **Requirements coverage**: 모든 requirement가 satisfied 또는 명시적으로 해소 불가 상태인가.
2. **Correctness**: happy path, edge case, error, empty state, permission, state transition, rollback이 처리되었는가.
3. **Integration**: 바뀐 모듈이 계약 깨짐, 소유권 중복, 숨은 가정 없이 맞물리는가.
4. **Simplicity**: 솔루션이 필요 이상으로 복잡하지 않은가.
5. **Cleanup**: 중복 로직, dead code, temporary code, 잡음 log, 사용되지 않는 파일/의존성이 제거되었는가.
6. **Security/privacy**: 인증, 인가, secret, 민감 데이터, injection risk, 감사 필요성이 안전한가.
7. **Performance**: 비싼 query, N+1, 불필요한 render, 중복 네트워크 호출, 블로킹 작업이 다루어졌는가.
8. **Validation**: 선택된 check가 risk에 적합한가 — 선택 근거는 [`../validation-paths.md`](../validation-paths.md) 참조.
9. **Documentation/operability**: docs, release note, migration, rollback, monitoring, 지원 note가 필요에 따라 갱신되었는가.

문서가 요구하지 않는 기능·추상화·상태·의존성·workflow 경로가 코드에 추가되어 있으면 [`requirement-status.md`](./requirement-status.md)의 `overbuilt`로 분류하여 finding으로 기록한다 (6-classification 축).

## main-agent-only 경계

본 9-pass 수행자는 **read-only**다. 구현 추가/제거/체크박스 전환/PRD 정정 같은 tracked write는 메인 에이전트가 사용자 승인된 remediation 단계에서 수행한다. 상세 경계는 [`../../../run-da/SKILL.md`](../../../run-da/SKILL.md) `Codex 세션 하드닝 계약` SSOT를 따른다.
