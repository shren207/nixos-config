# Shell 설정 (zsh, starship, atuin, zoxide, fzf)
{ config, pkgs, lib, ... }:

let
  # 스크립트 디렉토리 (nixos-config 루트 기준)
  scriptsDir = ../../../../scripts;
in
{
  # nrs.sh 스크립트 설치
  home.file.".local/bin/nrs.sh" = {
    source = "${scriptsDir}/nrs.sh";
    executable = true;
  };

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

    # Nix 시스템 관리
    # 스크립트: scripts/nrs.sh
    # 소스 참조: 모두 flake.lock에 잠긴 remote Git URL 사용 (로컬 경로 아님)
    nrs = "~/.local/bin/nrs.sh";                    # 빌드 미리보기 + 확인 후 적용
    nrs-offline = "~/.local/bin/nrs.sh --offline";  # 오프라인 빌드
    nrp = "(cd ~/IdeaProjects/nixos-config && sudo darwin-rebuild build --flake . && echo '📋 Preview:' && nvd diff /run/current-system ./result)";  # 미리보기만 (적용 안 함)
    nrh = "nvd history -p /nix/var/nix/profiles/system";  # 시스템 세대 히스토리

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
