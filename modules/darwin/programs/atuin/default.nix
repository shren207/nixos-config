{ config, lib, pkgs, ... }:

let
  homeDir = config.home.homeDirectory;
  atuinFilesPath = "${toString ./.}/files";

  # 모니터링 설정 (중앙 관리)
  syncCheckInterval = 3600;      # 1시간 (초)
  syncThresholdHours = 24;       # 24시간 이상 동기화 안 되면 알림
  logRetentionDays = 30;         # 로그 보관 기간
in
{
  # 로그 디렉토리 생성
  home.activation.createAtuinLogDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${homeDir}/Library/Logs/atuin"
  '';

  # 모니터링 스크립트 배포
  home.file.".local/bin/atuin-sync-monitor.sh" = {
    source = "${atuinFilesPath}/atuin-sync-monitor.sh";
    executable = true;
  };

  # launchd 에이전트
  launchd.agents.atuin-sync-monitor = {
    enable = true;
    config = {
      Label = "com.green.atuin-sync-monitor";
      ProgramArguments = [ "${homeDir}/.local/bin/atuin-sync-monitor.sh" ];
      StartInterval = syncCheckInterval;
      StandardOutPath = "${homeDir}/Library/Logs/atuin/sync-monitor.log";
      StandardErrorPath = "${homeDir}/Library/Logs/atuin/sync-monitor.error.log";
      EnvironmentVariables = {
        PATH = "/run/current-system/sw/bin:${homeDir}/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
        HOME = homeDir;
        ATUIN_SYNC_THRESHOLD_HOURS = toString syncThresholdHours;
        ATUIN_LOG_RETENTION_DAYS = toString logRetentionDays;
      };
    };
  };

  # Atuin 모니터링 alias (macOS 전용)
  home.shellAliases = {
    asm = "~/.local/bin/atuin-sync-monitor.sh";              # 수동 실행
    asm-test = "~/.local/bin/atuin-sync-monitor.sh --test";  # 테스트 (알림 없으면 hs/pushover 확인)
    asm-log = "tail -f ~/Library/Logs/atuin/sync-monitor.log";  # 로그 확인
  };
}
