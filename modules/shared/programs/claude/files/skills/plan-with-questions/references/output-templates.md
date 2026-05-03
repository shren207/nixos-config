# Output Templates

사용자에게 보여주는 메시지·체크리스트·상태 보고 템플릿. progressive disclosure로 본문에서 분리한 보일러플레이트.

## for_issue Step I-3 블랙박스 체크리스트 카테고리

체크리스트는 카테고리별로 구분한다:

- **A. 요구사항**: 해석이 여러 가지 가능한 부분
- **B. 설계 결정**: 사용자의 선호도/우선순위가 필요한 선택
- **C. 트레이드오프**: 접근법이 2개 이상인 경우
- **D. 사이드이펙트**: 사용자가 인지해야 할 영향
- **E. 기타**: 위 카테고리에 속하지 않는 사항

사용자에게 체크리스트를 보여주고, 모든 항목이 ✅가 될 때까지 또는 사용자가 "충분하다"고 판단할 때까지 스무고개를 반복한다.

## Step 4 / Step I-4 질문 패턴

- **사이드이펙트 인지 확인**: "이렇게 변경하면 ...에도 영향이 갑니다. 인지하고 계셨나요?"
- **트레이드오프 선택**: "A 방식은 ...이 장점이고, B 방식은 ...이 장점입니다. 어느 쪽을 선호하시나요?"
- **판단 기준 요청**: "이 부분은 판단 기준이 필요합니다: ..."
- **범위 확인**: "이 이슈의 범위에 ...도 포함되나요, 아니면 별도 이슈로 분리할까요?"
- **XY Problem 검증**: "해결하려는 근본 문제가 무엇인가요?"

**Step 3.5 외부 자문 결과 표시 시 anti-anchoring 규칙** (필수):

- "(Recommended)" 라벨 금지.
- 옵션 순서를 `decision_id`로 seed한 stable shuffle (같은 decision_id면 같은 순서, 다른 decision_id면 다른 순서).
- 각 옵션에 disqualifier ("틀릴 수 있는 조건") 명시.
- 옵션 보이기 전 "어떤 기준이 가장 중요한가?" 먼저 묻는 judgment-first 패턴.
- 옵션 description 중립화 — "A는 간단하고 추천" → "A는 변경 표면 작지만 후속 확장 시 재작업 가능".

상세는 [`consulting-step.md`](./consulting-step.md) 참조.

## for_issue Step I-6 전환 제안 메시지

이슈 생성 완료 후, 질문 도구로 사용자에게 묻는다. 메시지 본문과 첫 옵션은 **사용자 입력 시점의 자연어 trigger 카테고리**에 따라 달라진다.

trigger 카테고리 정의 (키워드 목록 + 권장 transition 모드)는 [`../SKILL.md`](../SKILL.md#모드-판별)의 "자연어 trigger → transition 매핑" 표 (SSOT)를 참조한다. 본 섹션은 각 카테고리의 사용자 메시지 문안과 옵션 본문만 정의한다. 모든 카테고리는 옵션을 **3개로 통일**한다 (`request_user_input`의 max-3 제약 준수).

### PRD 작성 의도 trigger 매칭 시

> "이슈 등록이 완료되었습니다. 입력에 PRD 작성 의도가 포함되어 있어, 바로 **for_prd 모드로 PRD 작성**을 시작할 수 있습니다. 어떻게 진행할까요?"

옵션 (3개):
- **Yes (for_prd 진입)** → 생성된 이슈 URL(create-issue Step 5의 `ISSUE_URL`)로 `for_prd <ISSUE_URL>` 진입.
- **No (write-handoff로 마무리)** → 이슈 URL을 인자로 `/write-handoff` 실행 후 종료.
- **No (여기서 종료)** → 이슈 URL 반환 후 종료. (사용자가 for_action 우회를 원하면 별도 메시지로 `for_action <ISSUE_URL>` 명시 호출 가능.)

### review-impl 의도 trigger 매칭 시

> "이슈 등록이 완료되었습니다. 입력에 구현 감사·문서 대비 리뷰 의도가 포함되어 있어, **for_action 모드로 진입 후 Post-Implementation 5번 Final review**에서 PRD 10-pass(`references/prd/multi-pass-review.md`) + review-impl overlay(`references/review-impl/implementation-review.md` — 6-classification 라벨링 + overbuilt 우선 분류)를 적용합니다. 어떻게 진행할까요?"

옵션 (3개):
- **Yes (for_action 진입)** → 생성된 이슈 URL로 `for_action <ISSUE_URL>` 진입.
- **No (write-handoff로 마무리)** → 이슈 URL을 인자로 `/write-handoff` 실행 후 종료.
- **No (여기서 종료)** → 이슈 URL 반환 후 종료.

### 일반 텍스트 (위 카테고리 매칭 없음)

> "이슈 등록이 완료되었습니다. 바로 for_action으로 전환하여 작업을 진행하시겠습니까?"

옵션 (3개):
- **Yes** → 생성된 이슈 URL로 `for_action <ISSUE_URL>` 진입.
- **No (write-handoff로 마무리)** → 이슈 URL을 인자로 `/write-handoff` 실행 후 종료 (bare 번호 대신 URL을 전달해 write-handoff 헬퍼의 cwd 의존성을 회피).
- **No (여기서 종료)** → 이슈 URL 반환 후 종료.

## for_prd 모드 자동 트리거 알림 메시지

자동 PRD 후보가 감지되면 1회 알림 + opt-out:

> "이 작업은 phase 추적·재개 상태가 필요해 보이는 장기 작업입니다. **Living PRD 모드**로 진행하고, 간단한 plan으로 줄이려면 알려주세요.
>
> 트리거 신호: [Phase ≥4 / 다중 도메인 / 어느 쪽인지 명시]"

옵션 (질문 도구):
- **PRD 모드로 진행 (default)** → for_prd 모드 진입.
- **간단한 plan으로** → for_action 모드 fallback.

상세는 [`task-size-routing.md`](./task-size-routing.md) 참조.

## for_action Step 9 / for_prd Step 7 승인 시 자동 수행 범위 표시

승인 표면에 사용자에게 노출할 자동 수행 범위를 mode별로 분기한다:

- `for_action` plan Step 8과 `for_prd` single-file Step 7: [`post-implementation.md`](./post-implementation.md)의 "Approval-surface default display string"을 사용한다. 일부 생략 시 stable step ID로 제거/표기하고 사용자 명시 요청 사유를 덧붙인다.
- `for_prd` split-file Step 7: 아래 `full PRD approval packet`의 `Automatic execution scope` 항목을 사용한다. 일부 생략 시 `Phase-scoped 자동 수행`에서 stable step ID로 제거/표기하고 사용자 명시 요청 사유를 덧붙인다. final closeout 범위 조정은 Step 7이 아니라 [`#final-closeout-gate-packet`](#final-closeout-gate-packet)에서만 다룬다.

이 항목은 승인 요청 도구 호출 시 사용자에게 노출되어 해당 gate에 표시된 tracked write·commit·GitHub PR write 자동 진행 범위에 대한 사용자 동의 근거가 된다. PR write 동의는 해당 gate의 표시 범위에 `PI-CREATE-PR`가 포함된 경우에만 성립한다. split final closeout gate의 PR write는 추가로 exact PR title/body 승인이 필요하다.

## full PRD approval packet

for_prd Step 7의 승인 표면은 아래 순서를 유지한다:

- Target PRD paths: master PRD 경로, 즉시 생성할 split phase 경로, 미래 phase의 reserved 경로와 materialization 상태
- Master PRD draft body: 승인 후 그대로 작성될 master PRD 본문 전체. `Change Log`에는 durable 산출물 이력과 Post-Implementation stable step ID 범위만 기록한다.
- Phase Index summary: split mode일 때 각 phase title, objective, validation focus, accepted phase outline, materialization status를 먼저 제시한다. 이 summary는 review 편의를 위한 요약이며, phase 파일 생성 승인은 아래 phase file draft body 또는 phase-start materialization gate로만 성립한다.
- Phase file draft body: 최초 active phase 파일과 즉시 생성할 추가 phase 파일은 승인 후 그대로 작성될 본문 전체를 포함한다. 미래 phase는 `Pending phase-start approval` 상태로 Phase Index에 남길 수 있으며, phase 시작 직전 같은 형식의 durable body 승인을 다시 받아 생성한다. 본문 전체가 approval packet 또는 승인된 chunk에 없는 phase 파일은 생성하지 않는다.
- Chunked approval fallback: full packet이 너무 커서 한 번에 표시하기 어렵다면 ordered chunk로 나눈다. 각 chunk는 stable chunk ID, target path, 승인 후 그대로 작성될 durable body를 포함해야 한다. 최종 승인 요청은 사용자가 이미 본 chunk ID 목록을 다시 열거한다. 요약·경로·checksum만 있는 chunk는 tracked write·commit·PR write 승인으로 간주하지 않는다.
- Automatic execution scope:
  - Single-file mode: 위 Post-Implementation stable step ID 표시 형식.
  - Split-file mode phase-scoped work: 즉시 생성할 phase 파일은 아래 `Phase-scoped default display string` 형식도 함께 표시한다.
  - Split-file mode final closeout: 모든 split PRD는 `PI-FINAL-REVIEW`, `PI-FOLLOWUP-COMMIT`, `PI-CREATE-PR`를 Step 7에서 승인하지 않는다. 모든 phase body materialization과 phase-end PRD sync commit checkpoint가 끝난 뒤 [`#final-closeout-gate-packet`](#final-closeout-gate-packet)의 두 ordered gate로 별도 승인받는다.

승인 후 Step 8은 approval packet 또는 승인된 chunk 범위 안에서 PRD 파일을 쓴다. Step 7 승인 이후 master PRD draft body, Phase Index summary, phase file draft body, chunk body를 바꿔야 하면 파일을 작성하지 말고 Step 7 승인 요청을 다시 수행한다.

## phase-start materialization gate packet

split mode에서 `Pending phase-start approval` 상태의 phase를 시작하려면 아래 승인 표면을 먼저 제시한다:

- Current PRD state: master PRD의 `Document Status`, 대상 Phase Index row, materialization status
- Prior phase checkpoint: 이전 materialized phase가 있으면 각 phase의 `PHASE-END-COMMIT` 완료 여부. 완료되지 않았거나 해당 stable step ID가 생략된 phase가 있으면 새 phase-start gate로 진행하지 않는다. 먼저 dependency-closed remediation/deferred scope를 승인받아 이전 phase를 닫는다.
- Phase file draft body: 승인 후 그대로 작성될 phase 파일 본문 전체
- Master PRD materialization update: 승인 후 그대로 반영될 master PRD `Document Status`, 대상 Phase Index row, `Active Phase File`, `Next Phase Materialization` row 전체 또는 동일 정보를 담은 minimal patch. 이 항목이 없으면 `PHASE-MATERIALIZE`의 master PRD tracked write 승인으로 간주하지 않는다.
- Phase-scoped 자동 수행 범위: 아래 stable step ID 중 해당 phase에 적용할 범위. 이 항목이 없으면 phase 파일 tracked write나 해당 phase 구현 진행 승인으로 간주하지 않는다.
- Approval meaning: 승인하면 메인 에이전트가 승인된 stable step ID에 한해 phase 파일 작성과 phase-scoped PI pipeline을 추가 사용자 확인 없이 수행한다. 표시 범위에서 생략된 stable step ID는 승인되지 않았으며 실행하지 않는다. 이 gate는 최종 PR write 승인으로 확장되지 않는다.

Phase-scoped stable step ID:

| Stable step ID | 수행 내용 |
|---|---|
| PHASE-MATERIALIZE | 승인된 phase file draft body를 phase 파일로 작성하고 master PRD `Active Phase File` / `Next Phase Materialization`을 갱신 |
| PI-IMPLEMENT | 해당 phase 구현 진행 |
| PI-COMMIT | 해당 phase 구현 커밋 |
| PI-RUN-DA | 해당 phase diff 기준 `/run-da for_pr` |
| PI-PARALLEL-AUDIT | 해당 phase diff 기준 `/parallel-audit` |
| PHASE-END-PRD-SYNC | phase validation, phase-end review, Phase-End Finding Disposition 표, phase 파일과 master PRD sync 반영 |
| PHASE-END-COMMIT | phase-end finding disposition이 모두 satisfied 또는 explicitly deferred인 상태에서 `PHASE-END-PRD-SYNC`가 만든 phase/master PRD 변경을 커밋하고 다음 phase-start materialization gate 또는 final closeout gate 전 checkpoint로 고정 |

Phase-scoped dependency closure:

| Stable step ID | Requires |
|---|---|
| PHASE-MATERIALIZE | 승인된 phase file draft body + 승인된 master PRD materialization update |
| PI-IMPLEMENT | PHASE-MATERIALIZE |
| PI-COMMIT | PI-IMPLEMENT |
| PI-RUN-DA | PI-COMMIT |
| PI-PARALLEL-AUDIT | PI-RUN-DA |
| PHASE-END-PRD-SYNC | PI-PARALLEL-AUDIT |
| PHASE-END-COMMIT | PHASE-END-PRD-SYNC + phase-end finding disposition table all satisfied/deferred |

Phase-scoped default display string:
`Phase-scoped 자동 수행: PHASE-MATERIALIZE, PI-IMPLEMENT, PI-COMMIT, PI-RUN-DA, PI-PARALLEL-AUDIT, PHASE-END-PRD-SYNC, PHASE-END-COMMIT (default)`

phase-start materialization gate도 ordered chunk를 사용할 수 있지만, 각 chunk에는 target path와 승인 후 그대로 작성될 durable body가 있어야 한다. 요약·경로·checksum만 있는 chunk는 승인으로 간주하지 않는다.

Phase-end finding remediation:
- Docs/PRD-only remediation이 승인된 phase scope 안에 머물면 `PHASE-END-PRD-SYNC`에 기록하고 `PHASE-END-COMMIT`으로 커밋한다.
- Implementation-code remediation은 기존 phase-scoped PI chain을 다시 탄다: `PI-IMPLEMENT` remediation -> `PI-COMMIT` -> `PI-RUN-DA` -> `PI-PARALLEL-AUDIT` -> `PHASE-END-PRD-SYNC` -> `PHASE-END-COMMIT`.
- Remediation 또는 deferred 결정이 승인된 phase scope를 넘으면 아래 `phase-remediation approval packet`으로 dependency-closed remediation/deferred scope와 관련 phase-scoped stable step ID를 다시 승인받는다. 요약·경로·checksum만으로 진행하지 않는다.

### phase-remediation approval packet

이미 materialized 된 phase의 phase-end remediation/deferred 결정이 기존 승인 scope를 넘으면 아래 승인 표면을 사용한다. 이 packet은 phase 파일을 새로 만드는 승인이 아니므로 `PHASE-MATERIALIZE`를 포함하지 않는다.

- Current phase state: master PRD `Document Status`, active phase file, `Last Completed Step`, `Next Blocking Step`, phase-end Finding Disposition 상태
- Remediation/deferred scope: 승인 후 수행할 exact remediation 또는 deferred decision. 구현 코드 변경, docs/PRD-only 변경, follow-up 분리 중 어느 것인지 명시한다.
- Target files: remediation이 tracked write를 포함하면 target path 목록을 제시한다.
- Approved durable body or minimal patch: docs/PRD tracked write가 있으면 승인 후 그대로 적용할 본문 또는 minimal patch를 제시한다. 요약·경로·checksum만으로 tracked write 승인을 대체하지 않는다.
- Approved steps: dependency-closed stable step ID 전체를 펼쳐서 표시한다. 예: `PI-IMPLEMENT, PI-COMMIT, PI-RUN-DA, PI-PARALLEL-AUDIT, PHASE-END-PRD-SYNC, PHASE-END-COMMIT` 또는 `PHASE-END-PRD-SYNC, PHASE-END-COMMIT`.
- Excluded steps: 생략된 phase-scoped stable step ID와 생략 근거를 표시한다. 생략 항목이 없으면 `N/A`.
- Approval meaning: 승인하면 메인 에이전트가 승인된 remediation/deferred scope와 stable step ID에 한해 추가 사용자 확인 없이 수행한다. 이 gate는 phase rematerialization이나 최종 PR write 승인으로 확장되지 않는다.

## final closeout gate packet

split mode에서는 모든 phase 파일이 materialized 되고 phase-end PRD sync commit checkpoint가 끝난 뒤 아래 두 gate를 순서대로 제시한다. 첫 gate는 final review/follow-up commit만 승인한다. 두 번째 gate는 follow-up commit까지 끝나 final diff가 고정된 뒤 exact PR title/body로 PR write만 승인한다.

### final review gate

- Final PRD state: master PRD `Document Status`, 모든 materialized phase 파일 목록, 남은 `Pending phase-start approval` 없음, 모든 `PHASE-END-COMMIT` checkpoint 완료
- Final review / follow-up scope: 최종 diff 요약, Final Multi-Pass Review 수행 범위, follow-up commit에 포함할 수 있는 변경 범위
- PRD final review 자동 수행 범위: `PI-FINAL-REVIEW`, `PI-FOLLOWUP-COMMIT`
- Approval meaning: 승인하면 메인 에이전트가 승인된 stable step ID에 한해 final review와 필요한 follow-up commit을 추가 사용자 확인 없이 수행한다. follow-up commit은 final review가 같은 승인 scope 안에서 요구한 변경으로 제한한다. 이 gate는 GitHub PR write 승인으로 확장되지 않는다.

Final review default display string:
`PRD final review 자동 수행: PI-FINAL-REVIEW, PI-FOLLOWUP-COMMIT (default)`

### final PR write gate

이 gate는 final review가 끝나고 필요한 follow-up commit이 모두 끝난 뒤, `/create-pr prepare` 결과를 master PRD `Approved PR Write Artifact` 섹션에 기록하고 그 PRD 변경까지 커밋해 final diff가 고정된 뒤에만 제시한다. Final review가 clean이면 `PI-FOLLOWUP-COMMIT: N/A`를 기록하고, artifact commit 이후 diff state를 고정한다. 승인 후 artifact나 PRD marker를 tracked file에 추가로 쓰면 approved head commit SHA가 바뀌므로 금지한다.

- Final fixed diff state: follow-up/artifact commit 이후 최종 diff 요약, base repository owner/name, head branch, target branch, head repository owner/name, approved head commit SHA
- PR write target: `create` 또는 `update`. `update`이면 PR number/URL, current title, 현재 base repository owner/name, 현재 base/head, head repository owner/name, current head commit SHA, title 변경 여부를 함께 제시한다. title 변경이 승인 표면에 없으면 기존 title을 보존한다.
- PR write body: GitHub에 전달할 exact PR title(생성 또는 승인된 title 변경 시)과 full PR body. `/create-pr prepare`나 create-pr 8섹션 템플릿으로 생성한 exact title/body를 이 gate에 그대로 제시한다. `/create-pr` 입력이나 요약은 supporting context로만 사용할 수 있으며 PR write 승인 근거가 될 수 없다. committed artifact에는 exact title/body와 stable write tuple만 저장하고, artifact commit 때문에 다시 바뀌는 approved head commit SHA는 저장하지 않는다.
- PRD final PR write 자동 수행 범위: `PI-CREATE-PR`
- Approval meaning: 승인하면 메인 에이전트가 승인된 `PI-CREATE-PR` 범위에 한해 `/create-pr apply-approved`로 PR 생성/업데이트를 추가 사용자 확인 없이 수행한다. 승인 후 write mode, PR number, base repo, target/head branch, head repository owner/name, head commit SHA, title/body를 재발견하거나 재생성하지 않는다. 직접 `gh pr create/edit`로 우회하지 않는다.

Final PR write default display string:
`PRD final PR write 자동 수행: PI-CREATE-PR (default)`

두 gate 모두 요약·경로·checksum만으로 대체할 수 없다. 승인 후 target branch, PR write 범위, PR title/body, 또는 승인 scope 밖의 final diff 변경이 필요하면 다시 승인받는다. 생성된 PR title/body가 승인된 title/body와 다르면 GitHub write 전에 final PR write gate를 다시 수행한다. split final PR write gate 이후 기본 `/create-pr` 생성 경로를 다시 실행하지 않는다.

Final gate runtime approval record:

```markdown
- YYYY-MM-DD: FINAL_REVIEW_GATE_APPROVED step_ids=[PI-FINAL-REVIEW,PI-FOLLOWUP-COMMIT] base=<owner/repo> head=<owner/repo@sha> target=<branch> followup_scope=<summary-or-N/A>
- YYYY-MM-DD: FINAL_PR_WRITE_GATE_APPROVED mode=<create|update> pr=<number-or-N/A> base=<owner/repo> head=<owner/repo:branch@sha> target=<branch> title_change=<yes|no> approved_pr_artifact=PRD:Approved PR Write Artifact/<entry-id>
```

`approved_pr_artifact` must reference the master PRD `Approved PR Write Artifact` section. That section must contain the exact PR title for create or title-change writes, the approved current title for no-title-change updates, full PR body, write mode, base repository owner/name, target branch, head repository owner/name, and head branch, and it must already be committed before the final PR write gate is shown. The approved head commit SHA is captured only in the final PR write gate runtime approval record after the artifact commit fixes the final diff. The approval record itself is a runtime approval record, not a post-gate tracked PRD write. Inline chat text, `/tmp` paths, transient tool output, summaries, checksums, or paths without the exact title/body are not resumable approval markers; on resume, use the durable artifact to present the final PR write gate again unless the same active runtime still has the approval record.
