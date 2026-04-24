---
name: create-issue
argument-hint: "[issue title or description (optional)] [--parent <NUM|URL>]"
description: |
  Create a structured GitHub issue with auto-enriched labels.
  Trigger: '이슈 등록', '이슈 만들어', 'todo 등록', '버그 등록', '이슈 추가'.
  NOT for CIR/ADR (use documenting-intent). NOT for PR 본문 (use create-pr).
---

# 이슈 등록

`$ARGUMENTS`를 이슈 제목, 설명, 또는 작업 내용으로 수신한다.
텍스트가 제공되면 이슈 제목/설명으로 사용하고,
비어있으면 대화 컨텍스트에서 이슈 내용을 추출한다.

## 빠른 참조

| 항목 | 설명 |
|------|------|
| 입력 | 이슈 제목 또는 설명 (선택). 비어있으면 대화 컨텍스트에서 추출 |
| 출력 | 구조적 이슈 등록 + URL 반환 |
| 핵심 도구 | 코드베이스 검색, `gh` CLI |
| 범위 | 등록 전용. 조회/감사/라이프사이클은 `gh` CLI를 직접 사용 |

## 런타임 도구 매핑

이 스킬은 Claude Code 세션과 direct Codex 세션 모두에서 동작한다.
사용자에게 질문하는 행동은 런타임에 해당하는 도구로 수행한다.

| 행동 | Claude Code 세션 | Codex 세션 |
|------|------------------|------------|
| 사용자에게 질문 | `AskUserQuestion` 도구 | plain-text 번호 질문 |

본문에서 "질문 도구"는 위 표의 런타임별 실제 도구를 가리킨다.

## 용어 / 변수 계약

Sub-Issues API는 GitHub visible issue number와 database id를 서로 다른 위치에서 요구한다. parent는 REST path의 `{issue_number}`(= visible number)만 사용하고, child의 database id만 POST body의 `sub_issue_id`로 전달한다. `_NUM`과 `_ID`를 바꿔 쓰면 Sub-Issues API 호출이 404 또는 422로 실패한다.

| 변수 | 의미 | 예시 |
|------|------|------|
| `OWNER_REPO` | 현재 cwd의 GitHub repo canonical `nameWithOwner` (= `gh repo view --json nameWithOwner -q .nameWithOwner` 결과) | `greenheadHQ/nixos-config` |
| `OWNER` | `OWNER_REPO`에서 분리한 owner (case-preserved canonical 값) | `greenheadHQ` |
| `REPO` | `OWNER_REPO`에서 분리한 repo 이름 | `nixos-config` |
| `PARENT_NUM` | parent의 GitHub visible issue number (integer). REST path의 `{issue_number}` | `539` |
| `ISSUE_URL` | `gh issue create`가 반환하는 HTML URL | `https://github.com/OWNER/REPO/issues/540` |
| `ISSUE_NUM` | `ISSUE_URL`에서 추출한 child의 visible number | `540` |
| `ISSUE_ID` | 새로 생성된 child 이슈의 database id. Sub-Issues POST body의 `sub_issue_id` | `4313342653` |

### 공통 repo 컨텍스트 초기화 스니펫

Step 0(`--parent` pre-check)과 Step 5-B(sub-issue 연결) 양쪽에서 `OWNER_REPO`/`OWNER`/`REPO`를 필요로 한다. 두 위치 모두 아래 스니펫을 idempotent하게(`:=` 파라미터 확장) 호출한다 — 이미 설정됐으면 재조회하지 않는다. resolution 규칙을 바꿀 경우 이 스니펫만 수정한다.

```bash
# ensure-repo-context
: "${OWNER_REPO:=$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
OWNER="${OWNER_REPO%%/*}"
REPO="${OWNER_REPO##*/}"
```

## 절차

### Step 0 — `--parent` 파싱 + pre-check (옵션 지정 시)

`$ARGUMENTS`가 `--parent` 토큰을 포함하면 Step 1 본문에 진입하기 전에 이 단계를 수행한다. `--parent` 미지정 시 이 단계를 건너뛰고 기존 동작을 유지한다.

**파싱 규칙**:

- `--parent=<값>` 또는 `--parent <값>` 형식만 옵션으로 인식한다. 위치는 자유(토큰 앞/중/뒤 모두 허용).
- `--` 이후의 모든 토큰은 옵션으로 소비하지 않고 제목/본문으로 취급한다 (escape 경로).
- `--parent` 뒤 토큰이 아래 값 패턴 중 하나에 매칭되면 옵션으로 소비하여 `PARENT_NUM`으로 정규화한다. 매칭되지 않거나 뒤 토큰이 없으면 **옵션으로 소비하지 않고 `--parent` 문자열을 자유 텍스트로 유지**한다 (`exit 1`하지 않음). 예: `/create-issue "--parent 옵션 문서화 이슈"`는 기존과 동일하게 제목/본문으로 흐른다. 사용자가 명시적 옵션 입력을 원하면 `--parent=<값>` 형식이나 유효한 값 패턴을 사용한다.

**값 패턴** (둘 중 하나에만 매칭 허용):

1. 숫자: `^[0-9]+$` — `PARENT_NUM`으로 직접 사용.
2. anchored URL: `^https://github\.com/([^/]+)/([^/]+)/issues/([0-9]+)([/?#].*)?$`
   - owner/repo를 lowercase 정규화하여 `gh repo view --json nameWithOwner -q .nameWithOwner` 결과(lowercase 정규화)와 비교한다. 불일치 시 `"ERROR: cross-repo sub-issue는 미지원"` 출력 후 `exit 1`.
   - GitHub owner/repo는 case-insensitive이므로 raw 비교 금지.
   - `.git`, 추가 slash, percent-encoding이 섞인 비정상 입력은 URL regex에 anchor가 있으므로 거부된다.
   - 매칭된 숫자 그룹을 `PARENT_NUM`으로 추출한다.

**Pre-check** (존재 확인 + object shape 검증, PR 배제):

```bash
# 공통 repo 컨텍스트 초기화 스니펫 실행 (위 "공통 repo 컨텍스트 초기화 스니펫" 섹션 참조).

# GitHub REST GET /repos/{owner}/{repo}/issues/{n}은 PR도 issue object로 반환하며 pull_request 키로 식별된다.
# PR 번호를 parent로 지정하면 Sub-Issues POST 단계에서야 실패하므로, 여기서 사전 차단한다.
if ! PARENT_META=$(gh api "/repos/$OWNER/$REPO/issues/$PARENT_NUM" \
     --jq 'select((.number|type=="number") and (.id|type=="number") and (has("pull_request")|not)) | {number,state}') \
     || [ -z "$PARENT_META" ]; then
  echo "ERROR: parent #$PARENT_NUM 조회 실패, 이슈가 아님, 또는 PR 번호"
  exit 1
fi
```

성공 시 `PARENT_NUM`을 Step 5-B에서 재사용한다. parent가 `closed` 상태여도 차단하지 않는다 (v1 YAGNI 범위).

Step 0 완료 후 나머지 `$ARGUMENTS`(=`--parent`/값 토큰 제거 후의 자유 텍스트)가 Step 1 본문의 title/description 경로로 흐른다.

### Step 1 — 코드베이스 탐색

이슈 내용을 기반으로 관련 컨텍스트를 수집한다 (Summary A1/Context A2 작성에 필요). LLM 친화성 체크리스트 A 섹션 참조 ([../write-handoff/references/llm-friendly-checklist.md](../write-handoff/references/llm-friendly-checklist.md)).

- **(a) 관련 파일 탐색**: 이슈에 언급된 경로는 `Read`로, 모듈/키워드는 `Glob`/`Grep`으로 탐색.
  예: `Glob "**/*.nix"`, `Grep -n "<키워드>" modules/`, `find . -name "*.nix" -path "*<모듈>*"`.
- **(b) 관련 이슈 검색**: `gh issue list --search "<키워드>" --state all --limit 20`으로 중복/관련 이슈 확인.
- **(c) 관련 커밋 확인**: `git log --oneline -20 -- <관련 경로>` 또는 `git log --grep="<키워드>"`.

### Step 2 — 템플릿 작성

`references/issue-template.md`를 참조하여 이슈 본문을 작성한다.

**필수 섹션** (항상 작성):
- **Summary**: 1-2 문장으로 what + why 요약 (체크리스트 A1)
- **Context**: 현 상태 → 문제점 → 필요성 순으로 서술 (체크리스트 A2)
- **References**: 비자명 주장의 출처 링크 최소 1개 이상 (체크리스트 B1/B4). 공식 docs URL, repo 내부 파일 경로(`path/to/file.nix:LINE`), 관련 이슈/커밋(`#NNN`/`abc1234`). 근거 부재 시 `[UNVERIFIED]` 라벨로 대체.
- **Proposed Changes**: 체크박스(`- [ ]`) 형태의 구체적 변경 계획

**선택 섹션** (판단 기준에 따라 포함):
- **PoC / Reproduction**: 재현이 중요한 주장(버그 리포트 등)에 6필드 포함 — `환경 / 입력 / 절차 / 기대 결과 / 실제 결과 / 성공 기준` (체크리스트 C1)
- **Related Commits**: `$ARGUMENTS` 또는 대화 컨텍스트에 커밋 해시가 언급되었거나, Step 1(c)에서 직접 관련 커밋을 발견한 경우
- **Affected Files**: 변경 대상 파일이 여러 개인 경우 (테이블 형식)
- **Notes**: 추가 참고사항(제약사항, 관련 이슈 번호, YAGNI 판단 근거 등)이 있는 경우

### Step 3 — Anti-hallucination 자체 검증

작성된 이슈 본문에 체크리스트 E1/E2를 적용한다 (규칙 상세 정의와 출처는 [`../write-handoff/references/llm-friendly-checklist.md`](../write-handoff/references/llm-friendly-checklist.md) Normative E1/E2 참조).

- **E1**: 근거 없거나 확신 낮은 주장은 `[UNVERIFIED]` 라벨 또는 삭제 (라벨 체계 상세는 [체크리스트 라벨 체계](../write-handoff/references/llm-friendly-checklist.md#라벨-체계-anti-hallucination) 참조).
- **E2**: 비자명 주장을 검증 질문으로 변환 → `Read`/`Grep`/`gh` 재실행으로 독립 확인 → 불일치/근거 부재 시 라벨 또는 삭제.

### Step 4 — 라벨 자동 결정

`references/label-taxonomy.md`를 참조하여 라벨을 결정한다.

1. `gh label list`로 기존 area 라벨 목록을 조회한다.
2. 이슈 내용에서 적합한 area를 자동 매칭한다 (기존 area에서만 선택).
3. 매칭되는 area가 없으면 **area 없이 등록하고 사용자에게 알린다** (자동 생성 금지).
4. priority는 이슈 내용의 긴급도/영향도를 기반으로 자동 판단한다 (high/medium/low).
5. GitHub 기본 라벨(enhancement/bug/documentation 등)을 이슈 유형에 맞게 선택한다.

### Step 5 — 등록 및 확인

Step 5는 두 하위 단계로 진행한다. Step 5-A가 실패(등록 실패 또는 URL validation 실패)하면 Step 5-B와 Step 6 모두 건너뛴다 (기존 fail-closed). Step 5-B의 실패는 `WARN:`으로 출력되며 Step 6 진입을 차단하지 않는다 (`--parent` 지정 시만 실행되므로 기본 단일 등록 경로에는 영향 없음).

#### Step 5-A — 이슈 등록

1. 등록 전 **제목, 라벨 조합을 사용자에게 보여주고 확인**을 받는다.
2. 확인 후 `gh issue create`를 **`--body-file`로 실행**한다. 본문은 임시 파일에 저장 후 전달. 실패 시 Step 5-B/6으로 진행하지 않는다.
   ```bash
   # BSD/macOS mktemp는 템플릿 끝(trailing)에 XXXXXX가 와야 랜덤 치환함.
   # 확장자 없이 랜덤 파일 생성 — gh issue create --body-file은 확장자 무관.
   umask 077
   ISSUE_BODY=$(mktemp -t issue-body.XXXXXX) || { echo "ERROR: mktemp 실패"; exit 1; }
   # <작성된 본문>을 $ISSUE_BODY에 기록 (Write 도구)

   # gh issue create — 성공 시 URL 캡처, 실패 시 본문 경로/미리보기 출력 후 exit 1
   if ISSUE_URL=$(gh issue create --title "<제목>" --label "<라벨>" --body-file "$ISSUE_BODY"); then
     echo "ISSUE_URL=$ISSUE_URL"
     rm -f "$ISSUE_BODY"
   else
     rc=$?
     echo "ERROR: gh issue create 실패 (exit $rc)"
     echo "ISSUE_BODY_PATH=$ISSUE_BODY  # 본문 보존됨 (재시도 시 재사용)"
     echo "--- 본문 미리보기 (상위 20줄, shell 세션 외 접근 가능하도록 stdout에 표시) ---"
     head -20 "$ISSUE_BODY"
     echo "---"
     echo "재시도 명령 (동일 shell 세션 또는 ISSUE_BODY_PATH 값을 직접 입력):"
     echo "  gh issue create --title '<제목>' --label '<라벨>' --body-file \"\$ISSUE_BODY_PATH\""
     echo "**Step 5-B와 Step 6은 이슈 등록 완료 전에는 진행하지 않는다.**"
     exit 1
   fi
   ```
3. 반환된 `ISSUE_URL`이 실제 GitHub URL(`https://github.com/.../issues/N`)인지 확인한다. 형식 불일치는 `ERROR:`로 출력하고 Step 5-B/6 진행을 금지한다 (Step 6 진입 가드의 차단 대상).

#### Step 5-B — sub-issue 연결 (`--parent` 지정 시만)

`--parent` 미지정 시 이 단계를 완전히 건너뛴다. 지정 시 child의 database id를 조회한 뒤 Sub-Issues API로 parent에 연결한다. Fail-open: 조회 또는 연결 실패는 이슈 본체 생성을 롤백하지 않으며 Step 6 진행을 차단하지 않는다. 단, 최종 상태를 `SUBISSUE_STATUS=` 토큰으로 항상 명시해 handoff 수신자(Step 6의 다음 LLM 또는 자동화)가 부분 실패를 인지할 수 있게 한다.

```bash
if [ -n "$PARENT_NUM" ]; then
  # 공통 repo 컨텍스트 초기화 스니펫 실행 (Step 0에서 호출됐어도 idempotent).
  ISSUE_NUM="${ISSUE_URL##*/}"

  # Branch 1: child database id 조회
  # Sub-Issues API는 visible issue number가 아니라 child의 database id(sub_issue_id)를 요구한다.
  ISSUE_ID=$(gh api "/repos/$OWNER/$REPO/issues/$ISSUE_NUM" -q '.id' 2>/dev/null || true)

  if [ -z "$ISSUE_ID" ]; then
    # Branch 1 failure: child id 조회 실패 → POST 스킵
    echo "WARN: ISSUE_ID 조회 실패 — sub-issue 연결 스킵, 수동 재시도 필요"
    echo "SUBISSUE_STATUS=FAILED_ID_LOOKUP  # ISSUE_URL=$ISSUE_URL (이슈는 생성됨, parent 미연결)"
    echo "재시도 (ISSUE_ID 재조회 포함):"
    echo "  ISSUE_ID=\$(gh api /repos/$OWNER/$REPO/issues/$ISSUE_NUM -q .id)"
    echo "  gh api -X POST /repos/$OWNER/$REPO/issues/$PARENT_NUM/sub_issues -F sub_issue_id=\$ISSUE_ID"
  else
    # ISSUE_ID 확보됨 → Branch 2 또는 Branch 3 선택
    if gh api -X POST "/repos/$OWNER/$REPO/issues/$PARENT_NUM/sub_issues" \
         -F "sub_issue_id=$ISSUE_ID" >/dev/null; then
      # Branch 2: 연결 성공
      echo "SUBISSUE_STATUS=LINKED"
      echo "SUBISSUE_LINKED=#$ISSUE_NUM -> parent #$PARENT_NUM"
    else
      # Branch 3: Sub-Issues POST 실패
      rc=$?
      echo "WARN: sub-issue 연결 실패 (exit $rc)"
      echo "SUBISSUE_STATUS=FAILED_POST  # ISSUE_URL=$ISSUE_URL (이슈는 생성됨, parent 미연결)"
      echo "재시도: gh api -X POST /repos/$OWNER/$REPO/issues/$PARENT_NUM/sub_issues -F sub_issue_id=$ISSUE_ID"
    fi
  fi
fi
```

**상태 토큰**: `--parent` 지정 시 Step 5-B는 아래 중 하나를 반드시 출력한다.

| `SUBISSUE_STATUS` | 의미 |
|-------------------|------|
| `LINKED` | child의 parent 연결 성공 |
| `FAILED_ID_LOOKUP` | child id 조회 실패 (parent 연결 미시도) |
| `FAILED_POST` | Sub-Issues POST 자체가 실패 |

Step 6은 `LINKED` 이외의 상태에서도 진행하지만, 이 토큰은 handoff body나 다음 LLM 출력에 명시되어 운영자가 부분 실패를 인지하고 재시도 명령을 실행할 수 있다.

### Step 6 — LLM 이행 가이드 연계

**진입 가드**: **Step 5-A에서 `ERROR:`가 출력되었거나 `ISSUE_URL`이 유효한 GitHub issue URL이 아니면 Step 6으로 진행하지 않는다** — `gh issue create` 실패와 URL validation 실패(`https://github.com/.../issues/N` 형식 불일치) 모두 차단 대상이다. 존재하지 않거나 잘못된 이슈 번호로 `/write-handoff`를 호출하면 handoff comment가 엉뚱한 곳에 게시되거나 오류로 중단된다. 반면 Step 5-B의 `SUBISSUE_STATUS=FAILED_ID_LOOKUP` 또는 `SUBISSUE_STATUS=FAILED_POST`는 Step 6 진행을 차단하지 않는다 — 이슈 본체는 이미 생성되었으므로 handoff 수신자(다음 LLM)는 `ISSUE_URL`로 정상 동작할 수 있다. 단, **Step 6을 진행할 때 `SUBISSUE_STATUS` 값을 handoff body 또는 사용자 응답에 명시적으로 보고**하여 운영자가 parent 연결 부분 실패를 인지하고 로그된 재시도 명령을 실행할 수 있게 한다.

**호출 맥락 확인**: plan-with-questions에서 호출된 경우(Step I-5), 이 Step을 건너뛴다.
(plan-with-questions Step I-6에서 통합 선택지로 제안하므로 중복 방지.)

이슈 생성이 완료되면, 질문 도구로 사용자에게 묻는다:

"LLM 이행 가이드를 작성할까요?"

- 사용자가 승인 → `/write-handoff <생성된 ISSUE_URL>` 스킬을 실행한다 (bare 번호 대신 Step 5의 `ISSUE_URL`을 전달해 write-handoff 헬퍼의 cwd 의존성을 회피한다, #486).
- 사용자가 거부 → 이슈 URL 반환 후 종료한다.

## Title Conventions

| Prefix | Use |
|--------|-----|
| `feat:` | 새 기능, 개선 |
| `fix:` | 버그 수정 |
| `refactor:` | 구조 변경 (동작 불변) |
| `test:` | 테스트 추가/수정 |
| `docs:` | 문서 |
| `chore:` | 기타 유지보수 |

**Epic/Umbrella 패턴 예시**:
- `refactor(skills): X 단순화 (epic, #A/#B/#C)`
- `feat(codex): Y 캠페인 (epic, Wave 1)`

Umbrella를 사용할 때는 먼저 `/create-issue`로 umbrella를 등록한 뒤, 반환된 번호(또는 URL)를 children 등록 시 `--parent <umbrella_NUM|URL>`로 전달한다. `/create-issue` 자체는 단일 등록만 수행한다 — 복수 이슈 순서 유도나 umbrella 선생성 판단은 이 스킬의 책임이 아니다.

## 주의사항

- 이슈 본문에 시크릿/credential/API 키를 포함하지 않는다. `.age` 복호화 값, `.env` 내용은 파일 경로만 참조한다.
- 조회(`gh issue list`), 감사(audit), 라이프사이클(close/reopen/edit), 라벨 관리(CRUD)는 이 스킬의 범위 밖이다. `gh` CLI를 직접 사용한다.
- `gh issue create` 실행 시 본문은 **`--body-file`로 전달**한다. HEREDOC(`$(cat <<'EOF' ... EOF)`) 방식은 본문 내부에 PoC/Reproduction 섹션의 nested `cat <<'EOF'` 예시나 독립 `EOF` 라인이 포함될 때 outer heredoc가 조기 종료되어 등록이 실패하거나 본문이 잘린다. `PoC / Reproduction` 섹션(issue-template)의 shell 재현 스니펫이 기본 기능이므로 HEREDOC 전달은 금지.
## 참조 자료

- **[references/issue-template.md](references/issue-template.md)** -- 이슈 템플릿 (필수 섹션: Summary/Context/References/Proposed Changes + 선택 섹션: PoC/Related Commits/Affected Files/Notes) + 섹션별 작성 가이드 + 작성 예시
- **[references/label-taxonomy.md](references/label-taxonomy.md)** -- 라벨 체계 상세 (색상 코드, 판단 기준, 설계 근거)
- **[LLM 친화성 체크리스트](../write-handoff/references/llm-friendly-checklist.md)** -- `create-issue`/`write-handoff` 공유. Normative(스킬 강제) + Informational(권장) 분리. 라벨 체계(`[UNVERIFIED]`/`[INFERRED]`/`[CONFLICTING]`). 공식 docs/학술 출처 링크 포함
