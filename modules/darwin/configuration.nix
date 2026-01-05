# macOS 시스템 설정 (nix-darwin)
{ config, pkgs, username, ... }:

{
  # Nerd Fonts 설치 (nix-darwin이 /Library/Fonts/Nix Fonts에 자동 링크)
  fonts.packages = with pkgs.nerd-fonts; [
    fira-code
    jetbrains-mono
  ];

  # Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # 사용자 설정
  users.users.${username} = {
    shell = pkgs.zsh;
    home = "/Users/${username}";
  };

  # 환경 설정
  environment = {
    shells = [ pkgs.zsh ];
  };

  # zsh 활성화 (darwin-rebuild PATH 설정에 필수)
  programs.zsh.enable = true;

  # macOS 시스템 기본값
  system.defaults = {
    # Dock 설정
    dock = {
      autohide = true;
      show-recents = false;
      tilesize = 36;
      mru-spaces = false;
      mineffect = "suck";
    };

    # Finder 설정
    finder = {
      AppleShowAllFiles = true;
      AppleShowAllExtensions = true;
    };

    # 전역 설정
    NSGlobalDomain = {
      # AppleInterfaceStyle = "Dark";  # Light 모드는 null 또는 주석처리
      AppleShowAllFiles = true;
      AppleShowAllExtensions = true;

      # 키보드: 키 반복 속도 가장 빠르게, 반복 지연 시간 제일 짧게
      InitialKeyRepeat = 15;  # 반복 지연 시간 (최소값: 15)
      KeyRepeat = 1;          # 키 반복 속도 (최소값: 1, 가장 빠름) [GUI에서는 2 이하로 내릴 수 없음]

      # 마우스: 자연스러운 스크롤 비활성화
      "com.apple.swipescrolldirection" = false;

      # 자동 수정 비활성화
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };

    # App Switcher를 모든 모니터에 표시
    CustomUserPreferences."com.apple.Dock" = {
      appswitcher-all-displays = true;
    };

    # 윈도우 매니저
    WindowManager = {
      EnableStandardClickToShowDesktop = false;
    };
  };

  # 입력소스 전환 툴팁 비활성화 (activation 스크립트)
  system.activationScripts.postActivation.text = ''
    # 입력소스 전환 툴팁 비활성화
    sudo defaults write /Library/Preferences/FeatureFlags/Domain/UIKit.plist \
      redesigned_text_cursor -dict-add Enabled -bool NO 2>/dev/null || true
  '';

  system.primaryUser = username;
  system.stateVersion = 6;
}
