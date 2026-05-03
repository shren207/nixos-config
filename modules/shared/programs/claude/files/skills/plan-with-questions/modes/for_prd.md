# Mode: for_prd

`plan-with-questions`의 인터뷰·검증·자동 트리거 흐름을 거친 뒤, PRD 규약을 따라 **`.claude/prds/`에 PRD 파일을 직접 작성**하는 모드다.

핵심 설계: PRD 정본은 `.claude/prds/` 디렉토리에 있으며, 본 모드가 (a) 자동 트리거 + opt-out, (b) Step 1-4 인터뷰·자문과 Step 5-6 DA, (c) PRD 작성·갱신을 모두 담당한다. `.claude/plans/` 사본은 만들지 않는다 (단일 SSOT).

## 진입 조건

1. **자동 트리거**: `for_action` Step 1-2 진행 중 [`../references/task-size-routing.md`](../references/task-size-routing.md) 트리거 알고리즘이 후보로 판정 → 사용자 1회 알림 + opt-out 통과. 이슈 ref가 이미 resolve된 상태에서 진입한다.
2. **명시 호출**: `$ARGUMENTS` 첫 토큰이 `for_prd`이고 두 번째 토큰이 **이슈 ref(URL/번호/이슈키)**. for_action과 동일하게 이슈 resolve 전제 — 텍스트 설명만으로는 진입할 수 없다 (이슈 없는 PRD 작성은 `for_issue`로 이슈 등록 후 transition).
3. **재개**: 기존 `.claude/prds/prd-<feature>.md` 파일이 있고 사용자가 동일 이슈 ref로 재호출 → for_prd 모드가 기존 파일을 read한 뒤 갱신 흐름 (자연어 입력 처리 섹션 참조).

## 차용 reference (직접 복제 금지)

| Reference | 용도 |
|-----------|------|
| [`../references/prd/prd-master-template.md`](../references/prd/prd-master-template.md) | Document Status + Phase Index + 본문 구조 |
| [`../references/prd/phase-template.md`](../references/prd/phase-template.md) | Phase Discovery Gate / Implementation / Validation / Exit Criteria |
| [`../references/prd/file-mode-selection.md`](../references/prd/file-mode-selection.md) | Single vs Split 자동 판정 |
| [`../references/validation-paths.md`](../references/validation-paths.md) | validation-path catalog (모든 모드 공통, 평면 위치 — path 수는 catalog enumeration 섹션에서 확인) |
| [`../references/prd/multi-pass-review.md`](../references/prd/multi-pass-review.md) | Final 10-pass review (Post-Implementation 5번) |
| [`../references/review-impl/requirement-status.md`](../references/review-impl/requirement-status.md) | phase 종료 시 6-classification taxonomy (requirement → 구현 매핑, auto-fix 미사용) |
| [`../references/review-impl/implementation-review.md`](../references/review-impl/implementation-review.md) | Final review 시 PRD 10-pass에 얹는 review-impl overlay (6-classification 라벨링 + overbuilt 우선 분류 delta) |

## 산출물 경로

- **Single**: `.claude/prds/prd-<feature>.md`
- **Split**: master `.claude/prds/prd-<feature>.md` + phase 파일 `.claude/prds/prd-<feature>/phase-NN-<name>.md` (master는 디렉토리 옆에 sibling으로 위치)

자동 판정은 [`../references/prd/file-mode-selection.md`](../references/prd/file-mode-selection.md)를 따른다 (상세는 [`../references/task-size-routing.md`](../references/task-size-routing.md#single-vs-split-자동-판정)).

## 자연어 입력 처리

자연어로 PRD 작성·갱신·review-only 작업을 요청하면 다음 흐름. trigger 키워드 정의는 [`../SKILL.md`](../SKILL.md#모드-판별) "자연어 trigger → transition 매핑" SSOT 표 참조 (본 섹션은 mode-specific 동작만 명시):

- **PRD 작성 의도 카테고리 — 신규 PRD**: 기존 `.claude/prds/prd-<feature>.md` 부재 시 본 모드 Step 1-8 전체 흐름 (인터뷰·자문·DA → 사용자 승인 → Step 8에서 신규 PRD 작성).
- **PRD 작성 의도 카테고리 — 기존 PRD 갱신**: `.claude/prds/prd-<feature>.md` 존재 시 기존 파일을 read한 뒤 갱신 흐름 (Discovery 결과로 영향받는 phase/section만 수정, 완료 체크박스 + 사용자 수정 보존).
- **review-impl 의도 카테고리** → for_action 모드 진입(이슈 ref 있을 시) 또는 for_issue 모드 진입(텍스트 설명만), Post-Implementation 5번 Final review 단계에서 [`../references/prd/multi-pass-review.md`](../references/prd/multi-pass-review.md)의 PRD 10-pass + [`../references/review-impl/implementation-review.md`](../references/review-impl/implementation-review.md) overlay(6-classification 라벨링 + overbuilt 우선 분류) 적용 (auto-fix 미사용, NG-2). 또는 for_prd phase-end review에서 phase-template의 10-pass와 통합 적용.

## 흐름

`for_prd`는 `for_action`의 Step 1-4, 5-6 인터뷰·자문·DA 흐름을 차용하되, `for_action` 전용 Step 4.5 plan 파일 초기화는 건너뛴다. Step 7(승인 게이트) 시점에서 PRD 규약([`../references/prd/prd-master-template.md`](../references/prd/prd-master-template.md) + [`../references/prd/phase-template.md`](../references/prd/phase-template.md))을 따라 `.claude/prds/`에 직접 작성한다.

### Step 1-4 + Step 5-6 (for_action 차용)

[`for_action.md`](./for_action.md) Step 1-4와 Step 5-6의 핵심 절차를 따른다. 차이점:
- **Step 1**: tier-1/aux 신호 1차 평가 (자동 트리거 가능성 검토).
- **Step 2**: 트리거 결정 시 사용자에게 알림 + opt-out 확인. 사용자 동의 시 Mode 전환 (`for_action` → `for_prd`).
- **Step 3.5**: 자문 입력에 phase 구조 후보를 포함 (PRD는 phase 단위 결정이 핵심).
- **Step 4.5**: 건너뛴다. `for_prd`는 `.claude/plans/` 파일과 plan-file-template 14 metadata를 만들지 않는다.
- **Step 5 DA**: 기본은 `/run-da for_plan` 호출 — `run-da`의 독립 Intensity agent가 SKIP/LITE/FULL을 자동 판정한다. DA 입력은 PRD draft/context, candidate phase structure, Step 1-4 evidence이며 plan 파일 path가 아니다. phase 4+ 복잡 plan에서 사용자가 명시적으로 exhaustive review를 원하면 `/run-da for_plan full` 사용 (full modifier는 Intensity 판단을 우회하고 8 도메인 강제). 두 의미는 다르다.
- **Step 6 DA 반영**: DA 결과는 PRD draft/context와 후보 phase 구조에 반영한다. PRD 작성 후에는 PRD master `Change Log`와, split mode에서 특정 phase가 영향받는 경우 해당 phase의 `Discoveries / Decisions`에 반영 이력을 남긴다.
- **Step 5/6 resume**: PRD 파일이 아직 없으면 DA draft/context는 durable artifact가 아니다. 세션이 끊긴 뒤 재개하면 transient DA verdict를 신뢰하지 않고 `for_prd.step5_da`부터 보수적으로 재실행한다. 재실행 사유는 PRD 작성 후 master `Change Log`에 남긴다.

### Step 7: 사용자 승인 게이트

**PRD 파일 작성 전에 명시 승인 게이트 필수** (`for_action` Step 9와 등가). 자동 PRD opt-out 동의가 곧장 commit/PR write 동의로 확장되는 회귀를 방지한다 (#569 류 회귀):

1. 메인 에이전트가 Step 1-4와 Step 5-6 결과 요약과 full PRD approval packet을 사용자에게 제시:
   - PRD 후보 신호 (트리거된 tier-1/aux 신호)
   - Resolved evidence + 사용자 답변 + Step 3.5 자문 매트릭스 요약
   - DA findings + Arbiter 판정 핵심
   - 후보 phase 구조 (3-6개) + 산출물 경로 (`.claude/prds/...`)
   - full PRD approval packet: [`../references/output-templates.md`](../references/output-templates.md#full-prd-approval-packet) 형식으로 승인 후 작성될 durable body와 chunk를 제시한다. split mode의 승인·materialization·final gate 계약은 [`../references/resume-state.md`](../references/resume-state.md#for_prd-prd-작성-후-next-blocking-step)가 SSOT다.
   - **자동 수행 범위**: single-file mode는 [`../references/post-implementation.md`](../references/post-implementation.md)의 Post-Implementation stable step ID 전체 또는 승인 게이트에서 명시한 생략 항목을 표시한다. split mode는 [`../references/resume-state.md`](../references/resume-state.md#for_prd-prd-작성-후-next-blocking-step)의 phase-scoped default display string을 표시한다.
2. 승인 요청 도구로 사용자 승인 요청. 사용자가 수정 요청하면 PRD draft/context 또는 후보 phase 구조를 갱신한 뒤 다시 요청.
3. **승인이 곧 승인 표면에 표시된 자동 수행 동의**다. tracked write·commit·PR write 중 무엇이 승인되는지는 해당 gate에 표시된 stable step ID와 자동 수행 범위에 한정된다. split mode Step 7의 실행 계약은 [`../references/resume-state.md`](../references/resume-state.md#for_prd-prd-작성-후-next-blocking-step)의 phase/final gate contract가 SSOT이며, 승인 packet은 그 contract의 사용자 표시 형식이다.

### Step 8: PRD 작성

승인이 통과한 경우에만 PRD 파일 작성으로 분기한다:

1. Step 1-4에서 수집한 정보, Step 5-6 DA 결과, 승인된 후보 phase 구조를 정리한다.
2. [`../references/prd/prd-master-template.md`](../references/prd/prd-master-template.md)를 따라 `.claude/prds/prd-<feature>.md`에 Step 7에서 승인된 master PRD draft body를 그대로 작성한다. 승인 packet 이후 본문 변경이 필요하면 작성하지 말고 Step 7로 돌아간다. `<feature>` slug 안전 규칙은 [`../references/prd/file-mode-selection.md`](../references/prd/file-mode-selection.md#경로-slug-안전-규칙)가 SSOT다.
3. Split mode이면 [`../references/prd/phase-template.md`](../references/prd/phase-template.md)를 따라 Step 7에서 본문 전체가 승인된 phase 파일만 같은 실행에서 생성한다 (`.claude/prds/prd-<feature>/phase-NN-<name>.md`). 최초 active phase 파일은 반드시 생성되며, 이 write는 [`../references/resume-state.md`](../references/resume-state.md#for_prd-prd-작성-후-next-blocking-step)의 initial `PHASE-MATERIALIZE` 완료로 기록한다. 미래 phase는 master PRD의 Phase Index에 `Pending phase-start approval`로 남길 수 있다. 승인 packet 또는 승인된 chunk에 없는 template 본문, checklist, 요구사항을 phase 본문에 추가해야 하면 작성하지 말고 Step 7로 돌아간다. `<name>` slug 안전 규칙도 [`../references/prd/file-mode-selection.md`](../references/prd/file-mode-selection.md#경로-slug-안전-규칙)를 따른다.
4. Split mode에서 아직 materialized 되지 않은 phase를 시작하려면 [`phase-start materialization gate`](../references/output-templates.md#phase-start-materialization-gate-packet)를 먼저 수행한다. phase-start/final gate의 실행 계약과 resume semantics는 [`../references/resume-state.md`](../references/resume-state.md#for_prd-prd-작성-후-next-blocking-step)가 SSOT다.

PRD 작성 + 갱신 + phase 진행 + Phase Discovery Gate 적용을 모두 본 모드가 책임진다. 별도 plan 파일 (`.claude/plans/`)은 만들지 않는다.

### Post-Implementation 흐름 변형

PRD가 작성된 후 구현 단계는 [`../references/post-implementation.md`](../references/post-implementation.md)를 따르되, split mode의 pending phase는 phase-scoped PI pipeline으로 실행하고 모든 split PRD의 final review·follow-up commit·PR write는 final closeout gates로 승인받는다:

- split mode에서는 모든 phase 완료와 phase-end PRD sync commit checkpoint 후 [`final closeout gate packet`](../references/output-templates.md#final-closeout-gate-packet)을 순서대로 수행하고, 승인된 stable step ID만 실행한다.
- 상세 review 흐름 (phase-end / Final / overbuilt 처리)은 [`../references/task-size-routing.md#review-impl-통합-시점`](../references/task-size-routing.md#review-impl-통합-시점)이 SSOT다. 본 mode 파일은 link만 두고 절차를 복제하지 않는다 (drift 방지).

PRD Closeout 조건은 `.claude/prds/`에 작성됐으므로 자동 활성화 (이전 버전의 `.claude/plans/` mismatch는 본 변경으로 해소).

## 메타데이터

PRD 자체 메타데이터는 [`../references/prd/prd-master-template.md`](../references/prd/prd-master-template.md)의 Document Status 표가 정본 (for_prd 모드가 적용). plan-with-questions의 [`../references/plan-file-template.md`](../references/plan-file-template.md) 14필드는 `for_action` 모드 전용이며, `for_prd`에는 적용되지 않는다 — 두 SSOT 병존 회피.

Resume From enum의 `for_prd.*` 항목 ([`../references/resume-state.md`](../references/resume-state.md))은 plan-with-questions가 PRD 작성 직전까지 도달한 단계를 기록할 때 사용한다. PRD 작성 후의 phase 진행은 PRD master Document Status가 추적한다.

## main-agent-only 경계

PRD 파일·phase 파일은 모두 tracked write이므로 메인 에이전트 전용. fan-out·subagent 위임 금지. PRD 10-pass + review-impl overlay 수행자도 read-only이며 적용은 메인이 수행. [`../../run-da/references/hardening-contract.md`](../../run-da/references/hardening-contract.md) `Codex 세션 하드닝 계약` SSOT를 따른다.

## for_prd 모드 특징

| 항목 | 값 |
|------|----|
| 입력 | 인터뷰 결과 + Step 3.5 자문 + PRD draft/context + 후보 phase 구조 + DA 판정 |
| 자동 트리거 | task-size-routing 알고리즘으로 후보 감지 |
| Step 3.5 외부 자문 | 트레이드오프 1+ 항목 시 (PRD 작성 전 1회) |
| DA `/run-da for_plan` | Step 5에서 무조건 호출 |
| 산출물 | `.claude/prds/prd-<feature>.md` (split mode면 phase 파일 추가) |

본 모드는 인터뷰·anti-anchoring·DA 검증을 거쳐 `.claude/prds/`에 PRD를 작성하는 단일 흐름이다.
