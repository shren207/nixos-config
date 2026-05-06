# Automatic run-da preflight gate

Automatic `plan-with-questions` call sites may apply the `run-da` Review Intensity checklist immediately before invoking `/run-da`. This is a caller-side gate for automatic workflow steps only; it is not a free-form exemption from review.

## 적용 call sites

- `for_action` Step 5: plan-mode review for the `.claude/plans/<slug>.md` plan.
- `for_prd` Step 5: plan-mode review for PRD draft/context.
- Post-Implementation Step 3: code review for the implementation diff.

Incidental guidance that merely mentions `/run-da` does not inherit this gate.

## SSOT

The gate reuses `run-da` policy without copying it:

- Checklist procedure: [`../../run-da/references/intensity-procedure.md`](../../run-da/references/intensity-procedure.md)
- Rule table: [`../../run-da/references/intensity-rules.md`](../../run-da/references/intensity-rules.md)
- Question-tool fallback: [`../../run-da/references/arbiter-scaling.md`](../../run-da/references/arbiter-scaling.md#질문-도구-미지원-대응)

If these references change, this gate follows them. Call-site docs must link here instead of duplicating the gate.

## Procedure

1. Collect the same input that `/run-da` would use:
   - plan-mode: plan summary and changed-file list.
   - PRD mode: PRD draft/context, candidate phase structure, and changed-file list.
   - post-implementation: `git diff --stat main...HEAD` and, when needed, actual diff facts.
2. Apply the Review Intensity checklist exactly as defined by `run-da`.
3. Record the full checklist table and first-match verdict in the active plan/PRD context or conversation state.
4. If the verdict is `SKIP`, ask the user with the question tool before skipping.
5. If the verdict is `LITE` or `FULL`, invoke `/run-da` with the checklist handoff and continue with that intensity.

## SKIP outcomes

| Condition | Action | Durable state |
|-----------|--------|---------------|
| User approves SKIP | Do not invoke `/run-da`; treat the automatic gate as completed. | `for_action` plan DA may record `DA State=SKIPPED`; post-implementation records the Step 3 outcome in `Change Log` / resume note, not in plan-mode `DA State`. |
| User rejects SKIP | Invoke `/run-da` with `SKIP rejected` handoff. `/run-da` must not ask the same SKIP question again; it enters the post-refusal escalation path. | Record escalation, not `SKIPPED`. |
| Question tool unavailable | Do not skip. Follow the `run-da` fallback policy, which escalates SKIP to LITE for this case. | Record escalation, not `SKIPPED`. |

## Handoff to `/run-da`

When the gate invokes `/run-da` after preflight, pass the checklist table and outcome as context. A valid handoff includes:

- mode (`for_plan` or `for_pr`)
- input summary used for the checklist
- all rule results with evidence
- final intensity verdict
- user approval state when the verdict was `SKIP`

If the handoff is missing, malformed, or based on stale input, `/run-da` reruns the checklist from current inputs and fail-closes according to its own procedure.
