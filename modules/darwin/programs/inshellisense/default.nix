# inshellisense 설정 (IDE 스타일 쉘 자동완성)
# https://github.com/microsoft/inshellisense
#
# === Change Intent Record ===
# v1 (legacy, 2026-01-05): nixpkgs rc.21로 도입. tmux 비호환으로 환경별 분기
#     (inshellisense=non-tmux, fzf-tab=tmux) 시도 후 리포 구조 변경 시 미포함.
# v2 (이번 변경): Homebrew tap으로 0.0.1 stable 설치.
#     0.0.1에서 tmux 지원 확인 (Issue #306). 사용자가 tmux 비주력.
#     fzf-tab과 공존 — fzf-tab은 zsh completion widget 대체,
#     inshellisense는 독립 overlay UI로 레이어가 다름.
#     trade-off: 두 자동완성 시스템 병행 관리 비용 발생하나,
#               역할이 다르고 추후 fzf-tab 제거 가능.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # rc.toml 키바인딩 (~/.config/inshellisense/rc.toml)
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

  # Zsh 초기화
  # is init zsh: 내부적으로 createShellConfigs() 호출하여
  # ~/.inshellisense/zsh/init.zsh를 자동 생성한 뒤 source 명령을 stdout에 출력.
  # 별도 HM activation 불필요 (--generate-full-configs 플래그는 0.0.1에 미존재).
  programs.zsh.initContent = lib.mkAfter ''
    if command -v is >/dev/null 2>&1; then
      eval "$(is init zsh)"
    fi
  '';
}
