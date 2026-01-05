# tmux 설정
{ config, pkgs, lib, ... }:

let
  tmuxDir = ./files;
in
{
  programs.tmux = {
    enable = true;
    mouse = true;
    terminal = "tmux-256color";
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

    # ~/.tmux.conf에서 ~/.tmux/tmux.conf를 source
    ".tmux.conf".text = ''
      # Managed by Home Manager
      source-file ~/.tmux/tmux.conf
    '';
  };

  # pane-notes 디렉토리 생성 (동적 생성용)
  home.activation.createTmuxPaneNotes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p $HOME/.tmux/pane-notes
  '';
}
