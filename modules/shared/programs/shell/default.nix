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
    # Claude Code (기본적으로 --dangerously-skip-permissions 사용)
    claude = "command claude --dangerously-skip-permissions";

    # 파일 목록 (eza 사용)
    l = "eza -l";
    ls = "eza -la";
    ll = "eza -la";

    # broot: tree 스타일 출력
    bt = "br -c :pt";

    # Nix rebuild (launchd 에이전트 정리 + Hammerspoon 재시작 포함)
    # 문제 예방: setupLaunchAgents 멈춤, Hammerspoon HOME 오염
    nrs = ''
      echo "🧹 Cleaning up launchd agents..." && \
      launchctl bootout gui/$(id -u)/com.green.atuin-watchdog 2>/dev/null; \
      launchctl bootout gui/$(id -u)/com.green.folder-action.compress-rar 2>/dev/null; \
      launchctl bootout gui/$(id -u)/com.green.folder-action.compress-video 2>/dev/null; \
      launchctl bootout gui/$(id -u)/com.green.folder-action.convert-video-to-gif 2>/dev/null; \
      launchctl bootout gui/$(id -u)/com.green.folder-action.rename-asset 2>/dev/null; \
      rm -f ~/Library/LaunchAgents/com.green.*.plist && \
      sleep 1 && \
      echo "🔨 Running darwin-rebuild..." && \
      sudo darwin-rebuild switch --flake ~/IdeaProjects/nixos-config && \
      echo "🔄 Restarting Hammerspoon..." && \
      killall Hammerspoon 2>/dev/null; sleep 1; open -a Hammerspoon && \
      echo "✅ Done!"
    '';
    nrs-offline = ''
      echo "🧹 Cleaning up launchd agents..." && \
      launchctl bootout gui/$(id -u)/com.green.atuin-watchdog 2>/dev/null; \
      launchctl bootout gui/$(id -u)/com.green.folder-action.compress-rar 2>/dev/null; \
      launchctl bootout gui/$(id -u)/com.green.folder-action.compress-video 2>/dev/null; \
      launchctl bootout gui/$(id -u)/com.green.folder-action.convert-video-to-gif 2>/dev/null; \
      launchctl bootout gui/$(id -u)/com.green.folder-action.rename-asset 2>/dev/null; \
      rm -f ~/Library/LaunchAgents/com.green.*.plist && \
      sleep 1 && \
      echo "🔨 Running darwin-rebuild (offline)..." && \
      sudo darwin-rebuild switch --flake ~/IdeaProjects/nixos-config --offline && \
      echo "🔄 Restarting Hammerspoon..." && \
      killall Hammerspoon 2>/dev/null; sleep 1; open -a Hammerspoon && \
      echo "✅ Done!"
    '';

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
  # 동기화: auto_sync가 터미널 명령 실행 시 sync_frequency 간격으로 자동 sync
  # 모니터링: modules/darwin/programs/atuin/에서 watchdog + Hammerspoon 메뉴바 제공
  programs.atuin = {
    enable = true;
    settings = {
      # 동기화 설정
      auto_sync = true;              # 명령 실행 후 자동 sync
      sync_frequency = "1m";         # auto_sync 최소 간격
      sync.records = true;           # Sync v2 (record-based sync) 활성화

      # 네트워크 타임아웃
      network_timeout = 30;          # 서버 요청 최대 대기 (초)
      network_connect_timeout = 5;   # 연결 수립 대기 (초)
      local_timeout = 5;             # SQLite 연결 대기 (초)

      # UI 설정
      style = "compact";
      inline_height = 9;
      show_help = false;
      update_check = false;
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
