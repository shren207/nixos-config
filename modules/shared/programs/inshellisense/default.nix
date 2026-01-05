# inshellisense 설정 (IDE 스타일 쉘 자동완성)
# https://github.com/microsoft/inshellisense
# 주의: tmux 외부에서만 사용 (tmux 내부에서는 fzf-tab 사용)
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

  # Home Manager activation: ~/.inshellisense/ 쉘 플러그인 자동 생성
  # is init zsh는 ~/.inshellisense/zsh/init.zsh 파일을 소스하므로, 파일이 없으면 작동하지 않음
  home.activation.generateInshellisenseConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v is >/dev/null 2>&1; then
      if [[ ! -f "$HOME/.inshellisense/zsh/init.zsh" ]]; then
        run --quiet is init --generate-full-configs
      fi
    fi
  '';

  # Zsh 초기화 (반드시 마지막에 실행되어야 함)
  programs.zsh.initContent = lib.mkAfter ''
    # inshellisense 자동 시작 (tmux 외부에서만)
    # tmux 내부에서는 fzf-tab을 사용하므로 inshellisense 스킵
    # 참고: https://github.com/microsoft/inshellisense/issues/204 (tmux 공식 미지원)
    if [[ -z "''${TMUX}" ]] && command -v is >/dev/null 2>&1; then
      eval "$(is init zsh)"
    fi
  '';
}
