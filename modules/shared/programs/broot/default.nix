# broot 설정 (Modern Linux Tree)
{ config, pkgs, lib, ... }:

{
  programs.broot = {
    enable = true;
    enableZshIntegration = true;  # br 함수 자동 생성

    settings = {
      modal = false;  # vim 모드 비활성화 (기본값)
    };
  };
}
