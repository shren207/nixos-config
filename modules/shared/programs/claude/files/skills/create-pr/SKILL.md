---
name: create-pr
argument-hint: "[prepare [create|update]|apply-approved|update]"
description: |
  Create structured PR. Default: create new PR. Args: prepare (draft exact title/body without write), apply-approved (write approved title/body), update (existing PR body).
  Trigger: 'PR 만들어줘', 'PR 생성', 'PR 올려', 'create PR', 'PR 업데이트', 'Human Test'.
  NOT for DA (use run-da). NOT for PR 코멘트 (use review-pr-feedback).
---

# 상세 PR 작성

`$ARGUMENTS`가 비어있으면 새 PR을 생성하고, `prepare`이면 GitHub write 없이 exact title/body를 생성하며, `apply-approved`이면 이미 승인된 exact title/body만 GitHub에 쓴다. `update`이면 기존 PR 본문을 업데이트한다. `prepare create` / `prepare update`로 write mode를 명시할 수 있으며, bare `prepare`는 현재 브랜치 PR이 있으면 `update`, 없으면 `create`로 추론한다.

## 빠른 참조

| 항목 | 위치 |
|------|------|
| 8섹션 PR 본문 템플릿 상세 | [references/pr-template.md](references/pr-template.md) |
| Pre-Merge E2E 테스트 가이드 작성 규칙 | [references/pre-merge-guide.md](references/pre-merge-guide.md) |

## 필수 8섹션 템플릿

PR 본문은 반드시 다음 8개 섹션을 포함한다.

| # | 섹션 | 역할 |
|---|------|------|
| 1 | Summary | 핵심 변경 1-3 bullet + `Closes #N` |
| 2 | 기존 문제/배경 | Pain point — 왜 이 변경이 필요한지 |
| 3 | CIR (Change Intent Record) | 발견 경위 + 설계 의도 + 대안 검토 이력. **검토 라운드/finding ID/partial hash chain 포함 금지** (변경 의도는 자연어로) |
| 4 | ADR (Architecture Decision Record) | 대안 비교 테이블 (대안/설명/장점/단점/결정) |
| 5 | 구현 상세 | 변경 파일 테이블 + 핵심 코드 스니펫 |
| 6 | 참고 레퍼런스 | 관련 PR/이슈/외부 링크 (안정 식별자: PR 번호, 이슈 번호, 또는 머지된 SHA — partial hash chain 금지) |
| 7 | Human Test Plan | 단계별 기대동작 + 실패 시 진단 가이드 |
| 8 | Pre-Merge E2E 테스트 가이드 | LLM이 직접 실행하는 자동 검증 절차 |

각 섹션의 작성 규칙, 예시, 흔한 실수는 [references/pr-template.md](references/pr-template.md) 참조.

## PR 전 결정

PR을 생성하기 전에, 작업 결과의 처리 방향을 결정한다:

| 선택지 | 조건 | 행동 |
|---|---|---|
| **PR 생성** | 리뷰가 필요한 변경 | 이 스킬의 절차를 진행 |
| **직접 merge** | 사용자가 명시적으로 승인한 단순 변경 | main에 현재 브랜치를 `git merge` 후 종료 |
| **보류 (keep)** | 추가 작업이 필요하거나 다른 브랜치와 조율 필요 | 사용자에게 보고 후 종료 |
| **폐기 (discard)** | 접근 방식이 잘못되었거나 불필요해짐 | 사용자 확인 후 브랜치 삭제 |

판단이 어려우면 **PR 생성**을 기본으로 선택한다.

## 절차

### 새 PR 생성 (기본)

첫 토큰이 `prepare`이면 no-write prepare mode, `apply-approved`이면 approved-write mode, `update`이면 기존 PR update mode로 진입한다. `$ARGUMENTS`가 비어있거나 첫 토큰이 위 mode token이 아니면 새 PR을 생성하며, non-mode arguments는 PR 작성 지시나 context로 취급한다.

1. **변경 분석**: `git diff main...HEAD`와 커밋 히스토리(`git log main..HEAD --oneline`)를 분석하여 변경 범위를 파악한다.
2. **연관 이슈 탐색**: 커밋 메시지, 브랜치명, 변경 내용에서 이슈 번호를 추출한다. 관련 이슈가 있으면 Summary에 `Closes #N`을 포함한다.
3. **CIR 수집**: 코드 인라인 주석(`# CIR:`, `# === Change Intent Record ===`)과 커밋 메시지에서 의사결정 이력을 추출한다. 현재 대화 컨텍스트에서도 방향 전환/대안 거부 이력을 수집한다.
4. **ADR 테이블 구성**: 검토한 대안들을 비교 테이블로 정리한다. 대안이 1개뿐이면 ADR 섹션을 간소화한다.
5. **8섹션 템플릿 작성**: [references/pr-template.md](references/pr-template.md)의 템플릿에 따라 전체 PR 본문을 작성한다.
6. **Pre-Merge E2E 가이드 작성**: [references/pre-merge-guide.md](references/pre-merge-guide.md)의 규칙에 따라 Phase 기반 검증 가이드를 포함한다.
7. **PR 생성**: 본문은 임시 파일에 쓰고, title/base/head/body-file 값을 별도 argv element로 전달해 PR을 생성한다. 제목은 70자 미만, conventional commit 형식을 따른다.

### PR 본문 준비 (`prepare`)

`$ARGUMENTS`가 `prepare`인 경우 GitHub write 없이 새 PR 또는 기존 PR 업데이트에 사용할 exact title/body를 생성한다. `prepare create` / `prepare update`가 아니면 현재 브랜치 PR이 있으면 `update`, 없으면 `create`로 write mode를 추론한다.

1. 새 PR 생성 Step 1-6 또는 기존 PR 업데이트 Step 1-3과 동일하게 변경사항을 분석하고 8섹션 본문을 작성한다.
2. 출력은 다음 항목을 포함한다:
   - PR write mode: `create` 또는 `update`
   - Base repository owner/name
   - Target branch / head branch / approved head repo owner/name
   - Approved head commit SHA
   - `create` mode: exact PR title. create의 head는 repo-local branch만 지원한다. cross-repo/fork create는 repo identity를 명시적으로 전달하는 API-backed path가 생기기 전까지 unsupported로 중단한다.
   - `update` mode: PR number/URL, current title, current base repository owner/name, current base/head, head repository owner/name, current head commit SHA, title change 여부. `title_change=yes`이면 exact approved PR title을 함께 출력한다. 제목 변경이 승인 표면에 명시되지 않으면 기존 title을 보존한다.
   - Exact full PR body
3. `prepare` 모드에서는 `gh pr create`, `gh pr edit`, review comment 작성, thread resolve 같은 GitHub write를 수행하지 않는다.
4. split PRD final PR write gate에서 사용할 경우, 이 exact title/body와 approved head commit SHA를 final PR write gate 승인 표면에 그대로 제시한다. PRD/plan 같은 tracked file에 exact PR body를 저장하지 않는다. 승인 후 문구나 head SHA가 바뀌면 다시 `prepare`를 수행하고 final PR write gate를 다시 승인받는다.

### 승인된 PR 쓰기 (`apply-approved`)

`$ARGUMENTS`가 `apply-approved`인 경우 이미 승인된 exact title/body만 GitHub에 쓴다.

1. 입력 또는 승인 표면에서 PR write mode(`create`/`update`), full PR body, base repository owner/name, target branch, head branch, approved head repo owner/name, approved head commit SHA를 확인한다. `create` mode는 exact PR title이 필요하고, `update` mode는 PR number/URL과 승인 시점 current title이 필요하며 `title_change=yes`이면 exact approved PR title도 필요하다. 요약이나 `/create-pr prepare` 실행 지시만 있고 필요한 exact field가 없으면 중단한다.
2. PR 본문이 8섹션을 모두 포함하는지 검증한다. 누락이 있으면 본문을 재생성하지 말고 `prepare`로 돌아가 다시 승인받는다.
3. GitHub write 직전에 title/body를 재작성하거나 현재 diff로 다시 생성하지 않는다. 승인된 문자열을 그대로 body 파일에 저장한다. 모든 GitHub write는 argv-safe 방식으로 실행한다: 승인된 title/base/head/body-file 값을 하나의 shell command string에 보간하거나 `eval`하지 말고, 각 값을 별도 argv element로 전달한다. 이 보장을 할 수 없으면 fail closed 처리한다.
4. `create` mode는 repo-local head만 지원한다. cross-repo/fork head는 `gh pr create --head`가 approved repo name을 직접 고정하지 못하므로 fail closed 처리하고, repo identity를 명시적으로 전달하는 별도 API-backed 절차가 생기기 전에는 `apply-approved create`에서 지원하지 않는다.
5. `create` mode는 GitHub write 직전 approved base repo와 approved head repo가 현재 repo와 일치하는지 확인하고, approved head branch의 remote ref를 `gh api repos/<approved base owner>/<approved base repo>/git/ref/heads/<approved head branch>` 또는 `git ls-remote`로 조회해 approved head commit SHA와 일치하는지 확인한다.
6. `create` mode는 검증이 모두 일치할 때만 승인된 repo/branch/title/body-file을 각각 별도 argv element로 전달해 `gh pr create`를 실행한다. 필수 argv는 `--repo`, approved base `owner/repo`, `--base`, approved target branch, `--head`, approved head branch, `--title`, approved title, `--body-file`, approved body file이다.
7. `create` mode는 생성 후 생성된 PR의 base/head repo, branch, head SHA가 승인 tuple과 일치하는지 확인한 뒤 성공으로 보고한다.
8. `update` mode는 GitHub write 전에 `gh api repos/<approved base owner>/<approved base repo>/pulls/<approved number>`로 현재 PR identity를 확인한다. 승인된 PR URL/number, `.base.repo.full_name`, `.base.ref`, `.head.repo.full_name`, `.head.ref`, `.head.sha`, 현재 title이 승인 tuple과 다르면 중단한다.
9. `update` mode는 승인된 PR number/URL을 대상으로 PR number, `--repo`, approved base `owner/repo`, `--body-file`, approved body file을 각각 별도 argv element로 전달해 `gh pr edit`를 실행한다. `title_change=yes`로 exact approved PR title이 승인 표면에 명시된 경우에만 `--title`과 approved title을 별도 argv element로 추가하고, `title_change=no`이면 기존 title을 보존한다. `apply-approved update`는 base/head 변경을 지원하지 않는다. base 또는 head 변경이 필요하면 기존 PR update를 중단하고 새 PR 생성 또는 수동 절차로 분기한다.
10. 승인된 mode/PR number/base repo/head repo/branch/head SHA/title/body와 실제 write 입력이 다르면 GitHub write를 수행하지 않는다.

### 기존 PR 업데이트 (`update`)

`$ARGUMENTS`가 `update`인 경우 기존 PR 본문을 보강한다.

1. **현재 PR 확인**: `gh pr view --json body,title,number`로 현재 PR 본문을 가져온다.
2. **누락 섹션 탐지**: 8섹션 중 빠진 섹션을 식별한다.
3. **부실 섹션 강화**: 있지만 내용이 부실한 섹션(예: Summary만 있고 CIR 없음)을 보강한다. 커밋 히스토리, 코드 변경, 대화 컨텍스트에서 추가 정보를 수집한다.
4. **업데이트 적용**: 새 본문은 임시 파일에 쓰고, PR number/repo/body-file 값을 별도 argv element로 전달해 PR 본문을 업데이트한다.

## Pre-Merge E2E 테스트 가이드 작성 규칙

PR 본문의 8번째 섹션으로, LLM이 PR을 머지하기 전에 직접 실행할 수 있는 검증 절차를 기술한다.

핵심 구조:
- **Phase 0 (정적 검증)**: 파일 존재 확인, 값 반영 확인, old 값 부재 확인을 grep/ls 등으로 수행한다.
- **Phase 1-N (기능 검증)**: 기능별로 프롬프트 + 기대동작 + 실패 시 진단을 기술한다.
- **Phase N+1 (Regression)**: 인접 기능이 깨지지 않았는지 의도적으로 혼동 가능한 쿼리로 검증한다.

상세 작성 규칙은 [references/pre-merge-guide.md](references/pre-merge-guide.md) 참조.

## 주의사항

- **ADR 테이블 표기**: 채택한 대안은 ✅, 기각한 대안은 ❌로 표시한다.
- **참고 레퍼런스 식별자**: 관련 PR/이슈/외부 링크는 안정 식별자(PR 번호 `#N`, 이슈 번호 `#N`, 또는 머지된 commit SHA)를 사용한다. 본인 PR의 mid-flight commit hash 또는 squash 전 partial hash chain은 박제 금지 — squash 후 dangling 위험. "관련 PR 참조" 식의 모호한 레퍼런스도 금지.
- **DA 피드백 분리**: DA 피드백 루프 결과는 PR 본문이 아닌 별도 코멘트로 분리한다. PR 본문에는 최종 결론만 반영한다.
- **CIR 없는 PR**: 단순 변경(타이포 수정, 버전 업데이트 등)은 CIR/ADR 섹션을 "해당 없음 — 단순 변경"으로 간소화한다. 무리하게 의사결정 이력을 만들어내지 않는다.
- **도구-중립 기술 (Codex / Claude Code / headless 공통)**: 특정 AI 에이전트 전용 도구명을 본문에 하드코딩하지 않는다. "gh pr create를 실행한다"가 아니라 "PR을 생성한다"처럼 행동 의도로 기술한다. 단, 참조/예시에서의 CLI 명령(`gh pr create` 등)은 예외로 허용한다.
- **PR 본문 박제 금지 항목**: 라운드 번호(`Round N`), DA finding ID(예: `Correctness-1`, `CORR-2`), partial commit hash chain, 워크트리 절대경로.
  - 변경 의도(why)는 자연어 설명으로 표현한다. lefthook commit-msg hook이 commit message에서 동일 패턴을 warn-only로 감지하므로 PR 본문도 동일 정책을 따른다.

## 참조 자료

- **[references/pr-template.md](references/pr-template.md)** — 8섹션 PR 본문 마크다운 템플릿 + 섹션별 작성 규칙/예시/흔한 실수
- **[references/pre-merge-guide.md](references/pre-merge-guide.md)** — Pre-Merge E2E 테스트 가이드 작성 규칙 + Phase 구조 + 결과 보고 형식
