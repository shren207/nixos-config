# NixOS 시스템 설정
{
  config,
  pkgs,
  lib,
  inputs,
  username,
  hostname,
  ...
}:

{
  # 시스템 기본
  system.stateVersion = "24.11";

  # 부트로더
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # 호스트명
  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  # 시간대
  time.timeZone = "Asia/Seoul";

  # 로케일
  i18n.defaultLocale = "ko_KR.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "ko_KR.UTF-8";
  };

  # Nix 설정
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [
        "root"
        username
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # 사용자
  users.users.${username} = {
    isNormalUser = true;
    description = "YOON NOKDOO";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.zsh;
    # SSH 키는 hosts/greenhead-minipc/default.nix에서 설정
  };

  # 기본 패키지
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    htop
    nvd
  ];

  # Zsh 활성화
  programs.zsh.enable = true;

  # 프로그램 모듈 임포트
  imports = [
    ./programs/tailscale.nix
    ./programs/ssh.nix
    ./programs/mosh.nix
    ./programs/fail2ban.nix
  ];
}
