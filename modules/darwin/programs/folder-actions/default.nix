# Folder Actions - launchd WatchPaths 기반 폴더 감시
# 감시 폴더: ~/FolderActions/{compress-rar, compress-video, rename-asset, convert-video-to-gif}/
{ config, pkgs, lib, ... }:

let
  scriptsDir = ./files/scripts;
  homeDir = config.home.homeDirectory;
  folderActionsDir = "${homeDir}/FolderActions";
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
  };

  # 감시 폴더 생성
  home.activation.createFolderActionsDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${folderActionsDir}/compress-rar"
    mkdir -p "${folderActionsDir}/compress-video"
    mkdir -p "${folderActionsDir}/rename-asset"
    mkdir -p "${folderActionsDir}/convert-video-to-gif"
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
  };
}
