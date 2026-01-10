# Ghostty 터미널 설정
{ config, pkgs, lib, ... }:

{
  xdg.configFile."ghostty/config".text = ''
    # macOS Option 키를 Alt로 사용 (왼쪽만)
    macos-option-as-alt = left

    # Ctrl+C를 legacy 시퀀스로 강제 (CSI u 모드 문제 해결)
    # Claude Code 등이 CSI u 모드를 활성화한 후 비활성화하지 않는 버그 우회
    keybind = ctrl+c=text:\x03
  '';
}
