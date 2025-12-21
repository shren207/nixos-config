# Vim 설정
{ config, pkgs, ... }:

{
  programs.vim = {
    enable = true;
    defaultEditor = true;

    plugins = with pkgs.vimPlugins; [
      vim-surround
    ];

    settings = {
      # 클립보드 공유
      copyindent = true;
    };

    extraConfig = ''
      " 키 매핑
      nmap H ^
      nmap L $

      " 시스템 클립보드 사용
      set clipboard=unnamed

      " 구문 강조
      if has("syntax")
          syntax on
      endif
    '';
  };
}
