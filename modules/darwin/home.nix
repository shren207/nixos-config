# Home Manager 설정 (macOS)
{ config, pkgs, lib, inputs, username, nixosConfigPath, hostType, ... }:

{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";

  # Home Manager 모듈에 nixosConfigPath, hostType 전달
  home-manager.extraSpecialArgs = { inherit nixosConfigPath hostType; };

  home-manager.users.${username} = { config, pkgs, lib, ... }: {
    home.username = username;
    # mkForce: home-manager-secrets가 users.users.${name}.home을 참조하는데
    # nix-darwin에서는 이 값이 null이므로 강제 설정 필요
    home.homeDirectory = lib.mkForce "/Users/${username}";

    # 프로그램별 모듈 임포트
    imports = [
      # Secrets 관리
      inputs.home-manager-secrets.homeManagerModules.home-manager-secrets
      inputs.nixos-config-secret.homeManagerModules.default

      # 공유 프로그램
      ../shared/programs/broot
      ../shared/programs/ghostty
      ../shared/programs/git
      ../shared/programs/shell
      ../shared/programs/tmux
      ../shared/programs/vim

      # macOS 전용
      ./programs/atuin
      ./programs/hammerspoon
      ./programs/claude
      ./programs/cursor
      ./programs/folder-actions
      ./programs/keybindings
      ./programs/ssh
    ];

    # CLI 도구 패키지
    home.packages = with pkgs; [
      # 파일/검색 도구
      bat
      broot
      eza
      fd
      fzf
      ripgrep
      zoxide

      # 개발 도구
      tmux
      lazygit
      gh
      git
      shellcheck

      # 쉘 도구
      starship
      atuin

      # 미디어 처리
      ffmpeg
      imagemagick
      rar

      # 기타 유틸리티
      curl
      unzip
      jq
      htop

      # Nix 도구
      nvd  # nix closure 버전 비교 (업데이트 미리보기용)
    ];

    home.stateVersion = "25.05";
  };
}
