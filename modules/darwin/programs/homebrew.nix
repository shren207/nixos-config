# Homebrew 패키지 관리 (GUI 앱)
{ config, pkgs, ... }:

{
  # Homebrew 활성화
  homebrew = {
    enable = true;

    # 선언되지 않은 앱 정리
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
    };

    # Homebrew Formula (CLI 도구)
    # Claude Code는 binary 버전을 사용 (Node.js 버전 의존성 없음)
    # 설치: curl -fsSL https://claude.ai/install.sh | bash
    brews = [
      # Nix로 관리하기 어려운 것들
      # "llvm@18"
      # "mysql@8.0"
      # "redis"
    ];

    # Homebrew Cask (GUI 앱)
    casks = [
      "cursor"
      "ghostty"
      "raycast"
      "rectangle"
      "hammerspoon"
      "homerow"
      "docker"
      "fork"
      "slack"
      "figma"
      "monitorcontrol"
    ];

    # Mac App Store 앱 (mas 필요)
    # masApps = {
    #   # "앱이름" = 앱스토어ID;
    # };
  };
}
