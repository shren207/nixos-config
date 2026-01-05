# inshellisense 설정 (IDE 스타일 쉘 자동완성)
# https://github.com/microsoft/inshellisense
{ config, pkgs, lib, ... }:

{
  # 패키지 설치
  home.packages = [ pkgs.inshellisense ];

  # 설정 파일 (~/.config/inshellisense/rc.toml)
  # 키바인딩: Tab=다음, Shift+Tab=이전, Enter=수락
  xdg.configFile."inshellisense/rc.toml".text = ''
    [bindings.acceptSuggestion]
    key = "return"

    [bindings.nextSuggestion]
    key = "tab"

    [bindings.previousSuggestion]
    key = "tab"
    shift = true

    [bindings.dismissSuggestions]
    key = "escape"
  '';

  # Zsh 초기화 (반드시 마지막에 실행되어야 함)
  programs.zsh.initContent = lib.mkAfter ''
    # inshellisense 자동 시작
    if command -v is >/dev/null 2>&1; then
      eval "$(is init zsh)"
    fi
  '';
}
