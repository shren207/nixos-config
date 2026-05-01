# Mode: for_prd

`/prd`의 Living PRD 구조와 Phase Discovery Gate / Phase-end review 패턴을 plan-with-questions 인터뷰 흐름에 통합한 모드. 자동 트리거 또는 사용자 명시 호출(`for_prd` 첫 토큰)로 진입한다.

## 진입 조건

1. **자동 트리거**: `for_action` Step 1-2 진행 중 [`../references/task-size-routing.md`](../references/task-size-routing.md) 트리거 알고리즘이 후보로 판정 → 사용자 1회 알림 + opt-out 통과.
2. **명시 호출**: `$ARGUMENTS` 첫 토큰이 `for_prd`. 트리거 알고리즘 검증 생략, 즉시 진입.
3. **재개**: plan 파일 `Mode=for_prd` + Resume From이 `for_prd.*` enum이면 그 단계로 점프.

## 차용 reference (직접 복제 금지, 링크만)

| Reference | 용도 |
|-----------|------|
| [`../../prd/references/prd-master-template.md`](../../prd/references/prd-master-template.md) | Document Status 14필드 + Phase Index + 본문 구조의 PRD 측 SSOT (plan-with-questions는 [`../references/plan-file-template.md`](../references/plan-file-template.md)가 정본) |
| [`../../prd/references/phase-template.md`](../../prd/references/phase-template.md) | Phase Discovery Gate / Implementation Checklist / Validation Strategy / Exit Criteria / Phase-end 10-pass 형식 |
| [`../../prd/references/file-mode-selection.md`](../../prd/references/file-mode-selection.md) | Single vs Split 자동 판정 (task-size-routing이 차용) |
| [`../../prd/references/validation-paths.md`](../../prd/references/validation-paths.md) | 10 validation path catalog (모든 모드 공통) |
| [`../../prd/references/multi-pass-review.md`](../../prd/references/multi-pass-review.md) | Final 10-pass review (Post-Implementation 5번) |
| [`../../review-implementation/`](../../review-implementation/) | phase 종료 시 6-classification + Final 9-pass (review-only, auto-fix 미사용) |

## 산출물 경로

[`../references/task-size-routing.md`](../references/task-size-routing.md#prd-모드-산출물-경로-결정) SSOT.

- **Single**: `.claude/plans/<slug>.md` — 14 metadata + Phase Index + 모든 phase inline.
- **Split**: `.claude/plans/<slug>/` — `master.md` (Document Status + Phase Index + Decision Log + Change Log) + `phase-NN-<name>.md` 분리.

자동 판정 플로우는 `file-mode-selection.md` 차용. 사용자 명시 지시 우선.

## 흐름

`for_prd`는 `for_action`의 Step 1-9를 거쳐 Step 7 계획 추적 도구 진입 후 Phase Plan 단계로 분기된다. 즉 Step 1-6(이슈 유효성·탐색·질문·자문·DA)은 동일하게 수행하고, Step 8 plan 작성 시 phase 단위 분리 + Phase Discovery Gate / Phase-end review를 추가한다.

### Step 1-6 (for_action 동일)

[`for_action.md`](./for_action.md) Step 1-6 그대로 따른다. 차이점:
- **Step 1**: tier-1/tier-2 신호 1차 평가 (자동 트리거 가능성 검토).
- **Step 2**: 트리거 결정 시 사용자에게 알림 + opt-out 확인. 사용자 동의 시 Mode 전환.
- **Step 5 DA**: phase 4+ 복잡 plan은 `/run-da for_plan full`(8 도메인 exhaustive) 권장 — Review Intensity가 자동 판단.

### Step 7-9: Phase Plan 작성

#### Step 7: 계획 추적 도구 진입

`for_action`과 동일하지만 산출물이 split-file일 수 있음 ([`../references/task-size-routing.md`](../references/task-size-routing.md#prd-모드-산출물-경로-결정) 자동 판정).

#### Step 8: Phase Plan 작성

plan 파일에 phase 단위 분리 + 다음 항목 포함 (각 phase):

```markdown
### Phase N: <name>

**Phase Discovery Gate** (편집 전 재확인):
- [ ] 관련 코드/파일: `path`, `path`
- [ ] 관련 테스트/fixture: `path`, `path`
- [ ] 관련 docs/spec/외부 참조: `path-or-link`
- [ ] 관련 command 또는 도구: `command/tool`
- [ ] Master plan의 assumption이 여전히 유효함
- [ ] 발견 사항이 이 phase 또는 후속 phase를 바꾸면, 구현 전에 plan 파일을 먼저 갱신

**Implementation Checklist**:
- [ ] [대상 파일/컴포넌트/시스템 + 기대 outcome을 포함한 구체적 구현 단계]

**Validation Strategy**: [risk-appropriate mix — `prd/references/validation-paths.md` catalog 인용]

**Validation Checklist**:
- [ ] [구체적 검증 명령 / surface]

**Exit Criteria**:
- [ ] Phase objective 달성
- [ ] 모든 Validation Checklist 항목 완료
- [ ] 다음 phase 시작 blocker 없음

**Phase-end Review** (다음 phase로 이동 전):
- [ ] 1. **Requirements coverage** (6-classification) — 본 phase의 plan 요구사항을 [`../../review-implementation/references/requirement-status.md`](../../review-implementation/references/requirement-status.md) 6분류로 평가:
  - `satisfied`: 구현 완료 + evidence
  - `partial`: 부분 구현, 다음 phase 또는 deferred
  - `missing`: 누락, 즉시 수정 또는 deferred
  - `conflicting`: 다른 항목과 충돌, Decision Log 기록 + 해결
  - `overbuilt`: plan에 없는 기능 추가, **즉시 제거** (NG-2 — auto-fix 미사용 시 메인 에이전트가 직접 제거)
  - `deferred`: 명시적으로 다음 phase 또는 follow-up으로 이동, Decision Log 기록
- [ ] 2. Phase-end 10-pass review (`prd/references/phase-template.md`의 10-pass 차용 — intent/correctness/simplicity/code quality/cleanup/security/performance/validation/future-phase/PRD sync)
- [ ] 3. 발견 사항이 후속 phase에 영향 → 즉시 plan 파일 갱신 + Decision Log 기록
```

##### overbuilt 처리 (NG-2 — auto-fix 미사용)

`/review-implementation` fix 모드는 차용하지 않는다. `overbuilt` 발견 시:
1. plan에 `[OVERBUILT: <description>]` 라벨로 finding 기록
2. Decision Log DL 추가 (`Status: accepted`, `Decision: remove`, `Consequences: <영향>`)
3. 메인 에이전트가 직접 코드 제거 (single-writer / main-agent-only)
4. 제거 후 Validation Checklist 재실행

#### Step 9: 사용자 승인 요청

`for_action`과 동일. plan 파일에 phase별 명세 + Phase Index가 모두 포함된 상태로 승인 요청.

## Post-Implementation (for_prd 변형)

[`../references/post-implementation.md`](../references/post-implementation.md) 7단계를 따르되 다음 추가:

- **5번 Final Multi-Pass Review**: `prd/references/multi-pass-review.md` 10-pass + `/review-implementation` 9-pass review-only 통합 호출. 메인 에이전트 직접 수행 (fan-out 금지).
  - `/review-implementation` 입력: plan 파일 (single) 또는 master + phase 파일들 (split).
  - `/review-implementation` 호출 시 review-only 모드 (auto-fix 미사용).
  - 결과 finding을 Final 10-pass와 통합 보고.
  - `overbuilt` finding은 6번 review-commit 단계에서 메인 에이전트가 직접 제거.

## 메타데이터 + Resume From (for_prd 전용)

[`../references/plan-file-template.md`](../references/plan-file-template.md) 14필드 모두 적용. PRD 전용 필드:
- `Current Phase`: `Phase N` 형식
- `Phase Progress`: `<X>/<Y> 완료`
- `Active Phase File`: split mode일 때 phase 파일 링크

Resume From enum은 `for_prd.phase_NN.<discovery|implementation|validation|review>` 형식 ([`../references/resume-state.md`](../references/resume-state.md#for_prd-phase-4에서-정밀화) SSOT).

## main-agent-only 경계

PRD 모드 plan 파일·phase 파일은 모두 tracked write이므로 메인 에이전트 전용. fan-out·subagent 위임 금지. 6-classification + 9-pass review 수행자도 read-only이며 적용은 메인이 수행. [`../../run-da/SKILL.md`](../../run-da/SKILL.md)의 `Codex 세션 하드닝 계약` SSOT를 따른다.
