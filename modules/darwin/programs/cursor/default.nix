# Cursor (VS Code fork) 설정
# Homebrew Cask로 앱 설치, Nix로 확장 관리
{ config, pkgs, lib, nixosConfigPath, ... }:

let
  cursorDir = ./files;
  # mkOutOfStoreSymlink용 절대 경로 (양방향 수정 가능)
  cursorFilesPath = "${nixosConfigPath}/modules/darwin/programs/cursor/files";

  # 홈 디렉토리 및 확장 경로
  homeDir = config.home.homeDirectory;
  extensionsPath = "${homeDir}/.cursor/extensions";

  # 확장 목록 정의
  cursorExtensions =
    # open-vsx (오픈소스 마켓플레이스): https://open-vsx.org/
    (with pkgs.open-vsx; [
      # 개발 도구
      dbaeumer.vscode-eslint
      esbenp.prettier-vscode
      usernamehw.errorlens
      streetsidesoftware.code-spell-checker
      aaron-bond.better-comments

      # Git
      eamodio.gitlens
      github.vscode-pull-request-github

      # 언어
      bbenoist.nix

      # 유틸리티
      buenon.scratchpads
      kisstkondoros.vscode-gutter-preview

      # 테마/UI
      k--kato.intellij-idea-keybindings

      # Claude Code
      anthropic.claude-code
    ])

    # vscode-marketplace (open-vsx에 없는 확장): https://marketplace.visualstudio.com/vscode
    ++ (with pkgs.vscode-marketplace; [
      fuzionix.code-case-converter
      wix.vscode-import-cost
      imekachi.webstorm-darcula
      atommaterial.a-file-icon-vscode
    ]);

  # extensions.json 생성 (Cursor GUI가 확장을 인식하도록)
  # Cursor 원본 형식: identifier, version, location, relativeLocation, metadata
  extensionsJson = pkgs.writeTextDir
    "share/vscode/extensions/extensions.json"
    (builtins.toJSON (map (ext: {
      identifier.id = ext.vscodeExtUniqueId;
      version = ext.version;
      location = {
        "$mid" = 1;
        path = "${extensionsPath}/${ext.vscodeExtUniqueId}";
        scheme = "file";
      };
      relativeLocation = ext.vscodeExtUniqueId;
      metadata = {
        installedTimestamp = 0;
        targetPlatform = "undefined";
      };
    }) cursorExtensions));

  # 모든 확장을 하나의 디렉토리로 통합
  combinedExtensions = pkgs.buildEnv {
    name = "cursor-extensions";
    paths = cursorExtensions ++ [ extensionsJson ];
    pathsToLink = [ "/share/vscode/extensions" ];
  };
in
{
  # programs.vscode 비활성화 (pkgs.code-cursor 설치 방지)
  # Homebrew Cask로만 Cursor 앱 설치
  programs.vscode.enable = lib.mkForce false;

  # Cursor 설정 파일 및 확장 관리
  home.file = {
    # 확장 디렉토리 심볼릭 링크 (Nix store에서 관리)
    ".cursor/extensions".source = "${combinedExtensions}/share/vscode/extensions";

    # settings.json - 읽기 전용 (Nix store 심볼릭 링크)
    "Library/Application Support/Cursor/User/settings.json".source =
      "${cursorDir}/settings.json";

    # keybindings.json - 양방향 수정 가능 (nixos-config 직접 참조)
    # Cursor에서 UI로 단축키 변경 시 nixos-config에 바로 반영됨
    "Library/Application Support/Cursor/User/keybindings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${cursorFilesPath}/keybindings.json";

    # Snippets - 읽기 전용 (Nix store 심볼릭 링크)
    "Library/Application Support/Cursor/User/snippets/javascript.json".source =
      "${cursorDir}/snippets/javascript.json";
    "Library/Application Support/Cursor/User/snippets/javascriptreact.json".source =
      "${cursorDir}/snippets/javascriptreact.json";
    "Library/Application Support/Cursor/User/snippets/typescript.json".source =
      "${cursorDir}/snippets/typescript.json";
    "Library/Application Support/Cursor/User/snippets/typescriptreact.json".source =
      "${cursorDir}/snippets/typescriptreact.json";
  };
}
