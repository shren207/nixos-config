# Shottr 설정 (macOS)
{
  config,
  lib,
  constants,
  nixosConfigPath,
  ...
}:

let
  shottrDir = ./files;
  homeDir = config.home.homeDirectory;
  shottrDomain = "cc.ffitch.shottr";
  shottrDefaultFolder = "${homeDir}/${constants.macos.paths.shottrDefaultFolderRelative}";
  shottrTokenPath = "${config.xdg.configHome}/shottr/upload-token";
in
{
  # Vaultwarden -> agenix 반자동 동기화 스크립트
  home.file.".local/bin/shottr-token-sync" = {
    source = "${shottrDir}/shottr-token-sync.sh";
    executable = true;
  };

  # 경로 가드: 폴더/북마크 이슈를 조기에 알림
  home.activation.checkShottrFolderAndWarn = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "${shottrDefaultFolder}" ]; then
      echo "Warning: Shottr default folder not found: ${shottrDefaultFolder}"
      echo "FolderActions activation should create this path."
    fi

    current_folder="$(defaults read "${shottrDomain}" defaultFolder 2>/dev/null || true)"
    if [ -n "$current_folder" ] && [ "$current_folder" != "${shottrDefaultFolder}" ]; then
      echo "Warning: Shottr current folder differs from declared folder."
      echo "  current: $current_folder"
      echo "  target : ${shottrDefaultFolder}"
      echo "If save fails after switch, re-select the folder once in Shottr UI."
      echo "Note: defaultFolderBookmark(data) is intentionally not managed by Nix."
    fi
  '';

  # 핵심 설정 선언 적용
  home.activation.applyShottrCoreSettings = lib.hm.dag.entryAfter [ "checkShottrFolderAndWarn" ] ''
    defaults write "${shottrDomain}" defaultFolder "${shottrDefaultFolder}"
    defaults write "${shottrDomain}" saveFormat "Auto"
    defaults write "${shottrDomain}" KeyboardShortcuts_fullscreen '{"carbonModifiers":768,"carbonKeyCode":18}'
    defaults write "${shottrDomain}" KeyboardShortcuts_area '{"carbonKeyCode":20,"carbonModifiers":768}'
    defaults write "${shottrDomain}" KeyboardShortcuts_scrolling '{"carbonModifiers":768,"carbonKeyCode":19}'
    defaults write "${shottrDomain}" KeyboardShortcuts_ocr '{"carbonModifiers":6400,"carbonKeyCode":31}'

    killall cfprefsd 2>/dev/null || true
  '';

  # token은 Nix store에 두지 않고 런타임에서 secret 파일로 주입
  home.activation.applyShottrTokenFromSecret = lib.hm.dag.entryAfter [ "applyShottrCoreSettings" ] ''
    if [ ! -f "${shottrTokenPath}" ]; then
      echo "Warning: Shottr token secret not found: ${shottrTokenPath}"
      echo "Run 'stsync && nrs' after adding token in Vaultwarden."
    else
      token_value="$(sed -n 's/^TOKEN=//p' "${shottrTokenPath}" | tail -n 1 | tr -d '\r')"
      token_value="''${token_value%\"}"
      token_value="''${token_value#\"}"

      if [ -z "$token_value" ]; then
        echo "Warning: Shottr token secret is empty. Skipping token apply."
      else
        defaults write "${shottrDomain}" token "$token_value"
      fi
    fi
  '';

  # nixosConfigPath를 주입해 어느 디렉토리에서 실행해도 동일 동작 보장
  home.shellAliases = {
    stsync = "SHOTTR_CONFIG_REPO='${nixosConfigPath}' ~/.local/bin/shottr-token-sync";
  };
}
