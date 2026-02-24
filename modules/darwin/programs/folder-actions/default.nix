# Folder Actions - launchd WatchPaths 기반 폴더 감시
# 감시 폴더: ~/FolderActions/{compress-rar, compress-video, rename-asset, convert-video-to-gif, upload-immich(personal)}/
#
# hostType 분기:
#   upload-immich 스크립트와 launchd agent는 personal 전용 (hostType == "personal").
#   work Mac은 Tailnet에 속하지 않아 Immich 서버(Tailscale IP)에 접근 불가하므로
#   upload-immich.sh 배치와 folder-action-upload-immich agent를 제외한다.
#   shottrDefaultDir(Shottr 저장 경로)는 양쪽 Mac 모두 동일(FolderActions/upload-immich)하게 유지.
#   폴더명이 work에서 의미가 안 맞지만, Shottr 경로 분기는 YAGNI로 판단하여 생략.
{
  config,
  pkgs,
  lib,
  constants,
  hostType,
  ...
}:

let
  scriptsDir = ./files/scripts;
  homeDir = config.home.homeDirectory;
  folderActionsDir = "${homeDir}/FolderActions";
  shottrDefaultDir = "${homeDir}/${constants.macos.paths.shottrDefaultFolderRelative}";
  logsDir = "${homeDir}/Library/Logs/folder-actions";
in
{
  # 스크립트 파일 배치
  home.file = {
    ".local/bin/compress-rar.sh" = {
      source = "${scriptsDir}/compress-rar.sh";
      executable = true;
    };
    ".local/bin/compress-video.sh" = {
      source = "${scriptsDir}/compress-video.sh";
      executable = true;
    };
    ".local/bin/rename-asset.sh" = {
      source = "${scriptsDir}/rename-asset.sh";
      executable = true;
    };
    ".local/bin/convert-video-to-gif.sh" = {
      source = "${scriptsDir}/convert-video-to-gif.sh";
      executable = true;
    };
  }
  // lib.optionalAttrs (hostType == "personal") {
    # Immich CLI 업로드 스크립트 — personal 전용
    # work Mac은 Tailnet 미소속 → Immich 서버 접근 불가 → 스크립트 배치 불필요
    ".local/bin/upload-immich.sh" = {
      source = "${scriptsDir}/upload-immich.sh";
      executable = true;
    };
  };

  # 감시 폴더 생성
  home.activation.createFolderActionsDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${folderActionsDir}/compress-rar"
    mkdir -p "${folderActionsDir}/compress-video"
    mkdir -p "${folderActionsDir}/rename-asset"
    mkdir -p "${folderActionsDir}/convert-video-to-gif"
    mkdir -p "${shottrDefaultDir}"
    mkdir -p "${logsDir}"
  '';

  # launchd 에이전트 설정
  launchd.agents = {
    # RAR 압축 폴더 감시
    folder-action-compress-rar = {
      enable = true;
      config = {
        Label = "com.green.folder-action.compress-rar";
        ProgramArguments = [ "${homeDir}/.local/bin/compress-rar.sh" ];
        WatchPaths = [ "${folderActionsDir}/compress-rar" ];
        StandardOutPath = "${logsDir}/compress-rar.log";
        StandardErrorPath = "${logsDir}/compress-rar.error.log";
        EnvironmentVariables = {
          PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
        };
      };
    };

    # 비디오 압축 폴더 감시
    folder-action-compress-video = {
      enable = true;
      config = {
        Label = "com.green.folder-action.compress-video";
        ProgramArguments = [ "${homeDir}/.local/bin/compress-video.sh" ];
        WatchPaths = [ "${folderActionsDir}/compress-video" ];
        StandardOutPath = "${logsDir}/compress-video.log";
        StandardErrorPath = "${logsDir}/compress-video.error.log";
        EnvironmentVariables = {
          PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
        };
      };
    };

    # 파일 이름 변경 폴더 감시
    folder-action-rename-asset = {
      enable = true;
      config = {
        Label = "com.green.folder-action.rename-asset";
        ProgramArguments = [ "${homeDir}/.local/bin/rename-asset.sh" ];
        WatchPaths = [ "${folderActionsDir}/rename-asset" ];
        StandardOutPath = "${logsDir}/rename-asset.log";
        StandardErrorPath = "${logsDir}/rename-asset.error.log";
      };
    };

    # 비디오 → GIF 변환 폴더 감시
    folder-action-convert-video-to-gif = {
      enable = true;
      config = {
        Label = "com.green.folder-action.convert-video-to-gif";
        ProgramArguments = [ "${homeDir}/.local/bin/convert-video-to-gif.sh" ];
        WatchPaths = [ "${folderActionsDir}/convert-video-to-gif" ];
        StandardOutPath = "${logsDir}/convert-video-to-gif.log";
        StandardErrorPath = "${logsDir}/convert-video-to-gif.error.log";
        EnvironmentVariables = {
          PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
        };
      };
    };
  }
  // lib.optionalAttrs (hostType == "personal") {
    # Immich 자동 업로드 폴더 감시 — personal 전용
    # shottrDefaultDir(~/FolderActions/upload-immich)에 파일이 추가되면
    # upload-immich.sh를 실행하여 Immich 서버(Tailscale IP)로 업로드한다.
    # work Mac은 Tailnet 미소속이므로 이 agent를 등록하지 않는다.
    folder-action-upload-immich = {
      enable = true;
      config = {
        Label = "com.green.folder-action.upload-immich";
        ProgramArguments = [ "${homeDir}/.local/bin/upload-immich.sh" ];
        WatchPaths = [ shottrDefaultDir ];
        StandardOutPath = "${logsDir}/upload-immich.log";
        StandardErrorPath = "${logsDir}/upload-immich.error.log";
        TimeOut = 1800; # 30분 전체 타임아웃 (대용량 업로드 무한 대기 방지)
        EnvironmentVariables = {
          PATH = "${homeDir}/.bun/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
          HOME = homeDir;
          IMMICH_INSTANCE_URL = "https://${constants.domain.subdomains.immich}.${constants.domain.base}";
          WATCH_DIR = shottrDefaultDir;
        };
      };
    };
  };
}
