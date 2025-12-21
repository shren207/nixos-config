---
description: 현재 git 브랜치의 모든 변경 사항(working tree, staged, unpushed, incoming)을 종합적으로 요약하고, 변경된 코드 내의 TODO를 추출합니다.
argument-hint: [base-ref]
allowed-tools: |
  Bash(git fetch:*),
  Bash(git status:*),
  Bash(git rev-parse:*),
  Bash(git branch:*),
  Bash(git rev-list:*),
  Bash(git log:*),
  Bash(git diff:*),
  Bash(echo:*),
  Bash(printf:*)
---

# /catchup — 브랜치 변경 사항 요약(digest)

당신은 현재 리포지토리에 대해 간결하고 실행 가능한 "catch-up(현황 파악)" 보고서를 작성하는 유용한 어시스턴트입니다. 항상 로컬 및 원격의 모든 변경 사항을 종합적으로 분석합니다.

## 입력(Inputs)

- **base_ref** = "$1" (기본값: upstream 추적 브랜치 `@{upstream}`; 없는 경우 `origin/<current-branch>` 사용; 실패 시 `origin/main` 사용)

## 컨텍스트 (사실 관계 우선 수집)

- 현재 브랜치: !`git branch --show-current`
- 원격 상태 Fetch (병합 없음): !`git fetch --prune --tags --all`
- 상태 (요약): !`git status -sb`
- Upstream (설정되지 않았을 수 있음): !`git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || echo "none"`
- base_ref 대비 Ahead(Unpushed) 개수: !`git rev-list --count ${1:-@{upstream}}..HEAD 2>/dev/null || echo "0"`
- base_ref 대비 Behind(Incoming) 개수: !`git rev-list --count HEAD..${1:-@{upstream}} 2>/dev/null || echo "0"`

### 로컬 변경 사항 (Local changes)

- Unstaged 요약: !`git diff --stat`
- Staged 요약: !`git diff --stat --cached`

### 커밋 차이 (제공된 경우 base_ref 사용)

- Unpushed 커밋 로그: !`git log --oneline --decorate -n 30 ${1:-@{upstream}}..HEAD 2>/dev/null || echo "Unable to determine unpushed commits"`
- Incoming(들어오는) 커밋 로그: !`git log --oneline --decorate -n 30 HEAD..${1:-@{upstream}} 2>/dev/null || echo "Unable to determine incoming commits"`

## 작업(Task)

1. 수집된 출력을 사용하여 위에서 설명한 대로 **base_ref**를 확인(Resolve)합니다.
2. **모든 범위(Local, Unpushed, Incoming)**의 변경 사항을 종합하여 보고서 작성을 준비합니다.
3. 현재 프로젝트 디렉토리에 `CLAUDE.local.*.md` 파일이 존재하는 경우, 이를 참조합니다.
4. TODO 파일 생성 (필수):
   작업 트리(Working Tree)가 깨끗하더라도, 이미 커밋된 내역(Committed)에 TODO가 있을 수 있습니다. 
   (주의: Incoming 변경 사항에 포함된 TODO는 내 작업이 아니므로 제외해야 합니다. 아래 명령어는 `${base_ref}..HEAD` 방향을 사용하므로, 내가 작성한(Unpushed) 내용만 필터링하고 Incoming은 자동으로 제외됩니다.)

   **실행할 검사 (명령어 필수):**
   *아래 명령어는 파일명(diff), 위치정보(@@), TODO내용을 모두 보존하면서 필터링하는 명령어입니다.*
   1. **Unstaged**: `git diff -U0 | grep -iE "^(diff --git|@@|\+.*TODO)"`
   2. **Staged**: `git diff --cached -U0 | grep -iE "^(diff --git|@@|\+.*TODO)"`
   3. **Committed Range (My Changes)**: `git diff -U0 ${base_ref}..HEAD | grep -iE "^(diff --git|@@|\+.*TODO)"`

   **수행 로직 및 작성 규칙:**
   - 위 명령어로 추출된 텍스트를 분석하여 `TODO.md`를 생성(덮어쓰기)합니다.
   - **그룹화**: 임의의 카테고리(예: UI개선, 리팩토링 등)로 나누지 마십시오. **반드시 파일 경로(`diff --git a/...`)를 기준으로 그룹화**해야 합니다.
   - **라인 번호 계산**: 출력 결과에 남아있는 Hunk Header(`@@ ... +L,S @@`)의 `L` 값을 참조하여, 해당 TODO가 위치한 줄 번호를 계산해 `(L#)` 형식으로 명시하십시오.

  <example>
  ```markdown
  ## src/server.ts
  - [ ] TODO: Add rate limiting middleware (L52)
  - [ ] TODO: Make this configurable (L116)

  ## src/components/Button.tsx
  - [ ] TODO: Fix typo (L20)
  ``` 
  </example>

5. 필요한 모든 정보를 수집하고 작업을 수행한 후, 다음 형식을 사용하여 한국어로 구조화된 보고서를 작성합니다:

## 현재 작업 (Current Work)

(최근 커밋, 브랜치 이름, 그리고 가능한 경우 `CLAUDE.local.*.md` 파일의 맥락을 바탕으로 현재 활성화된 작업을 간략히 설명합니다)

## 진행 상황 요약 (Progress Summary)

- 달성한 내용을 요약합니다: unpushed 커밋, staged/unstaged 변경 사항, 주요 마일스톤 등 
- 참고: 새로 추가된 TODO 항목이 발견되어 TODO.md 파일이 생성된 경우 이를 언급해 주십시오

## 다음 단계 (Next Steps)

1. Incoming 확인 (최우선):
  - 만약 'Incoming(Behind) 개수'가 1 이상이라면, 목록의 가장 첫 번째 항목으로 다음 경고를 굵게 표시하십시오: `🚨 원격 브랜치에 반영해야 할 변경 사항이 있습니다. (git pull, merge 또는 rebase 필요)`

2. 권장 조치:
  - 이후 테스트 실행, 충돌 해결, 변경 사항 push 등 일반적인 다음 단계를 나열하십시오.
  - 목록이 길어질 경우 상위 항목 위주로 간결하게 유지하십시오. 