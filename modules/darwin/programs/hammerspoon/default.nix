# Hammerspoon 설정 (macOS 키보드/자동화)
{
  config,
  lib,
  ...
}:

let
  hammerspoonDir = ./files;
  homeDir = config.home.homeDirectory;
in
{
  # ~/.hammerspoon/ 디렉토리 관리
  home.file = {
    ".hammerspoon/init.lua".source = "${hammerspoonDir}/init.lua";
    ".hammerspoon/foundation_remapping.lua".source = "${hammerspoonDir}/foundation_remapping.lua";
    ".hammerspoon/atuin_menubar.lua".source = "${hammerspoonDir}/atuin_menubar.lua";
    ".local/bin/ensure-chrome-debug-port.sh" = {
      source = "${hammerspoonDir}/ensure-chrome-debug-port.sh";
      executable = true;
    };
  };

  home.activation.createHammerspoonLogsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${homeDir}/Library/Logs/hammerspoon"
  '';

  # Hammerspoon이 죽어도 로그인 시 Chrome 디버깅 포트 9222를 보장하는 fallback
  launchd.agents.ensure-chrome-debug-port = {
    enable = true;
    config = {
      Label = "com.green.ensure-chrome-debug-port";
      ProgramArguments = [ "${homeDir}/.local/bin/ensure-chrome-debug-port.sh" ];
      RunAtLoad = true;
      EnvironmentVariables = {
        HOME = homeDir;
        PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StandardOutPath = "${homeDir}/Library/Logs/hammerspoon/ensure-chrome-debug-port.log";
      StandardErrorPath = "${homeDir}/Library/Logs/hammerspoon/ensure-chrome-debug-port.error.log";
    };
  };
}
