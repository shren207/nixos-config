# Shell 설정 - Linux/NixOS 전용
{
  config,
  pkgs,
  lib,
  ...
}:

let
  scriptsDir = ../../../../scripts;
in
{
  # NixOS 전용 Zsh 초기화
  programs.zsh.initContent = lib.mkMerge [
    (lib.mkBefore ''
      # 유니코드 결합 문자 처리 (wide character 지원)
      setopt COMBINING_CHARS
    '')
  ];

  # Atuin 비활성화 (Termius 한국어 입력 문제 테스트용)
  programs.atuin.enable = lib.mkForce false;

  # zsh-syntax-highlighting 비활성화 (테스트용)
  programs.zsh.syntaxHighlighting.enable = lib.mkForce false;

  # NixOS용 스크립트 설치
  home.file.".local/bin/nrs.sh" = {
    source = "${scriptsDir}/nrs-nixos.sh";
    executable = true;
  };

  home.file.".local/bin/nrp.sh" = {
    source = "${scriptsDir}/nrp-nixos.sh";
    executable = true;
  };

  # NixOS 전용 aliases
  home.shellAliases = {
    # Nix 시스템 관리 (nixos-rebuild)
    nrs = "~/.local/bin/nrs.sh";
    nrs-offline = "~/.local/bin/nrs.sh --offline";
    nrp = "~/.local/bin/nrp.sh";
    nrp-offline = "~/.local/bin/nrp.sh --offline";

    # NixOS 세대 히스토리
    nrh = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -10";
    nrh-all = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
  };
}
