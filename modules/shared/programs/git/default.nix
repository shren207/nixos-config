# Git 설정
{ config, pkgs, lib, ... }:

{
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
