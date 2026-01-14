{ config, lib, pkgs, ... }:

let
  homeDir = config.home.homeDirectory;
  atuinFilesPath = "${toString ./.}/files";

  # 모니터링 설정 (Single Source of Truth)
  syncCheckInterval = 600;        # 10분 (초) - 상태 체크 주기
  syncThresholdMinutes = 5;       # 5분 이상 동기화 안 되면 경고

  # 복구 설정
  maxRetryCount = 3;              # 최대 재시도 횟수
  initialBackoffSeconds = 5;      # 초기 백오프 (초)
  daemonStartupWait = 5;          # daemon 시작 대기 (초)
  networkCheckTimeout = 5;        # 네트워크 체크 타임아웃 (초)
  atuinSyncServer = "api.atuin.sh";  # sync 서버

  # Hammerspoon용 JSON 설정 파일
  monitorConfigJson = builtins.toJSON {
    inherit syncCheckInterval syncThresholdMinutes;
  };
in
{
  # JSON 설정 파일 (Hammerspoon에서 읽기)
  home.file.".config/atuin-monitor/config.json".text = monitorConfigJson;

  # Watchdog 스크립트 배포
  home.file.".local/bin/atuin-watchdog.sh" = {
    source = "${atuinFilesPath}/atuin-watchdog.sh";
    executable = true;
  };

  # launchd 에이전트: 주기적 sync (daemon 대체)
  # daemon은 아직 experimental이므로 launchd로 주기적 sync 실행
  # 참고: atuin CLI sync (v2)가 last_sync_time을 업데이트하지 않는 버그가 있어서
  # bash -c로 sync 후 파일을 직접 업데이트
  launchd.agents.atuin-sync = {
    enable = true;
    config = {
      Label = "com.green.atuin-sync";
      ProgramArguments = [
        "/bin/bash" "-c"
        "atuin sync && printf '%s' \"$(date -u +'%Y-%m-%dT%H:%M:%S.000000Z')\" > ~/.local/share/atuin/last_sync_time"
      ];
      RunAtLoad = true;     # 로드 시 바로 첫 실행
      StartInterval = 120;  # 이후 2분마다 sync
      EnvironmentVariables = {
        PATH = "/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:${homeDir}/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
        HOME = homeDir;
      };
    };
  };

  # launchd 에이전트: Watchdog (동기화 상태 감시 + 알림)
  launchd.agents.atuin-watchdog = {
    enable = true;
    config = {
      Label = "com.green.atuin-watchdog";
      ProgramArguments = [ "${homeDir}/.local/bin/atuin-watchdog.sh" ];
      StartInterval = syncCheckInterval;
      EnvironmentVariables = {
        PATH = "/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:${homeDir}/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
        HOME = homeDir;
        ATUIN_SYNC_THRESHOLD_MINUTES = toString syncThresholdMinutes;
        # 복구 설정
        ATUIN_MAX_RETRY_COUNT = toString maxRetryCount;
        ATUIN_INITIAL_BACKOFF = toString initialBackoffSeconds;
        ATUIN_DAEMON_STARTUP_WAIT = toString daemonStartupWait;
        ATUIN_NETWORK_CHECK_TIMEOUT = toString networkCheckTimeout;
        ATUIN_SYNC_SERVER = atuinSyncServer;
      };
    };
  };

  # Atuin watchdog alias (macOS 전용)
  home.shellAliases = {
    awd = "~/.local/bin/atuin-watchdog.sh";
  };
}
