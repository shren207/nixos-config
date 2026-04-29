# PRD: Issue 600 Pinning Guardrails Closeout

## Document Status
- Status: In Progress
- File Mode: Single
- Current Phase: Phase 1
- Last Updated: 2026-04-29
- PRD File: `.claude/prds/prd-issue-600-pinning-guardrails.md`
- Purpose: Living PRD for finishing issue 600 closeout after the initial implementation and repeated audit fixes. Use this as the source of truth for the remaining long-running work.

## Problem
Issue 600 expands LLM pinning guardrails beyond commit messages into staged content and GitHub PR/issue bodies. The implementation also uncovered Codex runtime risks: Stop hook file descriptor exhaustion and Skill context budget warnings during audit subprocesses. The branch now has substantial implementation, but it still needs closeout audits, full validation, activation decisions, and PR creation.

## Goals
- G-1: Finish pinning guardrails across commit messages, staged added lines, PR bodies, and issue bodies.
- G-2: Keep local hooks warn-only while making GitHub body checks hard-fail on findings.
- G-3: Preserve safe exceptions for GitHub URLs, `owner/repo#N`, leading closing-keyword lines, and explicit allowlist markers with meaningful reasons.
- G-4: Keep Codex audit subprocesses isolated enough to avoid Skill context budget warnings and project/user/plugin tool-surface leakage.
- G-5: Mitigate Codex Stop hook `Too many open files` failures for future macOS shells and verifier runs.
- G-6: Produce a PR against `main` only after remaining audits and validation are complete.

## Non-Goals
- NG-1: Supporting fork PR comment writes. Fork and missing-head PRs should still be scanned and hard-fail on findings, but comment writes are skipped.
- NG-2: Rewriting historical issue/PR bodies that already exist.
- NG-3: Running `nrs` as a hidden side effect without an explicit closeout decision.

## Success Criteria
- SC-1: `tests/test-pinning-rules.sh` passes and covers the known edge cases found by audits.
- SC-2: GitHub workflow loads trusted rules, hard-fails body findings, avoids PR checkout, and skips comment writes for fork or missing-head PRs.
- SC-3: Stop hook FD mitigation is represented in config and verified by `scripts/ai/verify-ai-compat.sh`.
- SC-4: `codex exec` audit guidance uses scratch cwd + scratch `CODEX_HOME` + `--ignore-user-config --disable plugins --ephemeral` with explicit model/effort pins.
- SC-5: Remaining platform, side-effect, docs, and review-implementation passes have no unresolved high/medium findings.
- SC-6: Full validation suite is recorded with pass/fail evidence before PR creation.

## Discovery Summary
- Reviewed: `.claude/plans/issue-600-pinning-hook-scope.md`, `.github/workflows/pinning-check.yml`, `lefthook.yml`, `flake.nix`, `scripts/ai/*pinning*.sh`, `scripts/ai/lib/pinning-rules.json`, Codex hook fixtures, run-da/parallel-audit/codex-fan-out docs, shell nofile config, and audit subprocess outputs.
- Current system: commit-message and pre-commit hooks are local warn-only; GitHub Actions body check hard-fails; pre-push runs tomlkit fixture wrapper, pinning tests, and `nix flake check --no-build --all-systems`.
- Completed audit evidence: security/API audit SAFE; performance/deps audit SAFE after batching staged scan and isolating subprocess home; tests/edge-case audit iteratively fixed fork/missing-head PRs, closing refs, plus-prefixed staged lines, and live fixture docs.
- Review-implementation pass: core requirements are satisfied or intentionally refined, with closeout still `partial` until remaining audit bundles and full validation complete. One validation issue was found and fixed: ShellCheck needed an explicit `SC2034` suppression for `PINNING_WARN_PREFIX`, which is read by the sourced common script.
- Confidence / gaps: platform/macOS+NixOS audit, adjacent side-effect audit, docs consistency audit, final validation suite, and PR creation are still pending.

## Requirements
### Functional Requirements
- FR-1: Shared rule metadata lives in `scripts/ai/lib/pinning-rules.json`.
- FR-2: `scripts/ai/commit-msg-pinning.sh` preserves comment stripping, Revert partial-hash skip, warn-only behavior, and missing-`jq` fallback.
- FR-3: `scripts/ai/pre-commit-pinning.sh` scans staged added lines only, respects path excludes, handles header-like added content, and remains warn-only.
- FR-4: `.github/workflows/pinning-check.yml` scans PR/issue bodies using trusted rules loaded via GitHub API.
- FR-5: GitHub workflow hard-fails findings, updates only its own bot comment when possible, resolves stale comments, and avoids fork comment writes.
- FR-6: Templates and durable skill docs avoid non-closing same-repo bare references or document allowlist usage.
- FR-7: Codex subprocess documentation prevents Skill context budget warnings in audit/review fan-out paths.
- FR-8: Stop hook FD mitigation is applied in Darwin shell config and verifier self-heal logic.

### Non-Functional Requirements
- NFR-1: Local checks must not block commits for pinning findings.
- NFR-2: Pre-commit scanning must be linear enough for large staged diffs.
- NFR-3: Workflow permissions stay minimal: no `pull-requests: write` unless a future implementation proves it is needed.
- NFR-4: Validation should be reproducible from a fresh shell/devShell.

## Assumptions
- A-1: `ruby`, `jq`, `node`, `shellcheck`, and `coreutils` are available through devShell as configured.
- A-2: Existing current-session Codex parent process cannot have its FD limit raised retroactively; mitigation targets future shells and child commands.
- A-3: PRD files under `.claude/prds/` may be ignored locally; the file still serves as the handoff source in this worktree.

## Risks / Edge Cases
- R-1: Diff parser edge cases around added lines beginning with plus signs.
- R-2: GitHub fork payloads with `pull_request.head.repo == null`.
- R-3: Closing-keyword allowlist accidentally scrubbing prose such as `does not fix #N`.
- R-4: Audit subprocesses reloading user/global skills and triggering context budget warnings.
- R-5: Existing Codex session Stop hooks still inheriting low nofile limits until a new shell/session is started.

## Execution Rules
- Work through phases in order unless a new high-severity finding requires revising this PRD first.
- Do not spawn native subagents in this current session while FD exhaustion remains a risk; use isolated serial `codex exec` if independent review is needed.
- Use `apply_patch` for manual tracked edits.
- Keep PR body and commit messages compliant with the new pinning policy.
- At phase end, update this PRD with completed checks, new findings, and validation evidence.

## Phase Index
| Phase | Status | Objective | Validation Focus |
|---|---|---|---|
| Phase 1: Stabilize Current Implementation | In Progress | Finish review-implementation mapping and close any immediate findings from the current branch. | Focused tests, shellcheck, workflow syntax |
| Phase 2: Finish Independent Audits | Not Started | Complete platform, adjacent side-effect, docs consistency, and any remaining review/audit passes. | SAFE/FINDINGS outputs with fixes committed |
| Phase 3: Full Validation And PR | Not Started | Run final validation suite, decide `nrs`, push branch, and create PR. | Full command transcript and PR creation result |

## Phase Plan
### Phase 1: Stabilize Current Implementation
Objective: make the current implementation internally consistent before broader closeout.

#### Phase Discovery Gate
- [x] Read `.claude/plans/issue-600-pinning-hook-scope.md`.
- [x] Read `review-implementation` workflow.
- [x] Inspect changed files from `main...HEAD`.
- [x] Re-run focused pinning tests after latest parser/workflow fixes.

#### Implementation Checklist
- [x] Fix fork PR body scanning while skipping comment writes.
- [x] Treat missing fork head repo as untrusted.
- [x] Anchor closing refs to leading closing-keyword lines.
- [x] Batch staged-line pre-commit scanning.
- [x] Preserve staged lines beginning with `++` and `++ b/`.
- [x] Align live hook fixture docs with hard-fail behavior.
- [x] Complete review-implementation 9-pass notes after the latest commits.

#### Validation Checklist
- [x] `shellcheck -S warning scripts/ai/pre-commit-pinning.sh tests/test-pinning-rules.sh`
- [x] `bash tests/test-pinning-rules.sh`
- [x] `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/pinning-check.yml")'`
- [x] `jq . scripts/ai/lib/pinning-rules.json >/dev/null`
- [x] `shellcheck -S warning scripts/ai/pre-commit-pinning.sh scripts/ai/commit-msg-pinning.sh tests/test-pinning-rules.sh tests/test-codex-hook-fixtures.sh`

#### Exit Criteria
- [x] No unresolved review-implementation finding above low.
- [ ] Working tree clean except PRD updates.
- [ ] Phase 2 audit prompts are still accurate.

#### Review-Implementation 9-Pass Notes
- Requirements coverage: `partial`; FR-1 through FR-8 have implementation evidence, but Phase 2/3 closeout remains.
- Correctness: current focused tests cover fork/missing-head PRs, closing refs, partial hashes, allowlist markers, staged added-line only scanning, large staged diff, and header-like plus-prefixed lines.
- Integration: local hooks, pre-push tests, GitHub workflow, devShell deps, Codex hook fixtures, and Codex subprocess docs are integrated without a known high/medium conflict.
- Simplicity: current solution keeps rule metadata centralized and avoids a new service or checkout-based workflow.
- Cleanup: no known temporary implementation files remain; `.claude/plans/` remains an ignored planning artifact.
- Security/privacy: workflow reads trusted rules via GitHub API and avoids fork comment writes; no new secret handling path was added.
- Performance: pre-commit scan is batched through one Ruby process after Bash diff extraction.
- Validation: focused checks passed; broad Nix/live/full pre-push validation remains Phase 3.
- Documentation/operability: subprocess isolation and live hook fixture docs are updated; docs consistency audit remains Phase 2.

### Phase 2: Finish Independent Audits
Objective: finish the audit matrix without continuing an unbounded same-scope loop.

#### Phase Discovery Gate
- [ ] Read latest `git log --oneline -20`.
- [ ] Confirm no uncommitted code/test changes.
- [ ] Reuse scratch cwd + scratch `CODEX_HOME` + `--disable plugins` audit command pattern.

#### Implementation Checklist
- [ ] Run macOS/NixOS platform audit.
- [ ] Run adjacent side-effect/regression audit.
- [ ] Run docs/consistency audit.
- [ ] If any finding appears, fix it with a narrow commit and rerun that audit once.
- [ ] Record any residual low-risk/deferred item in this PRD.

#### Validation Checklist
- [ ] Audit subprocess stderr has no Skill context budget warning.
- [ ] Each audit returns `SAFE` or has findings committed and rechecked.

#### Exit Criteria
- [ ] All remaining audit categories are SAFE or explicitly deferred with rationale.

### Phase 3: Full Validation And PR
Objective: produce final evidence and open the PR.

#### Phase Discovery Gate
- [ ] Confirm whether to run `nrs`; it is only needed if applying Home Manager activation outputs now.
- [ ] Confirm `gh auth status` or GitHub connector availability.

#### Implementation Checklist
- [ ] Run final validation suite:
  - [ ] `git status --short`
  - [ ] `jq . scripts/ai/lib/pinning-rules.json >/dev/null`
  - [ ] `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/pinning-check.yml")'`
  - [ ] `nixfmt --check flake.nix`
  - [ ] `shellcheck -S warning scripts/ai/lib/tomlkit-bootstrap.sh scripts/ai/verify-ai-compat.sh tests/run-tomlkit-pre-push-tests.sh tests/run-shell-script-tests.sh tests/test-codex-hook-fixtures.sh tests/test-pinning-rules.sh scripts/ai/pre-commit-pinning.sh scripts/ai/commit-msg-pinning.sh`
  - [ ] `bash tests/test-pinning-rules.sh`
  - [ ] `bash tests/run-tomlkit-pre-push-tests.sh`
  - [ ] `bash tests/test-codex-hook-fixtures.sh --live`
  - [ ] `./scripts/ai/verify-ai-compat.sh`
  - [ ] `nix flake check --no-build --all-systems`
  - [ ] `lefthook run pre-push`
- [ ] Run final review-implementation summary.
- [ ] Push `issue/600`.
- [ ] Create PR against `main` with compliant body text and the approved closing keyword line for `greenheadHQ/nixos-config#600`.

#### Exit Criteria
- [ ] Validation evidence recorded.
- [ ] PR URL recorded.
- [ ] No uncommitted implementation changes remain.

## Final Multi-Pass Review After All Phases
Use `modules/shared/programs/claude/files/skills/prd/references/multi-pass-review.md`.

Required closeout passes:
- [ ] Requirements coverage
- [ ] Correctness and edge cases
- [ ] Integration and ownership
- [ ] Simplicity
- [ ] Cleanup
- [ ] Security/privacy
- [ ] Performance
- [ ] Validation adequacy
- [ ] Documentation/operability
- [ ] PRD sync and handoff quality

## Open Questions
- OQ-1: Whether to run `nrs` during this branch closeout or leave activation to the user after merge.

## Change Log
- 2026-04-29: Initial living PRD created from current issue 600 implementation state, audit evidence, and remaining closeout work.
