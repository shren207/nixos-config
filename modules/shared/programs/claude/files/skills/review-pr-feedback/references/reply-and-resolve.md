# 답글 + resolve + 재확인 playbook

`review-pr-feedback` 스킬 Step 6/7의 정본.
review thread와 PR 일반 코멘트는 API 모델이 다르므로 플로우가 갈린다.

## 플로우 요약

| 대상 | 답글 mutation | resolve | 재확인 |
|------|---------------|--------|-------|
| Review thread | `addPullRequestReviewThreadReply` | `resolveReviewThread` | `reviewThreads { isResolved }` |
| PR 일반 코멘트 (issues/{pr}/comments) | `addComment` 또는 REST `POST /issues/{pr}/comments` | 없음 (resolve 개념 없음) | 불필요 |

`addPullRequestReviewThreadReply`와 `resolveReviewThread`는 review thread 전용이다.
PR 본문 아래 대화 탭의 일반 코멘트에는 resolve 상태가 없으며, 답글만 남기고 종료한다.

## Review thread 플로우

### 답글: addPullRequestReviewThreadReply

필요 입력: `thread.id` (Step 1에서 수집한 `reviewThreads.nodes[].id`), `body`.

```bash
# $TID는 reviewThreads.nodes[].id. $BODY_FILE은 mktemp 또는 이미 만들어둔 reply 초안.
BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT
cat > "$BODY_FILE" <<'REPLY'
반영했습니다. (<commit-hash>)

검증 내용:
- confirmed <file>:<line>
- added <fix>
- re-ran <verification command>
REPLY

gh api graphql \
  -f tid="$TID" \
  -f body="$(cat "$BODY_FILE")" \
  -f query='
    mutation($tid: ID!, $body: String!) {
      addPullRequestReviewThreadReply(input: {
        pullRequestReviewThreadId: $tid,
        body: $body
      }) {
        comment { id url }
      }
    }'
```

`gh api graphql -f body="..."`는 gh CLI가 GraphQL String variable로 안전하게 escape한다.
multiline과 따옴표, 백슬래시, 이모지 모두 그대로 전달된다.

### Resolve: resolveReviewThread

```bash
gh api graphql \
  -f tid="$TID" \
  -f query='
    mutation($tid: ID!) {
      resolveReviewThread(input: { threadId: $tid }) {
        thread { id isResolved }
      }
    }'
```

응답의 `thread.isResolved`가 `true`여야 정상. 바로 Step 7(재확인)로 넘어간다.

### 재확인 (Step 7)

`thread.id`를 그대로 넣어 현재 상태를 재조회한다.

```bash
gh api graphql \
  -f tid="$TID" \
  -f query='
    query($tid: ID!) {
      node(id: $tid) {
        ... on PullRequestReviewThread {
          isResolved
        }
      }
    }' | jq '.data.node.isResolved'
```

`true`이면 통과. `false`이면 아래 retry 정책을 따른다.

## PR 일반 코멘트 플로우

review thread가 아닌 PR 본문 아래 대화 탭 코멘트는 resolve가 없다.
답글만 남기고 종료한다.

### REST 경로 (간단)

```bash
BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT
# ... BODY_FILE 작성 ...
jq -n --arg body "$(cat "$BODY_FILE")" '{body: $body}' \
  | gh api --input - \
      --method POST \
      "/repos/$OWNER/$REPO/issues/$PR_NUMBER/comments"
```

`jq -n --arg body` + `gh api --input -` 조합은 newline/따옴표를 안전하게 JSON encode한다.

### GraphQL 경로

```bash
# $SUBJECT_ID는 PR의 Node ID. gh pr view --json id -q .id로 얻을 수 있다.
SUBJECT_ID="$(gh pr view "$PR_NUMBER" --json id -q .id)"

gh api graphql \
  -f sid="$SUBJECT_ID" \
  -f body="$(cat "$BODY_FILE")" \
  -f query='
    mutation($sid: ID!, $body: String!) {
      addComment(input: { subjectId: $sid, body: $body }) {
        commentEdge { node { id url } }
      }
    }'
```

## Multiline body 전송: 안전한 기본 경로와 반례

### 권장 default

1. **GraphQL String variable**: `gh api graphql -f body="$(cat "$BODY_FILE")"` — gh가 String escape 처리.
2. **REST JSON via stdin**: `jq -n --arg body "..." '{body:$body}' | gh api --input - ...` — JSON string escape 처리.
3. **파일이 필요하면 `mktemp` + `trap`**: 고정 경로(`/tmp/reply.md` 등)를 쓰지 말 것. `/tmp`는 world-writable sticky 디렉토리라 다른 프로세스의 파일을 재사용하거나 읽을 위험이 있다.

### 반례: REST form에서 `-f body="..."` 사용 (PR #399 mishap)

```bash
# ❌ 이렇게 하지 말 것
gh api "/repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments/$CID/replies" \
  -f body="line1
line2"
```

REST `-f`는 application/x-www-form-urlencoded field이다. GitHub REST endpoint가
raw JSON body를 기대하는 경우 newline이 리터럴 `\n`으로 들어가거나 payload 자체가
예상과 다르게 encoding된다. PR #399에서 multiline 답글 한 줄이 통째로 리터럴
이스케이프 상태로 전송된 이슈가 바로 이 패턴이었다.

수정된 기본값:

```bash
# ✅ 안전한 대체 — stdin JSON
jq -n --arg body "$BODY" '{body:$body}' \
  | gh api --input - \
      --method POST \
      "/repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments/$CID/replies"
```

## Retry 정책 {#retry-policy}

Step 7의 `isResolved=true` 재확인이 `false`를 돌려주는 경우의 정본 정책.
SKILL.md·다른 reference·Step 7 설명은 모두 이 앵커를 링크로 참조한다.

1. **1회 재시도**: `resolveReviewThread`는 idempotent하므로 다시 호출해도 안전하다.
   API 일시 지연이나 eventual consistency 지연은 대부분 1회 재조회로 수렴한다.
2. **재시도 후에도 false**: 즉시 사용자에게 보고. 자동 재시도를 반복하지 않는다.
   가능한 원인 — 권한 부족 (`viewerCanResolve=false`), bot 사용자 제한, 조직 정책.
3. **수동 확인 요청**: 사용자에게 thread URL을 공유하고, 브라우저에서 직접 resolve 또는
   권한 재설정을 진행하도록 안내.

절대 무한 retry 루프를 돌리지 않는다. API 호출 비용과 rate limit 문제를 유발한다.

## 에지 케이스

| 상황 | 대응 |
|------|------|
| `viewerCanReply == false` | 답글 권한 없음. 수집 단계에서 미리 필드를 체크하거나, mutation 실패 시 NOTICE 답글을 대신 issue comment로 남긴다. |
| `viewerCanResolve == false` | resolve 권한 없음. 답글만 남기고 사용자에게 수동 resolve 요청. |
| thread가 outdated (`isOutdated=true`)인데 unresolved | 답글 + resolve는 그대로 가능. Step 2에서 `STALE_REVIEW`로 분류했다면 그 사유를 답글에 남긴다. |
| 동일 thread에 답글을 여러 개 달아야 함 | 모두 `addPullRequestReviewThreadReply`로 순차 호출 후 최종 resolve. |

## 체크리스트

- [ ] `thread.id`를 Step 1에서 정확히 수집했는가 (Step 6 mutation 입력).
- [ ] 답글 본문을 `mktemp` 기반 임시 파일에 작성했는가 (`/tmp/reply.md` 같은 고정 경로 미사용).
- [ ] `addPullRequestReviewThreadReply` 응답의 `comment.id`를 기록했는가 (추적 용도).
- [ ] `resolveReviewThread` 응답의 `thread.isResolved=true`를 1차 확인했는가.
- [ ] Step 7 재조회에서 동일하게 `isResolved=true`를 확인했는가.
- [ ] retry 1회 후에도 false이면 사용자 보고로 종료했는가.
