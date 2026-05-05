# Phase 4: Validation Activation Closeout

Parent PRD: [PRD: Pinning SSOT Compatibility](../prd-pinning-ssot-compatibility.md)
Status: In Progress
Last Updated: 2026-05-05

## Objective

Validate the SSOT changes, activate them through `nrs`, run required post-implementation checks, and create the PR.

## Context From Master PRD
- Goals covered: G-4, G-5, G-6
- Success Criteria: SC-4, SC-5, SC-6
- Requirements covered: FR-9, FR-10, NFR-2, NFR-4
- Key scenarios touched: all scenarios

## Phase Discovery Gate
Before code edits:
- [x] Confirm Phase 2 and Phase 3 are complete.
- [x] Read the final diff for all five scoped docs.
- [x] Read `pinning-patterns.sh` helper behavior.
- [x] Read relevant PreToolUse fixture test section.
- [x] Confirm master PRD assumptions still hold.

## Scope
### In Scope
- Scoped static guard checks.
- Preserved runtime example checks for `consulting-step.md`.
- Negative and positive hook smoke tests.
- Relevant fixture tests.
- `nrs` activation.
- Post-`nrs` `./scripts/ai/verify-ai-compat.sh`.
- Post-implementation review/audit/final checks and PR creation.

### Out of Scope
- New guard patterns or sanitizer behavior.
- Broad rewrite of unrelated validation docs.

## Implementation Checklist
- [x] Run helper-based generated durable-output checks on changed guidance sections.
- [x] Run zero-match checks for files expected to be fully clean.
- [x] Run an explicit preserved-example check for `consulting-step.md` runtime code blocks.
- [x] Run old-style generated durable-content deny smoke.
- [x] Run new-style generated durable-content pass smoke.
- [x] Run relevant `tests/test-codex-hook-fixtures.sh` PreToolUse behavioral tests.
- [x] Run `nrs`.
- [x] Run `./scripts/ai/verify-ai-compat.sh` immediately after `nrs`.
- [x] Run implementation commit.
- [ ] Run code review loop.
- [ ] Run parallel audit.
- [ ] Run final multi-pass review and review-implementation overlay.
- [ ] Apply review fixes and commit if needed.
- [ ] Create PR.

## Validation Strategy

Combine source static checks, direct hook behavior, deterministic fixtures, activation, and final review. Runtime examples in `consulting-step.md` are validated as preserved examples, not as generated durable-output guidance.

## Validation Checklist
- [x] Static helper check for generated durable-output guidance.
- [x] Explicit allowlist or targeted section check for preserved `consulting-step.md` runtime examples.
- [x] Old-style deny smoke returns deny JSON.
- [x] New-style pass smoke exits cleanly.
- [x] Relevant PreToolUse fixture tests pass.
- [x] `nrs` succeeds.
- [x] `./scripts/ai/verify-ai-compat.sh` succeeds after `nrs`.
- [ ] Code review loop reaches clear state or records accepted fixes.
- [ ] Parallel audit reaches clear state or records accepted fixes.
- [ ] Final multi-pass review and overlay complete.

## Exit Criteria
- [ ] All selected validation checks pass or gaps are recorded with reason.
- [ ] Deployed user-scope skill surface reflects source changes.
- [ ] PRD master and phase files are updated to Complete.
- [ ] PR is created or a blocker is documented.

## Phase-End Multi-Pass Review
- [ ] 1. Intent/coverage review.
- [ ] 2. Correctness review.
- [ ] 3. Simplicity review.
- [ ] 4. Code quality review.
- [ ] 5. Duplication/cleanup review.
- [ ] 6. Security/privacy review.
- [ ] 7. Performance/load review.
- [ ] 8. Validation review.
- [ ] 9. Future-phase review.
- [ ] 10. PRD sync review.

## Discoveries / Decisions
- Current post-implementation flow is steps 1-7 by default; the older issue handoff skip note is not applied unless the user explicitly narrows scope.
- Validation completed so far: static helper checks, consulting runtime example check, old-style deny smoke, new-style pass smoke, hook fixture tests, `nrs`, and `verify-ai-compat`.
- Review findings about stale result-output wording, PRD status drift, NFR wording ambiguity, guard-internal prose duplication, Baseline delimiter ambiguity, and legacy Baseline compatibility were incorporated.

## Phase Change Log
- 2026-05-05: Phase file created.
- 2026-05-05: Phase moved to In Progress after validation, activation, and implementation commit. Remaining: review loop clear, parallel audit, final multi-pass review, follow-up commit if needed, PR creation.
