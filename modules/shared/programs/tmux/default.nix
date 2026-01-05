# tmux 설정
{ config, pkgs, lib, ... }:

let
  tmuxDir = ./files;
in
{
  programs.tmux = {
    enable = true;
    # Home Manager가 생성하는 ~/.config/tmux/tmux.conf가 먼저 로드되므로,
    # 사용자 설정을 여기서 source해야 함
    extraConfig = ''
      source-file ~/.tmux/tmux.conf
    '';
  };

  # ~/.tmux/ 디렉토리 전체를 심볼릭 링크로 관리
  home.file = {
    ".tmux/tmux.conf".source = "${tmuxDir}/tmux.conf";
    ".tmux/scripts/pane-note.sh" = {
      source = "${tmuxDir}/scripts/pane-note.sh";
      executable = true;
    };
    ".tmux/scripts/pane-link.sh" = {
      source = "${tmuxDir}/scripts/pane-link.sh";
      executable = true;
    };
    ".tmux/scripts/pane-peek.sh" = {
      source = "${tmuxDir}/scripts/pane-peek.sh";
      executable = true;
    };
    ".tmux/scripts/prefix-help.sh" = {
      source = "${tmuxDir}/scripts/prefix-help.sh";
      executable = true;
    };
    ".tmux/scripts/find-unused-prefixes.sh" = {
      source = "${tmuxDir}/scripts/find-unused-prefixes.sh";
      executable = true;
    };
    # NOTE: ~/.tmux.conf는 더 이상 필요없음
    # programs.tmux.extraConfig에서 ~/.tmux/tmux.conf를 source하므로
    # XDG 경로(~/.config/tmux/tmux.conf)가 우선 로드됨
  };

  # pane-notes 디렉토리 생성 (동적 생성용)
  home.activation.createTmuxPaneNotes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p $HOME/.tmux/pane-notes
  '';
}
