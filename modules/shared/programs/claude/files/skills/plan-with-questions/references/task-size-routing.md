# Task Size Routing — for_prd 자동 트리거

`for_action` 진입 후 Step 1-2(이슈 유효성 + 코드베이스 탐색) 결과를 분석하여 PRD 모드 후보를 자동 감지하고, 사용자에게 1회 알림 + opt-out 옵션을 제공한다.

## 자동 트리거 신호

다음 신호 중 **1개 이상** 감지 시 → `for_prd` 후보:

### Tier-1 (강한 신호 — 단일 충족 시 트리거)

- **Phase ≥4**: 의존성 순서 phase가 4개 이상 필요. `/prd/references/file-mode-selection.md`의 Single/Split 판정 룰과 일치.
- **다중 도메인**: 다음 도메인 중 2+ 동시 변경.
  - data model (DB schema, migration)
  - backend (route, service, job)
  - frontend (component, screen, routing)
  - infrastructure (config, deployment, container)
  - permission / security (auth, RBAC, secret)
  - observability (log, metric, trace)
  - billing / external API integration

### Tier-2 (보조 신호 — 1개 단독은 약함, 2+ 조합 시 트리거)

- **예상 소요일 ≥1일**: Step 1-2 분석에서 추정 작업 시간이 single-day 초과.
- **키워드**: 이슈 제목/본문에 `overhaul`, `재설계`, `redesign`, `아키텍처 변경`, `architecture change`, `migration plan`, `epic` 포함.
- **파일 변경 수 ≥10**: Step 1-2에서 식별한 수정 대상 파일이 10개 이상.
- **이슈 라벨**: `epic`, `meta`, `roadmap`, `tracking-issue` (이슈 트래커에서 확인 가능 시).
- **계획 변동 가능성 높음**: Step 1-2 discovery에서 unknown이 많거나 외부 의존성이 큰 경우.

### Tier-3 (약한 신호 — 단독으론 트리거 안 함)

- 사용자 요청 본문에 "phase", "단계별", "stages" 같은 표현.
- Step 2 로컬 재현에서 비결정적 동작 발견.

## 트리거 알고리즘 (의사코드)

```
def should_trigger_prd(step12_result):
    tier1_hits = count_tier1_signals(step12_result)  # phase>=4, multi-domain
    tier2_hits = count_tier2_signals(step12_result)  # day, keyword, files>=10, label
    if tier1_hits >= 1:
        return "trigger"
    if tier2_hits >= 2:
        return "trigger"
    return "no_trigger"
```

메인 LLM이 Step 1-2 결과를 보고 위 알고리즘을 적용. tier-1 신호는 명확하므로 메인 LLM이 직접 식별 가능. tier-2의 "예상 소요일"은 메인 LLM의 추정으로, 보수적으로 평가 (부족 추정으로 PRD 누락보다 과대 추정으로 PRD 트리거가 안전).

## opt-out 알림 메시지

[`output-templates.md`](./output-templates.md#for_prd-모드-자동-트리거-알림-메시지) SSOT.

요약:
- default: PRD 모드 진행
- opt-out: `for_action` 모드 fallback (Phase plan 없는 단일 plan)
- 사용자가 명시적 거부 시 plan에 `Decision Log` 기록:

```markdown
### DL-N: PRD auto-trigger declined

- Status: accepted
- Context: Step 1-2 결과 PRD 후보로 감지(`Phase ≥4`, `다중 도메인 (frontend+backend)`).
- Decision: 사용자 opt-out → `for_action` 모드 fallback.
- Consequences: phase 추적 없음. 작업 큰 경우 재개·decision 추적 한계 발생 가능.
```

## PRD 모드 산출물 경로 결정

`for_prd` 트리거 후 산출물은 다음 중 하나:

### Single-file mode

```
.claude/plans/<slug>.md
```

조건 (`/prd/references/file-mode-selection.md` 차용):
- Phase 3개 이하 (짧은 phase) — 단 자동 트리거 조건이 Phase ≥4면 single-file 사용 안 함.
- 단일 도메인.
- 짧은 phase 체크리스트.
- Discovery note가 plan 본문에 편하게 들어감.

### Split-file mode

```
.claude/plans/<slug>/
├── master.md (Document Status + Phase Index + Decision Log + Change Log)
└── phase-NN-<name>.md (각 phase별 독립 파일)
```

조건:
- Phase 4개 이상 OR phase 체크리스트 길이 10+ 항목.
- 여러 도메인.
- Discovery 메모가 master plan 집중력 방해.
- 구현 중 계획 변동 가능성 큼.

자동 트리거 조건이 `Phase ≥4`이면 보통 split-file이 자연스럽다. 그러나 phase가 짧고 단순하면 single-file 유지도 가능 — file-mode-selection 자동 판정 플로우 적용.

### 자동 판정 플로우 (file-mode-selection 차용)

```
Phase가 4개 이상인가?                          yes → Split
  no ↓
어느 phase의 implementation 항목이 10개 초과?  yes → Split
  no ↓
Discovery가 plan 본문에 편하게 들어가는가?     no  → Split
  yes ↓
여러 도메인이 관여하는가?                      yes → Split
  no ↓
구현 중 계획이 크게 바뀔 가능성이 큰가?        yes → Split
  no ↓
→ Single
```

사용자가 "single로 유지해" 또는 "split으로 나눠줘"라고 명시하면 그 지시를 우선한다.

## review-implementation 통합 시점

| 모드 | 6-classification | 9-pass review | auto-fix |
|------|------------------|---------------|----------|
| **for_action** | 미사용 | Post-Impl 5번 Final 10-pass(`prd/multi-pass-review`)와 별도 호출 안 함 | 미사용 |
| **for_prd** | **각 phase 종료 시** plan 요구사항 vs 구현 대조 (`requirement-status.md`) | **Final 단계**에서 9-pass review 호출 (`/review-implementation` review-only) | **미사용** (NG-2) |

**phase 종료 시 6-classification**: 각 phase의 Phase-end review에 `requirement-status.md` 6분류 체크리스트 적용:
- requirement → status (`satisfied | partial | missing | conflicting | overbuilt | deferred`) → code evidence (file:line) → gap → action.
- `overbuilt` 발견 시 `Decision Log` 기록 + 다음 phase 시작 전 제거.

**Final 9-pass**: 모든 phase 완료 후 Post-Impl 5번에서 `/review-implementation` review-only 모드 호출 (input: plan 파일 + master+phase 파일들). 반환된 9-pass 결과를 `prd/multi-pass-review.md` Final 10-pass와 통합 보고.

**auto-fix 차용 안 함**: review-implementation의 fix 모드는 호출하지 않는다 (NG-2). 발견된 issue는 Decision Log 기록 후 메인 에이전트가 직접 수정하거나 다음 phase로 deferred.

## 적용 단계 매핑

| Step | 동작 |
|------|------|
| `for_action.step1_validity` 종료 후 | tier-1 신호 1차 평가 (issue 라벨, 키워드) |
| `for_action.step2_exploration` 종료 후 | tier-1 + tier-2 종합 평가 → 트리거 결정 |
| 트리거 시 | 사용자 알림(`AskUserQuestion`) → opt-out 확인 |
| 사용자 동의 시 | Mode 갱신 (`for_action` → `for_prd`) + Decision Log 기록 |
| 사용자 거부 시 | `for_action` 모드 유지 + Decision Log "PRD auto-trigger declined" 기록 |

이후 흐름은 [`../modes/for_prd.md`](../modes/for_prd.md)로 분기.
