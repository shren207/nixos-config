#!/usr/bin/env bash
# tests/test-pinning-rules.sh
# pinning-rules.json + commit-msg/pre-commit/GitHub Actions matcher regression tests.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RULES="$REPO_ROOT/scripts/ai/lib/pinning-rules.json"
COMMIT_HOOK="$REPO_ROOT/scripts/ai/commit-msg-pinning.sh"
PRE_COMMIT_HOOK="$REPO_ROOT/scripts/ai/pre-commit-pinning.sh"
WORKFLOW="$REPO_ROOT/.github/workflows/pinning-check.yml"
TMP_LIST="$(mktemp "${TMPDIR:-/tmp}/pinning-rules-tests.XXXXXX")"

cleanup() {
  local path
  if [ -f "$TMP_LIST" ]; then
    while IFS= read -r path; do
      [ -n "$path" ] && rm -rf "$path"
    done < "$TMP_LIST"
    rm -f "$TMP_LIST"
  fi
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2" desc="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$desc: expected output to contain [$needle], got: $haystack"
}

assert_not_contains() {
  local haystack="$1" needle="$2" desc="$3"
  [[ "$haystack" != *"$needle"* ]] || fail "$desc: expected output not to contain [$needle], got: $haystack"
}

new_tmp_dir() {
  local dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/pinning-rules.XXXXXX")"
  printf '%s\n' "$dir" >> "$TMP_LIST"
  printf '%s\n' "$dir"
}

run_commit_hook_text() {
  local text="$1" msg
  msg="$(mktemp "${TMPDIR:-/tmp}/pinning-commit-msg.XXXXXX")"
  printf '%s\n' "$msg" >> "$TMP_LIST"
  printf '%s\n' "$text" > "$msg"
  bash "$COMMIT_HOOK" "$msg" 2>&1
}

setup_git_fixture() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init >/dev/null 2>&1
  git -C "$repo" branch -M main >/dev/null 2>&1
  git -C "$repo" config user.name "Pinning Test"
  git -C "$repo" config user.email "pinning@example.invalid"
  git -C "$repo" config core.hooksPath /dev/null
  printf 'base\n' > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -m "initial" >/dev/null 2>&1
}

run_pre_commit_fixture() {
  local repo="$1"
  (cd "$repo" && bash "$PRE_COMMIT_HOOK") 2>&1
}

extract_workflow_script() {
  ruby -e '
    require "yaml"
    workflow = YAML.load_file(ARGV[0])
    step = workflow["jobs"]["check-pinning"]["steps"].find { |item|
      item["uses"].to_s.include?("actions/github-script")
    }
    puts step["with"]["script"]
  ' "$WORKFLOW"
}

test_json_schema() {
  jq -e '
    .schema_version == 1
    and (.rules | length == 5)
    and ([.rules[].id] | index("partial_hash") != null)
    and (.markers.min_reason_length >= 10)
    and (.allowlist.closing_refs.grep_ere | length > 0)
  ' "$RULES" >/dev/null
}

test_commit_msg_regression() {
  local out
  out="$(run_commit_hook_text 'feat: DA round 2 MAINTAINABILITY-1 deadbeef 반영')"
  assert_contains "$out" "라운드 카운터" "round counter regression"
  assert_contains "$out" "DA finding ID" "finding id regression"
  assert_contains "$out" "DA/검토 키워드" "DA keyword regression"
  assert_contains "$out" "Partial commit hash" "partial hash regression"

  out="$(run_commit_hook_text $'# DA round 2 DESIGN-1 deadbeef\nfeat: normal subject')"
  assert_not_contains "$out" "DA/검토 키워드" "commit-msg must strip comment lines"
  assert_not_contains "$out" "Partial commit hash" "commit-msg must strip comment hash lines"

  out="$(run_commit_hook_text $'Revert "example"\n\nThis reverts commit deadbeef.')"
  assert_not_contains "$out" "Partial commit hash" "revert partial-hash skip"

  out="$(run_commit_hook_text 'docs: 0123456789012345678901234567890123456789 1234567 refs')"
  assert_not_contains "$out" "Partial commit hash" "full SHA and pure numeric should not warn"

  local large
  large="$(
    printf 'feat: DA round 2\n'
    for _ in $(seq 1 12000); do
      printf 'ordinary body line\n'
    done
  )"
  out="$(run_commit_hook_text "$large")"
  assert_contains "$out" "라운드 카운터" "large commit message must still warn"

  out="$(PINNING_JQ_BIN=/definitely/missing/jq run_commit_hook_text 'feat: DA round 2')"
  assert_contains "$out" "jq 미설치" "missing jq fallback"
}

test_pre_commit_scanner() {
  local repo out
  repo="$(new_tmp_dir)"
  setup_git_fixture "$repo"

  mkdir -p "$repo/src"
  printf '%s\n' '# DA for_pr DESIGN-1 반영 deadbeef' > "$repo/src/pinned.sh"
  git -C "$repo" add src/pinned.sh
  out="$(run_pre_commit_fixture "$repo")"
  assert_contains "$out" "src/pinned.sh:1" "pre-commit should report staged added line"
  assert_contains "$out" "DA/검토 키워드" "pre-commit should report DA keyword"

  git -C "$repo" reset --hard HEAD >/dev/null 2>&1
  mkdir -p "$repo/tests/fixtures"
  printf '%s\n' '# DA for_pr DESIGN-1 반영 deadbeef' > "$repo/tests/fixtures/pinned.txt"
  git -C "$repo" add tests/fixtures/pinned.txt
  out="$(run_pre_commit_fixture "$repo")"
  [[ -z "$out" ]] || fail "path exclude should suppress fixture findings, got: $out"

  git -C "$repo" reset --hard HEAD >/dev/null 2>&1
  mkdir -p "$repo/src"
  cat > "$repo/src/allowed.md" <<'EOF'
ref: https://github.com/karakeep-app/karakeep/issues/1977
ref: karakeep-app/karakeep#1977
Closes #600
same repo #600 <!-- pinning-allow: intentional local reference for test -->
<!-- pinning-allow-next-line: intentional local reference for test -->
next line #601
EOF
  git -C "$repo" add src/allowed.md
  out="$(run_pre_commit_fixture "$repo")"
  [[ -z "$out" ]] || fail "allowlists and valid markers should suppress findings, got: $out"

  git -C "$repo" reset --hard HEAD >/dev/null 2>&1
  mkdir -p "$repo/src"
  printf '%s\n' 'This does not fix #600' > "$repo/src/not-closing.md"
  git -C "$repo" add src/not-closing.md
  out="$(run_pre_commit_fixture "$repo")"
  assert_contains "$out" "bare 이슈/PR 번호" "non-leading fix prose must not be treated as closing ref"

  git -C "$repo" reset --hard HEAD >/dev/null 2>&1
  mkdir -p "$repo/src"
  printf '%s\n' 'same repo #600 <!-- pinning-allow: short -->' > "$repo/src/not-allowed.md"
  git -C "$repo" add src/not-allowed.md
  out="$(run_pre_commit_fixture "$repo")"
  assert_contains "$out" "bare 이슈/PR 번호" "short allowlist reason should not suppress"

  git -C "$repo" reset --hard HEAD >/dev/null 2>&1
  mkdir -p "$repo/src"
  printf '%s\n' '# DA for_pr DESIGN-1 already present' > "$repo/src/baseline.sh"
  git -C "$repo" add src/baseline.sh
  git -C "$repo" commit -m "add baseline" >/dev/null 2>&1
  printf '%s\n' 'ordinary new line' >> "$repo/src/baseline.sh"
  git -C "$repo" add src/baseline.sh
  out="$(run_pre_commit_fixture "$repo")"
  [[ -z "$out" ]] || fail "pre-commit should scan added lines only, got: $out"

  git -C "$repo" reset --hard HEAD >/dev/null 2>&1
  mkdir -p "$repo/src"
  {
    for i in $(seq 1 8000); do
      printf 'ordinary staged line %s\n' "$i"
    done
    printf 'large diff keeps warning for deadbeef\n'
  } > "$repo/src/large.md"
  git -C "$repo" add src/large.md
  out="$(run_pre_commit_fixture "$repo")"
  assert_contains "$out" "src/large.md:8001" "large pre-commit staged diff should still report findings"
  assert_contains "$out" "Partial commit hash" "large pre-commit staged diff should still scan rules"
}

test_workflow_static_and_js() {
  ruby -e 'require "yaml"; YAML.load_file(ARGV[0])' "$WORKFLOW"
  grep -q 'contents: read' "$WORKFLOW" || fail "workflow missing contents: read"
  grep -q 'issues: write' "$WORKFLOW" || fail "workflow missing issues: write"
  ! grep -q 'pull-requests: write' "$WORKFLOW" || fail "workflow must not request pull-requests: write"
  grep -Eq 'uses: actions/github-script@[0-9a-f]{40}' "$WORKFLOW" || fail "workflow action must be pinned to full commit SHA"
  grep -q 'pull.base.sha' "$WORKFLOW" || fail "workflow must load PR rules from base sha"
  grep -q 'getContent' "$WORKFLOW" || fail "workflow must load rules through GitHub API"
  ! grep -q 'actions/checkout' "$WORKFLOW" || fail "workflow must not read rules from PR checkout"

  if ! command -v node >/dev/null 2>&1; then
    fail "node is required for workflow JavaScript validation"
  fi

  local script_file wrapped_file
  script_file="$(mktemp "${TMPDIR:-/tmp}/pinning-workflow-script.XXXXXX.js")"
  wrapped_file="$(mktemp "${TMPDIR:-/tmp}/pinning-workflow-wrapped.XXXXXX.js")"
  printf '%s\n' "$script_file" "$wrapped_file" >> "$TMP_LIST"
  extract_workflow_script > "$script_file"
  grep -q 'function loadRules' "$script_file" || fail "workflow JS missing loadRules boundary"
  grep -q 'function scanText' "$script_file" || fail "workflow JS missing scanText boundary"
  grep -q 'function isSameLineAllowed' "$script_file" || fail "workflow JS missing allowlist boundary"
  grep -q 'function renderComment' "$script_file" || fail "workflow JS missing renderComment boundary"
  grep -q 'function renderResolvedComment' "$script_file" || fail "workflow JS missing resolved comment boundary"
  grep -q 'async function findPreviousComment' "$script_file" || fail "workflow JS missing previous comment lookup boundary"
  grep -q 'async function upsertComment' "$script_file" || fail "workflow JS missing upsertComment boundary"
  grep -q 'async function resolveComment' "$script_file" || fail "workflow JS missing resolveComment boundary"
  grep -Fq "github-actions[bot]" "$script_file" || fail "workflow must update only its own bot comment"
  grep -q 'github.paginate.iterator' "$script_file" || fail "workflow must stop comment pagination after finding marker"
  grep -q 'await resolveComment(target, renderResolvedComment(target, rules));' "$script_file" || fail "workflow must resolve stale failure comments"
  grep -q 'bash ./tests/run-tomlkit-pre-push-tests.sh' "$REPO_ROOT/lefthook.yml" \
    || fail "pre-push tomlkit fixture suites must share one runtime wrapper"
  grep -q 'test -f ./tests/test-pinning-rules.sh && bash ./tests/test-pinning-rules.sh' "$REPO_ROOT/lefthook.yml" \
    || fail "pre-push pinning-rules must fail when the test script is missing"
  {
    printf '(async function __pinningWorkflowCheck(){\n'
    cat "$script_file"
    printf '\n});\n'
  } > "$wrapped_file"
  node --check "$wrapped_file" >/dev/null

  node - "$RULES" <<'NODE'
const fs = require('fs');
const rules = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
function scrub(line) {
  return line
    .replace(new RegExp(rules.allowlist.urls.js_regex, 'g'), '')
    .replace(new RegExp(rules.allowlist.cross_repo_refs.js_regex, 'g'), '')
    .replace(new RegExp(rules.allowlist.closing_refs.js_regex, 'g'), '');
}
function partialAllowed(match, rule) {
  const filter = rule.post_filters.find((item) => item.type === 'partial_hash');
  let token = match;
  if (filter.strip_backticks) token = token.replace(/`/g, '');
  if (filter.exclude_full_sha_length && token.length === filter.exclude_full_sha_length) return false;
  if (token.length < filter.min_length || token.length > filter.max_length) return false;
  if (filter.require_hex_alpha && !/[a-f]/.test(token)) return false;
  return true;
}
const partial = rules.rules.find((rule) => rule.id === 'partial_hash');
const partialRe = new RegExp(partial.matchers.js_regex);
if (!partialAllowed('deadbee', partial)) throw new Error('short hex hash should match');
if (partialAllowed('1234567', partial)) throw new Error('pure numeric should not match');
if (partialAllowed('0123456789012345678901234567890123456789', partial)) throw new Error('full SHA should not match');
const multiCandidate = '1234567 deadbee';
let foundPartial = null;
for (const match of multiCandidate.matchAll(new RegExp(partial.matchers.js_regex, 'g'))) {
  if (partialAllowed(match[0], partial)) {
    foundPartial = match[0];
    break;
  }
}
if (foundPartial !== 'deadbee') throw new Error('partial hash scan should continue after rejected candidates');
const bare = rules.rules.find((rule) => rule.id === 'bare_issue_ref');
const bareRe = new RegExp(bare.matchers.js_regex);
if (bareRe.test(scrub('Closes #600'))) throw new Error('closing refs should be scrubbed');
if (bareRe.test(scrub('- Fixes #600'))) throw new Error('markdown list closing refs should be scrubbed');
if (bareRe.test(scrub('see owner/repo#600'))) throw new Error('cross-repo refs should be scrubbed');
if (!bareRe.test(scrub('see #600'))) throw new Error('bare same-repo ref should match');
if (!bareRe.test(scrub('This does not fix #600'))) throw new Error('non-leading fix prose should not be scrubbed');
NODE

  node - "$script_file" "$RULES" <<'NODE'
const fs = require('fs');
const vm = require('vm');

const script = fs.readFileSync(process.argv[2], 'utf8');
const rules = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));

async function runForkBody(body) {
  let commentWriteCount = 0;
  let requestedRef = null;
  const context = {
    repo: { owner: 'owner', repo: 'repo' },
    payload: {
      pull_request: {
        number: 123,
        body,
        head: { repo: { full_name: 'fork/repo' } },
        base: { sha: 'trusted-base-sha', repo: { full_name: 'owner/repo' } },
      },
    },
  };
  const core = {
    failed: null,
    infos: [],
    warnings: [],
    info(message) { this.infos.push(message); },
    warning(message) { this.warnings.push(message); },
    setFailed(message) { this.failed = message; },
  };
  const github = {
    rest: {
      repos: {
        getContent: async ({ ref }) => {
          requestedRef = ref;
          return {
            data: {
              type: 'file',
              encoding: 'base64',
              content: Buffer.from(JSON.stringify(rules), 'utf8').toString('base64'),
            },
          };
        },
      },
      issues: {
        updateComment: async () => { commentWriteCount += 1; },
        createComment: async () => { commentWriteCount += 1; },
        listComments: async () => ({ data: [] }),
      },
    },
    paginate: {
      iterator: async function* iterator() {
        yield { data: [] };
      },
    },
  };

  await vm.runInNewContext(`(async () => {\n${script}\n})()`, {
    Buffer,
    context,
    core,
    github,
  });

  return { commentWriteCount, core, requestedRef };
}

(async () => {
  let result = await runForkBody('DA round 2');
  if (result.requestedRef !== 'trusted-base-sha') {
    throw new Error(`fork PR rules must load from trusted base sha, got ${result.requestedRef}`);
  }
  if (!result.core.failed || !result.core.failed.includes('Pinning findings:')) {
    throw new Error(`fork PR body findings must hard-fail, got ${result.core.failed}`);
  }
  if (result.commentWriteCount !== 0) {
    throw new Error(`fork PR must not write comments, wrote ${result.commentWriteCount}`);
  }

  result = await runForkBody('This does not fix #600');
  if (!result.core.failed || !result.core.failed.includes('Pinning findings:')) {
    throw new Error(`non-leading fix prose must hard-fail, got ${result.core.failed}`);
  }

  result = await runForkBody('Closes #600');
  if (result.core.failed) {
    throw new Error(`leading closing ref should be allowed, got ${result.core.failed}`);
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
NODE
}

test_json_schema
test_commit_msg_regression
test_pre_commit_scanner
test_workflow_static_and_js

echo "All pinning rule tests passed."
