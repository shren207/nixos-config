#!/usr/bin/env bash
# tests/shell-script-tests.sh
# 배포 레이아웃 기준 shell script fixture 테스트
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures/shell-scripts"
TEST_TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/shell-script-tests-list.XXXXXX")"

# Git hooks may export repository-scoped GIT_* variables.
# Fixture repositories must run fully isolated from the outer repo context.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_OBJECT_DIRECTORY
unset GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_IMPLICIT_WORK_TREE

cleanup() {
  local dir
  if [[ -f "$TEST_TMP_FILE" ]]; then
    while IFS= read -r dir; do
      [[ -n "$dir" ]] && rm -rf "$dir"
    done < "$TEST_TMP_FILE"
    rm -f "$TEST_TMP_FILE"
  fi
  return 0
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || fail "expected output to not contain: $needle"
}

new_sandbox() {
  local dir
  dir=$(mktemp -d "${TMPDIR:-/tmp}/shell-script-tests.XXXXXX")
  printf '%s\n' "$dir" >> "$TEST_TMP_FILE"
  printf '%s\n' "$dir"
}

assert_shell_default_wiring() {
  local shell_nix="$REPO_ROOT/modules/shared/programs/shell/default.nix"
  local content
  content=$(cat "$shell_nix")

  assert_contains "$content" 'home.file.".local/bin/wt"'
  assert_contains "$content" 'home.file.".local/lib/wt"'
  assert_contains "$content" 'home.file.".local/lib/rebuild-common.sh"'
  assert_contains "$content" 'home.file.".local/lib/rebuild"'
  assert_contains "$content" 'recursive = true;'
}

symlink_helper_dir() {
  local source_dir="$1"
  local target_dir="$2"
  local file
  local rel_path

  mkdir -p "$target_dir"
  while IFS= read -r file; do
    rel_path="${file#"$source_dir"/}"
    mkdir -p "$(dirname "$target_dir/$rel_path")"
    ln -sf "$file" "$target_dir/$rel_path"
  done < <(find "$source_dir" -type f | sort)
}

install_deployed_layout() {
  local sandbox="$1"
  local flake_path="${2:-$REPO_ROOT}"
  local home_dir="$sandbox/home"
  local bin_dir="$home_dir/.local/bin"
  local lib_dir="$home_dir/.local/lib"

  assert_shell_default_wiring
  mkdir -p "$bin_dir" "$lib_dir/wt" "$lib_dir/rebuild"

  cp "$REPO_ROOT/modules/shared/scripts/wt.sh" "$bin_dir/wt"
  chmod +x "$bin_dir/wt"
  ln -sf "$FIXTURE_DIR/bin/codex-sync" "$bin_dir/codex-sync"
  symlink_helper_dir "$REPO_ROOT/modules/shared/scripts/lib/wt" "$lib_dir/wt"

  sed "s|@flakePath@|$flake_path|g" \
    "$REPO_ROOT/modules/shared/scripts/rebuild-common.sh" > "$lib_dir/rebuild-common.sh"
  symlink_helper_dir "$REPO_ROOT/modules/shared/scripts/lib/rebuild" "$lib_dir/rebuild"
}

create_git_fixture_repo() {
  local repo_root="$1"
  local sandbox_root home_dir
  sandbox_root="$(dirname "$repo_root")"
  home_dir="$sandbox_root/home"

  fixture_git() {
    HOME="$home_dir" \
      XDG_CONFIG_HOME="$home_dir/.config" \
      GIT_CONFIG_GLOBAL=/dev/null \
      GIT_CONFIG_NOSYSTEM=1 \
      git -C "$repo_root" \
      -c core.hooksPath=/dev/null \
      -c commit.gpgSign=false \
      -c init.templateDir= \
      "$@"
  }

  mkdir -p "$repo_root/.claude/worktrees" "$home_dir/.config"
  (
    cd "$repo_root"
    fixture_git init >/dev/null 2>&1
    fixture_git branch -M main >/dev/null 2>&1
    fixture_git config user.name "Test User"
    fixture_git config user.email "test@example.com"
    echo "fixture" > README.md
    fixture_git add README.md
    fixture_git commit -m "initial" >/dev/null 2>&1
    fixture_git worktree add ".claude/worktrees/feature_one" -b feature-one >/dev/null 2>&1
  )
}

run_test() {
  local name="$1"
  shift
  echo "==> $name"
  "$@"
}

test_wt_help_from_deployed_layout() {
  local sandbox output
  sandbox=$(new_sandbox)
  install_deployed_layout "$sandbox"

  output=$(
    HOME="$sandbox/home" \
    PATH="$FIXTURE_DIR/bin:$PATH" \
    bash "$sandbox/home/.local/bin/wt" --help 2>&1
  )

  assert_contains "$output" "사용법: wt"
  assert_contains "$output" "wt cleanup [--auto]"
}

test_rebuild_common_exports_public_api() {
  local sandbox output
  sandbox=$(new_sandbox)
  install_deployed_layout "$sandbox"

  output=$(
    HOME="$sandbox/home" \
    PATH="$FIXTURE_DIR/bin:$PATH" \
    bash -c '
      set -euo pipefail
      REBUILD_CMD="nixos-rebuild"
      source "'"$sandbox/home/.local/lib/rebuild-common.sh"'"
      parse_args --offline --force --cores 2
      printf "offline=%s\nforce=%s\ncores=%s\n" "$OFFLINE_FLAG" "$FORCE_FLAG" "$CORES_FLAG"
      declare -F acquire_nrs_lock
      declare -F release_nrs_lock_on_failure
      declare -F acquire_rebuild_lock
      declare -F release_rebuild_lock_on_failure
      declare -F preflight_source_build_check
      declare -F preview_changes
      declare -F worktree_symlink_guard
      declare -F maybe_relink_or_restore
      declare -F cleanup_build_artifacts
    ' 2>&1
  )

  assert_contains "$output" "offline=--offline"
  assert_contains "$output" "force=true"
  assert_contains "$output" "cores=--cores 2"
  assert_contains "$output" "acquire_nrs_lock"
  assert_contains "$output" "release_nrs_lock_on_failure"
  assert_contains "$output" "acquire_rebuild_lock"
  assert_contains "$output" "release_rebuild_lock_on_failure"
  assert_contains "$output" "preflight_source_build_check"
  assert_contains "$output" "preview_changes"
  assert_contains "$output" "worktree_symlink_guard"
  assert_contains "$output" "maybe_relink_or_restore"
}

test_detect_worktree_uses_current_worktree_path() {
  local sandbox home_dir repo_root worktree_root output
  sandbox=$(new_sandbox)
  home_dir="$sandbox/home"
  repo_root="$sandbox/repo"

  create_git_fixture_repo "$repo_root"
  repo_root="$(cd "$repo_root" && pwd -P)"
  worktree_root="$repo_root/.claude/worktrees/feature_one"
  install_deployed_layout "$sandbox" "$repo_root"

  output=$(
    HOME="$home_dir" \
    PATH="$FIXTURE_DIR/bin:$PATH" \
    bash -c '
      set -euo pipefail
      cd "'"$worktree_root"'"
      REBUILD_CMD="nixos-rebuild"
      source "'"$home_dir/.local/lib/rebuild-common.sh"'"
      printf "flake=%s\nmain=%s\n" "$FLAKE_PATH" "$MAIN_FLAKE_PATH"
    ' 2>&1
  )

  assert_contains "$output" "flake=$worktree_root"
  assert_contains "$output" "main=$repo_root"
}

test_wt_ls_from_deployed_layout_lists_worktrees() {
  local sandbox home_dir repo_root output
  sandbox=$(new_sandbox)
  home_dir="$sandbox/home"
  repo_root="$sandbox/repo"

  install_deployed_layout "$sandbox"
  create_git_fixture_repo "$repo_root"

  output=$(
    HOME="$home_dir" \
    PATH="$FIXTURE_DIR/bin:$PATH" \
    bash -c '
      set -euo pipefail
      cd "'"$repo_root"'"
      "'"$home_dir/.local/bin/wt"'" ls
    ' 2>&1
  )

  assert_contains "$output" "Worktrees (1)"
  assert_contains "$output" "feature_one"
}

test_shadow_paths_do_not_override_managed_helpers() {
  local sandbox home_dir repo_root worktree_root output
  sandbox=$(new_sandbox)
  home_dir="$sandbox/home"
  repo_root="$sandbox/repo"

  create_git_fixture_repo "$repo_root"
  repo_root="$(cd "$repo_root" && pwd -P)"
  worktree_root="$repo_root/.claude/worktrees/feature_one"
  install_deployed_layout "$sandbox" "$repo_root"

  mkdir -p "$home_dir/.local/bin/lib/wt" "$home_dir/.local/lib/lib/rebuild"
  cat > "$home_dir/.local/bin/lib/wt/ui.sh" <<'EOF'
echo "SHADOW_WT_HELPER" >&2
EOF
  for helper in tmux git-state commands; do
    cat > "$home_dir/.local/bin/lib/wt/$helper.sh" <<'EOF'
:
EOF
  done
  for helper in common worktree locks preflight relink preview; do
    cat > "$home_dir/.local/lib/lib/rebuild/$helper.sh" <<'EOF'
echo "SHADOW_REBUILD_HELPER" >&2
EOF
  done
  cat > "$home_dir/.local/bin/codex-sync.sh" <<'EOF'
#!/usr/bin/env bash
echo "SHADOW_CODEX_SYNC" >&2
exit 0
EOF
  chmod +x "$home_dir/.local/bin/codex-sync.sh"

  output=$(
    HOME="$home_dir" \
    PATH="$FIXTURE_DIR/bin:$PATH" \
    bash -c '
      set -euo pipefail
      cd "'"$worktree_root"'"
      REBUILD_CMD="nixos-rebuild"
      source "'"$home_dir/.local/lib/rebuild-common.sh"'"
      "'"$home_dir/.local/bin/wt"'" --help
    ' 2>&1
  )

  assert_not_contains "$output" "SHADOW_WT_HELPER"
  assert_not_contains "$output" "SHADOW_REBUILD_HELPER"
  assert_not_contains "$output" "SHADOW_CODEX_SYNC"
}

test_wt_create_creates_worktree_without_shadow_codex_sync() {
  local sandbox home_dir repo_root output new_worktree fallback_dir marker_file
  sandbox=$(new_sandbox)
  home_dir="$sandbox/home"
  repo_root="$sandbox/repo"
  fallback_dir="$sandbox/fallback-bin"
  marker_file="$sandbox/codex-sync-marker"

  create_git_fixture_repo "$repo_root"
  repo_root="$(cd "$repo_root" && pwd -P)"
  install_deployed_layout "$sandbox" "$repo_root"

  mkdir -p "$home_dir/.local/bin" "$fallback_dir"
  cat > "$home_dir/.local/bin/codex-sync" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'managed\n' >> "${CODEX_SYNC_MARKER:?}"
exit 0
EOF
  chmod +x "$home_dir/.local/bin/codex-sync"
  cat > "$home_dir/.local/bin/codex-sync.sh" <<'EOF'
#!/usr/bin/env bash
echo "SHADOW_CODEX_SYNC" >&2
exit 0
EOF
  chmod +x "$home_dir/.local/bin/codex-sync.sh"
  cat > "$fallback_dir/codex-sync" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'fallback\n' >> "${CODEX_SYNC_MARKER:?}"
exit 0
EOF
  chmod +x "$fallback_dir/codex-sync"

  output=$(
    HOME="$home_dir" \
    PATH="$fallback_dir:$FIXTURE_DIR/bin:$PATH" \
    CODEX_SYNC_MARKER="$marker_file" \
    bash -c '
      set -euo pipefail
      cd "'"$repo_root"'"
      "'"$home_dir/.local/bin/wt"'" feature-two
    ' 2>&1
  )

  new_worktree="$repo_root/.claude/worktrees/feature-two"
  [[ -d "$new_worktree" ]] || fail "expected worktree directory to exist: $new_worktree"
  assert_contains "$output" "$new_worktree"
  assert_not_contains "$output" "SHADOW_CODEX_SYNC"
  assert_contains "$(cat "$marker_file")" "managed"
  assert_not_contains "$(cat "$marker_file")" "fallback"
}

test_missing_managed_helpers_fail_closed() {
  local sandbox home_dir repo_root output
  sandbox=$(new_sandbox)
  home_dir="$sandbox/home"
  repo_root="$sandbox/repo"

  create_git_fixture_repo "$repo_root"
  repo_root="$(cd "$repo_root" && pwd -P)"
  install_deployed_layout "$sandbox" "$repo_root"

  rm -rf "$home_dir/.local/lib/wt" "$home_dir/.local/lib/rebuild"
  mkdir -p "$home_dir/.local/bin/lib/wt" "$home_dir/.local/lib/lib/rebuild"
  cat > "$home_dir/.local/bin/lib/wt/ui.sh" <<'EOF'
echo "SHADOW_WT_LOADED" >&2
EOF
  cat > "$home_dir/.local/lib/lib/rebuild/common.sh" <<'EOF'
echo "SHADOW_REBUILD_LOADED" >&2
EOF

  output=$(
    HOME="$home_dir" \
    PATH="$FIXTURE_DIR/bin:$PATH" \
    bash "$home_dir/.local/bin/wt" --help 2>&1 || true
  )
  assert_contains "$output" "helper directory not found"
  assert_not_contains "$output" "SHADOW_WT_LOADED"

  output=$(
    HOME="$home_dir" \
    PATH="$FIXTURE_DIR/bin:$PATH" \
    bash -c '
      set -euo pipefail
      REBUILD_CMD="nixos-rebuild"
      source "'"$home_dir/.local/lib/rebuild-common.sh"'"
    ' 2>&1 || true
  )
  assert_contains "$output" "helper directory not found"
  assert_not_contains "$output" "SHADOW_REBUILD_LOADED"
}

test_fixture_git_is_hermetic_against_global_hooks() {
  local sandbox repo_root hook_dir global_config hook_marker
  sandbox=$(new_sandbox)
  repo_root="$sandbox/repo"
  hook_dir="$sandbox/global-hooks"
  global_config="$sandbox/global-gitconfig"
  hook_marker="$sandbox/HOOK_RAN"

  mkdir -p "$hook_dir"
  cat > "$hook_dir/pre-commit" <<EOF
#!/usr/bin/env bash
echo hook-ran > "$hook_marker"
exit 1
EOF
  chmod +x "$hook_dir/pre-commit"
  cat > "$global_config" <<EOF
[core]
	hooksPath = $hook_dir
EOF

  GIT_CONFIG_GLOBAL="$global_config" create_git_fixture_repo "$repo_root"

  [[ -d "$repo_root/.git" ]] || fail "expected fixture repo to be created"
  [[ ! -e "$hook_marker" ]] || fail "expected fixture git setup to ignore host global hooks"
}

run_test "wt help uses deployed helper layout" test_wt_help_from_deployed_layout
run_test "rebuild-common exports public API" test_rebuild_common_exports_public_api
run_test "detect_worktree switches to active worktree" test_detect_worktree_uses_current_worktree_path
run_test "wt ls lists deployed worktrees" test_wt_ls_from_deployed_layout_lists_worktrees
run_test "shadow paths do not override managed helpers" test_shadow_paths_do_not_override_managed_helpers
run_test "wt create uses managed codex-sync path" test_wt_create_creates_worktree_without_shadow_codex_sync
run_test "missing managed helpers fail closed" test_missing_managed_helpers_fail_closed
run_test "fixture git setup ignores host global hooks" test_fixture_git_is_hermetic_against_global_hooks
