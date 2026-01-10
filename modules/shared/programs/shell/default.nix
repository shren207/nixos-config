# Shell 설정 (zsh, starship, atuin, zoxide, fzf)
{ config, pkgs, lib, ... }:

{
  # 환경 변수
  home.sessionVariables = {
    # iCloud Drive 경로
    ICLOUD = "$HOME/Library/Mobile Documents/com~apple~CloudDocs";

    # Bun
    BUN_INSTALL = "$HOME/.bun";
  };

  # PATH 추가 (순서 중요: .local/bin이 먼저 와야 네이티브 claude가 우선됨)
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.bun/bin"
    "$HOME/.npm-global/bin"
  ];

  # Shell aliases
  home.shellAliases = {
    # Claude Code
    claude-d = "claude --dangerously-skip-permissions";
    claude-d-mcp = "claude-d --mcp-config $HOME/.claude/mcp-config.json";

    # 파일 목록 (eza 사용)
    l = "eza -l";
    ls = "eza -la";
    ll = "eza -la";

    # broot: tree 스타일 출력
    bt = "br -c :pt";

    # Nix rebuild
    nrs = "sudo darwin-rebuild switch --flake ~/IdeaProjects/nixos-config";
    nrs-offline = "sudo darwin-rebuild switch --flake ~/IdeaProjects/nixos-config --offline";

    # Hammerspoon CLI
    hs = "/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs";
    hsr = ''hs -c "hs.reload()"'';

    # 터미널 CSI u 모드 리셋 (문제 발생 시 복구용)
    reset-term = ''printf "\033[?u\033[<u"'';
  };

  # Zsh 설정
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # 히스토리 설정
    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      share = true;
    };

    # 초기화 스크립트 (initContent 사용)
    initContent = lib.mkMerge [
      # 가장 먼저 실행되어야 할 설정
      (lib.mkBefore ''
        # Ghostty 쉘 통합 설정
        if [ -n "''${GHOSTTY_RESOURCES_DIR}" ]; then
          builtin source "''${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration"
        fi

        # Homebrew 설정
        eval "$(/opt/homebrew/bin/brew shellenv)"
      '')

      # 나머지 초기화 스크립트
      ''
      # cursor 래퍼: 인수 없이 실행 시 현재 디렉터리 열기
      cursor() {
        if [ $# -eq 0 ]; then
          command cursor .
        else
          command cursor "$@"
        fi
      }

      # NVM bash completion
      [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

      # Bun completions
      [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

      # Deno 설정
      [ -f "$HOME/.deno/env" ] && . "$HOME/.deno/env"

      # Mise 활성화 (node, ruby 등 런타임 관리)
      if command -v mise >/dev/null 2>&1; then
        eval "$(mise activate zsh)"
      fi

      # tmux 내부에서 clear 시 history buffer도 함께 삭제
      if [ -n "$TMUX" ]; then
        alias clear='clear && tmux clear-history'
      fi
    ''
    ];
  };

  # Starship 프롬프트
  programs.starship = {
    enable = true;
  };

  # Atuin 히스토리
  programs.atuin = {
    enable = true;
    settings = {
      auto_sync = true;
      update_check = false;
      sync_frequency = "1m";
      style = "compact";
      inline_height = 9;
      show_help = false;
    };
  };

  # Zoxide (cd 대체)
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # FZF
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "${lib.getExe pkgs.fd} --strip-cwd-prefix --exclude .git";
    fileWidgetCommand = "${lib.getExe pkgs.fd} --strip-cwd-prefix --exclude .git";
  };
}
