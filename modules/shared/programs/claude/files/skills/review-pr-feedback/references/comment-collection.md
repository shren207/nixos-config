# PR 코멘트 수집 플레이북

`review-pr-feedback` 스킬 Step 1의 정본. GraphQL `reviewThreads`를 primary로,
PR 일반 코멘트·리뷰 요약은 REST 보조로 수집한다.

## 수집 대상 매트릭스

| 코멘트 유형 | primary 소스 | resolve 개념 | 수집 목적 |
|-------------|--------------|-------------|----------|
| Review thread 코멘트 (diff 위 코멘트) | GraphQL `reviewThreads` | 있음 (`isResolved`) | 답글 + resolve + 재확인 |
| PR 일반 코멘트 (conversation 탭) | REST `/issues/{pr}/comments` | 없음 | 답글만 |
| Review 요약 (approve / request changes / comment) | REST `/pulls/{pr}/reviews` | 없음 | 맥락 파악 (actionable 추출은 선택) |

`isResolved` 필드는 REST `pulls/{pr}/comments` 응답에 없다. resolved 상태를 알려면 GraphQL이 필수다.
REST도 각 엔드포인트 조합으로 같은 수집이 가능하지만, 이 스킬은 단순성 때문에 위 분담을 기본으로 둔다.

## GraphQL reviewThreads 쿼리 (기본 템플릿)

```bash
# 환경 변수에 PR 정보를 넣어둔다.
OWNER="greenheadHQ"
REPO="nixos-config"
PR_NUMBER=399

gh api graphql \
  -f owner="$OWNER" -f repo="$REPO" -F pr="$PR_NUMBER" -f cursor="" \
  -f query='
    query($owner: String!, $repo: String!, $pr: Int!, $cursor: String) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $pr) {
          reviewThreads(first: 50, after: $cursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              isResolved
              isOutdated
              path
              line
              comments(first: 20) {
                nodes {
                  id
                  author { login }
                  body
                  createdAt
                }
              }
            }
          }
        }
      }
    }'
```

Pagination은 `pageInfo.hasNextPage == true`인 동안 `$cursor`를 `endCursor`로 갱신하여 반복한다.

## actionable set 정의

1. **`isResolved == false`** 인 thread를 actionable로 간주한다.
2. **`isOutdated == true`** 인 thread도 수집은 한다. actionable 여부는 Step 2 분류에서 판단한다.
   - outdated이지만 유효한 지적 → `STALE_REVIEW`로 분류해 답글만 남기고 resolve.
   - outdated이면서 이미 반영된 내용 → `STALE_REVIEW` + 반영 참조 링크 답글 후 resolve.
3. `isResolved == true` thread는 기본적으로 제외한다. 재확인이 필요하면 별도로 조회.

## PR 일반 코멘트 수집 (REST 보조)

```bash
# conversation 탭의 일반 코멘트
gh api --paginate "/repos/$OWNER/$REPO/issues/$PR_NUMBER/comments"

# review 요약 (approve/request-changes/comment)
gh api --paginate "/repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews"
```

- Issue comment에는 `id`, `user.login`, `body`만 본다.
- Review summary의 `body`가 비어 있지 않다면 내용 검토 후 actionable 추출.

## 결과 정리 의무

수집한 후 다음 축으로 정렬해 Step 2로 넘긴다.

| 축 | 이유 |
|----|------|
| 파일별 | 관련 코드 근처 코멘트를 한 번에 검토 |
| 리뷰어별 | CodeRabbit / 인간 / 다른 AI 리뷰어의 패턴을 파악 |
| `thread.id` 보관 | Step 6의 `addPullRequestReviewThreadReply` / `resolveReviewThread` mutation 입력 |
| `comment.id` 보관 | 개별 코멘트 단위로 reply하려는 경우 REST 엔드포인트에 필요 |

## 자주 묻는 구분

- **Issue ≠ Pull Request 코멘트가 별개인가?** 아니다. GitHub 내부적으로 모든 PR은 Issue이기도 하므로 `/issues/{pr}/comments`가 PR 본문 아래 일반 코멘트를 돌려준다. 다만 review thread 코멘트는 `/pulls/{pr}/comments`로 들어오며, 둘은 서로 다른 스레드이다.
- **왜 GraphQL-first인가?** `isResolved` 같은 review thread state를 REST는 주지 않는다. GraphQL 한 쿼리로 id·resolved·outdated·path·line·comments를 모두 받으므로 수집 단계에서 불필요한 왕복을 줄인다.
- **REST로도 다 되나?** 같은 데이터를 REST로도 구할 수 있지만, 여러 엔드포인트를 조합해야 하고 `isResolved`가 없다. 이 스킬은 단순성 때문에 REST 보조를 유지한다.

## Step 2로 넘기기 전 체크리스트

- [ ] `pageInfo.hasNextPage`가 false가 될 때까지 모든 페이지 수집.
- [ ] 각 thread의 `id`, `isResolved`, `isOutdated`, `path`, `line`, 최신 `comment.body`·`author.login` 보관.
- [ ] PR 일반 코멘트와 review summary 본문도 함께 보관 (actionable 판단에 필요).
- [ ] resolved thread 제외 (또는 별도 버킷으로 분리).
