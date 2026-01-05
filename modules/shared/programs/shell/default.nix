# Shell 설정 (zsh, starship, atuin, zoxide, fzf, fzf-tab)
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

    # 파일 출력 (bat 사용)
    cat = "bat";

    # broot: tree 스타일 출력
    bt = "br -c :pt";
  };

  # Zsh 설정
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # fzf-tab 플러그인 (tmux 내부에서 자동완성 사용)
    plugins = [
      {
        name = "fzf-tab";
        src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
      }
    ];

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

      # === fzf-tab 설정 ===
      # 기본 키바인딩
      zstyle ':fzf-tab:*' fzf-bindings 'tab:accept'
      zstyle ':fzf-tab:*' continuous-trigger '/'

      # tmux 내부: 팝업 사용 (tmux 3.2+)
      if [[ -n "''${TMUX}" ]]; then
        zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
        zstyle ':fzf-tab:*' popup-min-size 80 12
      fi

      # 미리보기 설정 (eza, bat 활용)
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath 2>/dev/null || ls -1 $realpath'
      zstyle ':fzf-tab:complete:cat:*' fzf-preview 'bat --style=numbers --color=always $realpath 2>/dev/null || cat $realpath'
      zstyle ':fzf-tab:complete:ls:*' fzf-preview 'eza -1 --color=always $realpath 2>/dev/null || ls -1 $realpath'

      # git 명령어 미리보기
      zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview 'git log --oneline --color=always $word -- 2>/dev/null | head -20'
      zstyle ':fzf-tab:complete:git-log:*' fzf-preview 'git show --color=always $word 2>/dev/null | head -50'
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
