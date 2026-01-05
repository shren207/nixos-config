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
    # inshellisense 자동 시작 (tmux 내부에서도 작동하도록 TMUX 관련 변수 우회)
    # 참고: https://github.com/microsoft/inshellisense/issues/306
    if command -v is >/dev/null 2>&1; then
      # tmux 내부인 경우 TMUX 관련 환경변수를 임시로 해제
      if [[ -n "''${TMUX}" ]]; then
        _IS_TMUX_BACKUP="$TMUX"
        _IS_TMUX_PANE_BACKUP="''${TMUX_PANE:-}"
        unset TMUX TMUX_PANE
      fi

      # inshellisense 초기화
      eval "$(is init zsh)"

      # TMUX 환경변수 복원
      if [[ -n "''${_IS_TMUX_BACKUP}" ]]; then
        export TMUX="$_IS_TMUX_BACKUP"
        [[ -n "''${_IS_TMUX_PANE_BACKUP}" ]] && export TMUX_PANE="$_IS_TMUX_PANE_BACKUP"
        unset _IS_TMUX_BACKUP _IS_TMUX_PANE_BACKUP
      fi
    fi
  '';
}
