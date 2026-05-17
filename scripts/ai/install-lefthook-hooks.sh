#!/usr/bin/env bash
# Install Lefthook into the worktree-default hooks path and inject the staged-config guard.
#
# Source-of-truth scope: this script is the single source of truth for lefthook install
# and staged-config guard injection in the main repo and every worktree whose flake.nix
# shellHook delegates here (`bash ./scripts/ai/install-lefthook-hooks.sh`). Worktrees
# with inline shellHook implementations (`.claude/worktrees/issue_732/flake.nix` 등) are
# outside this scope and are tracked as a follow-up consolidation candidate.
set -euo pipefail

BEGIN_MARKER="# BEGIN nixos-config lefthook staged-config guard"
END_MARKER="# END nixos-config lefthook staged-config guard"

fail() {
  echo "install-lefthook-hooks: $*" >&2
  exit 1
}

if [ "${LEFTHOOK:-}" = "0" ] || [ "${LEFTHOOK:-}" = "false" ]; then
  exit 0
fi

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  exit 0
fi

command -v lefthook >/dev/null 2>&1 || fail "lefthook not found"
command -v python3 >/dev/null 2>&1 || fail "python3 not found"

repo_root="$(git rev-parse --show-toplevel)"
worktree_git_dir="$(git -C "$repo_root" rev-parse --path-format=absolute --git-dir)"
hooks_dir="$worktree_git_dir/hooks"
mkdir -p "$hooks_dir"

cleanup_redundant_hooks_path() {
  # lefthook 2.1.0+ refuses to install when core.hooksPath is set; --force used to bypass
  # the guard and emitted two warning lines on every direnv reload. The previous version
  # of this script wrote core.hooksPath to the same value git would resolve by default,
  # so the setting was functionally redundant. Unset only when the recorded value matches
  # the scope-appropriate default — if a user (or another tool) pointed it somewhere else,
  # leave it alone and surface a warning so the user can decide.
  #
  # Each scope is compared against its own default because `git rev-parse --git-path hooks`
  # honors core.hooksPath itself (so it can't be used as a stable baseline):
  #   - local scope lives in the main repo, so its default is <git-common-dir>/hooks.
  #   - worktree scope lives in the current worktree, so its default is <git-dir>/hooks
  #     (which equals git-common-dir/hooks in the main repo).
  local main_default_hooks worktree_default_hooks current_local current_worktree
  main_default_hooks="$(git -C "$repo_root" rev-parse --path-format=absolute --git-common-dir)/hooks"
  worktree_default_hooks="$(git -C "$repo_root" rev-parse --path-format=absolute --git-dir)/hooks"

  current_local="$(git -C "$repo_root" config --local --get core.hooksPath 2>/dev/null || true)"
  if [ -n "$current_local" ]; then
    if [ "$current_local" = "$main_default_hooks" ]; then
      git -C "$repo_root" config --local --unset-all core.hooksPath
      echo "install-lefthook-hooks: removed redundant core.hooksPath (local); default resolution preserved" >&2
    else
      echo "install-lefthook-hooks: non-default core.hooksPath (local) detected: $current_local — preserved, but lefthook warnings will persist" >&2
    fi
  fi

  if [ "$(git -C "$repo_root" config --get extensions.worktreeConfig 2>/dev/null || echo false)" = "true" ]; then
    current_worktree="$(git -C "$repo_root" config --worktree --get core.hooksPath 2>/dev/null || true)"
    if [ -n "$current_worktree" ]; then
      if [ "$current_worktree" = "$worktree_default_hooks" ]; then
        git -C "$repo_root" config --worktree --unset-all core.hooksPath
        echo "install-lefthook-hooks: removed redundant core.hooksPath (worktree); default resolution preserved" >&2
      else
        echo "install-lefthook-hooks: non-default core.hooksPath (worktree) detected: $current_worktree — preserved, but lefthook warnings will persist" >&2
      fi
    fi
  fi
}

acquire_install_lock() {
  # Concurrent direnv activations (e.g., several VSCode terminals reloading at once) race
  # on the same hook file: lefthook rewrites it and the Python block below re-reads and
  # re-writes it to inject the staged-config guard. Without serialization the guard can
  # appear twice and the next run aborts with "nested guard marker". The lock pins both
  # operations into a single critical section.
  #
  # Lock path lives under the main repo's .git/info — every worktree shares this directory
  # via `git rev-parse --git-common-dir`, so this single lock serializes installs from any
  # worktree as well. .git/info already exists in the main repo (lefthook.checksum lives
  # there), so no mkdir is required.
  local lock_file
  lock_file="$(git -C "$repo_root" rev-parse --path-format=absolute --git-common-dir)/info/lefthook-install.lock"

  exec 200>"$lock_file"

  if command -v flock >/dev/null 2>&1; then
    # Linux (NixOS): fd-based, auto-released when the fd closes.
    flock -x 200
  elif command -v lockf >/dev/null 2>&1; then
    # macOS (Darwin): fd-based BSD flock(2) wrapper, auto-released when the fd closes.
    lockf -s 200
  else
    fail "neither flock nor lockf available; cannot serialize lefthook install"
  fi
}

inject_staged_guard() {
  local hook_path
  hook_path="$(git -C "$repo_root" rev-parse --path-format=absolute --git-path hooks/pre-commit)"
  [ -f "$hook_path" ] || fail "generated pre-commit hook not found: $hook_path"

  python3 - "$hook_path" "$BEGIN_MARKER" "$END_MARKER" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

hook_path = Path(sys.argv[1])
begin = sys.argv[2]
end = sys.argv[3]

lines = hook_path.read_text(encoding="utf-8").splitlines()

regions: list[tuple[int, int]] = []
active: int | None = None
for idx, line in enumerate(lines):
    if line == begin:
        if active is not None:
            raise SystemExit("install-lefthook-hooks: nested guard marker")
        active = idx
    elif line == end:
        if active is None:
            raise SystemExit("install-lefthook-hooks: unmatched end guard marker")
        regions.append((active, idx))
        active = None
if active is not None:
    raise SystemExit("install-lefthook-hooks: unmatched begin guard marker")

remove = set()
for start, finish in regions:
    remove.update(range(start, finish + 1))
stripped = [line for idx, line in enumerate(lines) if idx not in remove]

call_indexes = [
    idx
    for idx, line in enumerate(stripped)
    if 'call_lefthook run "pre-commit" "$@"' in line
]
if not call_indexes:
    raise SystemExit("install-lefthook-hooks: final Lefthook pre-commit call not found")
insert_at = call_indexes[-1]

guard = [
    begin,
    'repo_root="$(git rev-parse --show-toplevel)" || exit 1',
    'expected_lefthook_config="$(cd "$repo_root" && pwd -P)/lefthook.yml"',
    'if [ -n "${LEFTHOOK_CONFIG:-}" ]; then',
    '  config_dir="$(dirname "$LEFTHOOK_CONFIG")"',
    '  config_base="$(basename "$LEFTHOOK_CONFIG")"',
    '  config_abs="$(cd "$config_dir" 2>/dev/null && pwd -P)/$config_base" || { echo "lefthook staged guard: invalid LEFTHOOK_CONFIG" >&2; exit 1; }',
    '  if [ "$config_abs" != "$expected_lefthook_config" ]; then',
    '    echo "lefthook staged guard: LEFTHOOK_CONFIG must point to repo lefthook.yml" >&2',
    '    exit 1',
    '  fi',
    'fi',
    'if [ -n "${LEFTHOOK_BIN:-}" ]; then',
    '  echo "lefthook staged guard: LEFTHOOK_BIN is not allowed for guarded commits" >&2',
    '  exit 1',
    'fi',
    'if [ -n "${LEFTHOOK_EXCLUDE:-}" ]; then',
    '  echo "lefthook staged guard: LEFTHOOK_EXCLUDE is not allowed for guarded commits" >&2',
    '  exit 1',
    'fi',
    'guard_path="scripts/ai/check-lefthook-staged-config.sh"',
    'if git -C "$repo_root" cat-file -e ":$guard_path" 2>/dev/null; then',
    '  guard_entry="$(git -C "$repo_root" ls-files -s -- "$guard_path")"',
    '  guard_count="$(printf "%s\\n" "$guard_entry" | sed "/^$/d" | wc -l | tr -d " ")"',
    '  guard_mode="$(printf "%s\\n" "$guard_entry" | awk \'{ print $1 }\')"',
    '  guard_stage="$(printf "%s\\n" "$guard_entry" | awk \'{ print $3 }\')"',
    '  if [ "$guard_count" != "1" ] || [ "$guard_stage" != "0" ] || { [ "$guard_mode" != "100644" ] && [ "$guard_mode" != "100755" ]; }; then',
    '    echo "lefthook staged guard: invalid staged guard script index entry" >&2',
    '    exit 1',
    '  fi',
    '  guard_tmp="$(mktemp "${TMPDIR:-/tmp}/lefthook-staged-guard.XXXXXX")" || exit 1',
    '  if ! git -C "$repo_root" show ":$guard_path" > "$guard_tmp"; then',
    '    rm -f "$guard_tmp"',
    '    echo "lefthook staged guard: failed to materialize staged guard script" >&2',
    '    exit 1',
    '  fi',
    '  guard_status=0',
    '  bash "$guard_tmp" "$repo_root" || guard_status="$?"',
    '  rm -f "$guard_tmp"',
    '  if [ "$guard_status" != "0" ]; then',
    '    exit "$guard_status"',
    '  fi',
    'else',
    '  if git -C "$repo_root" cat-file -e "HEAD:$guard_path" 2>/dev/null; then',
    '    echo "lefthook staged guard: guard script missing from index" >&2',
    '    exit 1',
    '  fi',
    '  if git -C "$repo_root" show :lefthook.yml 2>/dev/null | grep -Eq "scripts/ai/run-staged-snapshot.sh|scripts/ai/run-gitleaks-staged-policy.sh"; then',
    '    echo "lefthook staged guard: staged-snapshot hook surface requires staged guard script" >&2',
    '    exit 1',
    '  fi',
    'fi',
    end,
]

updated = stripped[:insert_at] + guard + stripped[insert_at:]
hook_path.write_text("\n".join(updated) + "\n", encoding="utf-8")
PY

  chmod +x "$hook_path"
  bash -n "$hook_path"
}

run_lefthook_install() {
  # lefthook 2.x has no --quiet flag and prints "sync hooks: ✔️ ..." on every install.
  # Suppress the success output so direnv reloads stay silent (SC-1) but re-emit captured
  # output on failure so the user still sees error context (e.g., remaining non-default
  # core.hooksPath warnings, missing hooks, etc.).
  local install_output rc=0
  install_output="$(lefthook install 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ]; then
    if [ -n "$install_output" ]; then
      printf '%s\n' "$install_output" >&2
    fi
    fail "lefthook install failed (exit $rc)"
  fi
}

cleanup_redundant_hooks_path
acquire_install_lock
run_lefthook_install
inject_staged_guard
