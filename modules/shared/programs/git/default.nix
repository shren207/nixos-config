# Git 설정
{ config, pkgs, lib, ... }:

let
  # Rebase 역순 표시 스크립트
  rebaseReverseEditor = pkgs.writeShellScript "git-rebase-reverse-editor" ''
    set -euo pipefail

    TODO_FILE="$1"
    TEMP_FILE=$(mktemp)
    trap 'rm -f "$TEMP_FILE"' EXIT

    COMMAND_PATTERN='^(p|pick|r|reword|e|edit|s|squash|f|fixup|x|exec|b|break|d|drop|l|label|t|reset|m|merge)[[:space:]]'

    # 커밋 라인과 나머지(주석/빈줄) 분리
    COMMITS=()
    OTHERS=()
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ $COMMAND_PATTERN ]]; then
        COMMITS+=("$line")
      else
        OTHERS+=("$line")
      fi
    done < "$TODO_FILE"

    # 역순 정렬하여 표시 (최신 커밋이 위로)
    {
      for ((i=''${#COMMITS[@]}-1; i>=0; i--)); do
        printf '%s\n' "''${COMMITS[i]}"
      done
      printf '%s\n' "''${OTHERS[@]}"
    } > "$TODO_FILE"

    # 에디터 실행
    "''${EDITOR:-${pkgs.vim}/bin/vim}" "$TODO_FILE"
    EDITOR_EXIT=$?

    # 에디터가 실패하면 즉시 종료 (rebase 취소)
    if [[ $EDITOR_EXIT -ne 0 ]]; then
      exit $EDITOR_EXIT
    fi

    # 편집 후 다시 역순으로 복원 (= 원래 순서)
    EDITED_COMMITS=()
    EDITED_OTHERS=()
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ $COMMAND_PATTERN ]]; then
        EDITED_COMMITS+=("$line")
      else
        EDITED_OTHERS+=("$line")
      fi
    done < "$TODO_FILE"

    # 복원 로직 - 쓰기 실패 시 에러 처리
    if {
      for ((i=''${#EDITED_COMMITS[@]}-1; i>=0; i--)); do
        printf '%s\n' "''${EDITED_COMMITS[i]}"
      done
      printf '%s\n' "''${EDITED_OTHERS[@]}"
    } > "$TODO_FILE"; then
      exit 0
    else
      echo "Error: Failed to restore rebase order." >&2
      exit 1
    fi
  '';
in
{
  # Delta (git diff 시각화)
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      dark = true;
    };
  };

  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "greenhead";
        email = "shren0812@gmail.com";
      };

      alias = {
        s = "status -s";
        l = "log --color --graph --decorate --date=format:'%Y-%m-%d' --abbrev-commit --pretty=format:'%C(red)%h%C(auto)%d %s %C(green)(%cr)%C(bold blue) %an'";
      };

      http.postBuffer = 157286400;
      branch.sort = "committerdate";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = false;
      merge.conflictStyle = "zdiff3";

      # Rebase 역순 표시 설정
      sequence.editor = "${rebaseReverseEditor}";
    };

    ignores = [
      # macOS
      ".DS_Store"

      # IDE
      ".idea"
      ".cursorrules"
      ".cursor"

      # Claude
      ".claude"
      "**/.claude/settings.local.json"
      "CLAUDE.local.md"
      "CLAUDE.local.*.md"
    ];
  };

  # GitHub CLI
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
    };
  };
}
