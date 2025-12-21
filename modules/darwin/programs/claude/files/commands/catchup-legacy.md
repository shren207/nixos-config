---
description: Summarize all changes on the current git branch (working tree, staged, unpushed, and incoming from upstream).
argument-hint: [(all|local|incoming|unpushed)] [base-ref]
allowed-tools: |
  Bash(git fetch:*),
  Bash(git status:*),
  Bash(git rev-parse:*),
  Bash(git branch:*),
  Bash(git rev-list:*),
  Bash(git log:*),
  Bash(git diff:*)
---

# /catchup — branch change digest

You are a helpful assistant that prepares a concise, actionable "catch-up" report for the current repository.

## Inputs

- **scope** = "$1" (default: "all")
- **base_ref** = "$2" (default: the upstream tracking branch `@{upstream}`; if none, use `origin/<current-branch>`; if that fails, use `origin/main`)

## Context (gather facts first)

- Current branch: !`git branch --show-current`
- Fetch remote state (no merge): !`git fetch --prune --tags --all`
- Status (short): !`git status -sb`
- Upstream (may be unset): !`git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || echo "none"`
- Ahead/Behind vs base_ref (if exists): !`git rev-list --left-right --count ${2:-@{upstream}}...HEAD 2>/dev/null || echo "N/A"`

### Local changes

- Unstaged summary: !`git diff --stat`
- Staged summary: !`git diff --stat --cached`

### Commit deltas (use base_ref if provided)

- Unpushed commits: !`git log --oneline --decorate -n 30 ${2:-@{upstream}}..HEAD 2>/dev/null || echo "Unable to determine unpushed commits (no base_ref/upstream)"`
- Incoming commits: !`git log --oneline --decorate -n 30 HEAD..${2:-@{upstream}} 2>/dev/null || echo "Unable to determine incoming commits (no base_ref/upstream)"`

## Task

1. Resolve **base_ref** as described above using the gathered outputs.
2. Depending on **scope**:
   - **local**: Summarize only working tree/staged changes and list WIP files to review.
   - **unpushed**: Summarize commits in `base_ref..HEAD` with brief bullets (scope, modules touched).
   - **incoming**: Summarize commits in `HEAD..base_ref` and call out breaking changes or migrations.
   - **all** (default): Provide a compact sectioned report covering **Local changes**, **Unpushed**, **Incoming**, and an **Ahead/Behind** count.
3. If `CLAUDE.local.*.md` files exist in the current project directory, reference them to inform your decisions and provide contextually relevant insights.
4. After gathering all necessary information, produce a structured report in Korean using the following format:

## Current Work

(Briefly describe the active work based on recent commits, branch name, and context from CLAUDE.local.*.md files if available)

## Progress Summary

(Summarize what has been accomplished: unpushed commits, staged/unstaged changes, key milestones)

## Next Steps

(Provide a checklist of recommended actions: run tests, rebase/merge, resolve conflicts, push changes, etc. Suggest specific commands where applicable. Keep output concise—if lists exceed ~30 items, show top items + "and N more…")
