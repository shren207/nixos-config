# Implementation Review Overlay (review-only)

`plan-with-questions`의 review-impl reference 중 **실행 절차 overlay**. Final Multi-Pass Review의 canonical checklist는 [`../prd/multi-pass-review.md`](../prd/multi-pass-review.md)의 PRD 10-pass다. 본 overlay는 그 위에 review-impl 고유 분류 라벨을 얹는 짧은 delta다 — 별도 9개 pass를 따로 수행하지 않는다 (10-pass 결과에 라벨링 + 우선순위만 부여).

review-only 정책 (NG-2): 보고만 산출. 적용은 메인 에이전트가 사용자 승인된 remediation 단계에서 수행.

## canonical checklist 위치

- **Final Multi-Pass Review**: [`../prd/multi-pass-review.md`](../prd/multi-pass-review.md) PRD 10-pass — 모든 모드의 Post-Impl 5번 Final review에서 mandatory.
  - PRD 산출물 부재(`for_action` 단순 작업) 시 `PRD closeout` 항목만 `N/A` skip + 근거 기록, 나머지 9개 항목은 그대로 수행.
- **Phase-End 10-pass**: [`../prd/phase-template.md`](../prd/phase-template.md) Phase-End — `for_prd` phase 종료 시.

## review-impl overlay (delta)

PRD 10-pass 결과 위에 다음 두 layer를 얹는다.

### 1. 6-classification 라벨 부여

PRD 10-pass의 각 finding(특히 1번 Requirements coverage·8번 Validation의 출력)을 [`./requirement-status.md`](./requirement-status.md)의 6-classification(`satisfied`/`partial`/`missing`/`conflicting`/`overbuilt`/`deferred`) 중 하나로 라벨링한다. 라벨링 기준은 해당 reference의 Classification 룰을 따른다.

### 2. overbuilt 우선 분류

PRD 10-pass의 4번 Simplicity / 5번 Cleanup에서 발견된 항목 중 "문서가 요구하지 않는 기능·추상화·상태·의존성"이 보이면 `overbuilt`를 우선 라벨로 부여한다 ([`./requirement-status.md`](./requirement-status.md) Classification 룰 6번: overbuilt 우선 판정). 동일 코드가 `partial`/`satisfied`와 `overbuilt` 모두 후보면 `overbuilt`로 분류한다 (retrospective 증거가 더 구체적).

## 적용 시점

- `for_action` (review-impl 의도 trigger 진입, PRD/spec 입력 있음): Post-Impl 5번에서 PRD 10-pass + 본 overlay.
- `for_prd`: phase-end 6-classification + Post-Impl 5번 PRD 10-pass + 본 overlay.
- `for_action` (단순 작업, PRD 산출물 없음): PRD 10-pass만 수행 (overlay 미적용 — 매핑할 requirement 문서 부재).

상세 모드별 적용 범위는 [`../task-size-routing.md#review-impl-통합-시점`](../task-size-routing.md#review-impl-통합-시점) SSOT 표 참조.

## 다른 축과의 관계

| 축 | 시점 | 역할 |
|---|---|---|
| PRD Final 10-pass | Post-Impl 5번 (canonical) | requirement coverage / cross-phase / correctness / simplicity / cleanup / security / performance / validation / docs / closeout 검증 |
| 본 review-impl overlay | PRD Final 10-pass 위 (delta) | 각 finding에 6-class 라벨 부여 + overbuilt 우선 분류 |
| 6-classification taxonomy | overlay 정의 위치 | [`./requirement-status.md`](./requirement-status.md) — 라벨 정의·룰·overbuilt 감지 체크리스트 |

## main-agent-only 경계

본 overlay는 read-only다. 라벨링·우선 분류 결과는 보고만 산출하며, 구현 추가/제거/체크박스 전환/PRD 정정 같은 tracked write는 메인 에이전트가 사용자 승인된 remediation 단계에서 수행한다. 상세 경계는 [`../../../run-da/SKILL.md`](../../../run-da/SKILL.md) `Codex 세션 하드닝 계약` SSOT를 따른다.
