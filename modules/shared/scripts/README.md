# Shared Script Layout

운영 엔트리포인트는 top-level 파일명과 CLI surface를 유지하고, 실제 구현은 책임별 helper로 분리한다.

## Public Entrypoints

- `wt.sh`: worktree CLI thin wrapper
- `rebuild-common.sh`: `nrs`/`nrp`가 source하는 compatibility loader
- `nrs-relink.sh`: standalone relink CLI. `rebuild-common` helper로 강제 흡수하지 않는다.

## Helper Boundaries

- `lib/wt/ui.sh`: prompt, formatting, repo/path helpers
- `lib/wt/tmux.sh`: tmux window/session orchestration
- `lib/wt/git-state.sh`: git/worktree state collection, PR status lookup
- `lib/wt/commands.sh`: `wt` subcommands and bootstrap/remove orchestration
- `lib/rebuild/common.sh`: logging, worktree detection, argument parsing
- `lib/rebuild/worktree.sh`: `mkOutOfStoreSymlink` drift guard
- `lib/rebuild/locks.sh`: cooperative nrs/rebuild locking
- `lib/rebuild/preflight.sh`: source-build and cask preflight checks
- `lib/rebuild/relink.sh`: worktree symlink cleanup/relink/restore helpers
- `lib/rebuild/preview.sh`: build preview and artifact cleanup

## Rules

- Top-level entrypoints stay thin. New runtime logic belongs in a helper file unless it is dispatch/help text.
- Helpers are grouped by change reason, not by arbitrary line counts.
- Loader source order is part of the contract. Keep the explicit `source` order in top-level entrypoints in sync with helper dependencies.
- If a new helper is added, keep `modules/shared/programs/shell/default.nix` and `tests/shell-script-tests.sh` aligned with the deployed `~/.local/lib/**` layout expectations.
- Tests must exercise the deployed layout, not only the repo-local path. `tests/shell-script-tests.sh` should validate both the expected Home Manager wiring and runtime smoke paths.
