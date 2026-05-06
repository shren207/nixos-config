# Home Manager 설정 (macOS)
{
  config,
  pkgs,
  lib,
  inputs,
  username,
  nixosConfigPath,
  nixosConfigDefaultPath,
  hostType,
  constants,
  ...
}:

{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  # home-manager backup 정책 (mkOutOfStoreSymlink atomic-rename collision 회피):
  #   - backupCommand가 우선. regular file/symlink 충돌은 unlink, directory 충돌은
  #     timestamped backup으로 보존 (rm -rf 위험 회피).
  #   - backupFileExtension은 셸 스크립트 안에서 timestamp ext로 재사용되며,
  #     backupCommand 롤백 시 기존 backup 동작 fallback 역할도 한다.
  #   - 배경: Claude Code 등 외부 프로세스의 atomic rename(rename(2))으로
  #     mkOutOfStoreSymlink target이 일반 파일/디렉터리로 변해 다음 nrs에서
  #     stale .backup collision으로 막히는 사고를 자가 치유한다.
  home-manager.backupFileExtension = "backup";
  home-manager.backupCommand = pkgs.writeShellScript "hm-cleanup-stale-conflict" ''
    set -e
    # home-manager가 인자 없이 호출하는 probe 경로 대비 — default 빈 문자열로 처리.
    target="''${1:-}"
    [ -n "$target" ] || exit 0
    if [ -d "$target" ] && [ ! -L "$target" ]; then
      mv -- "$target" "$target.''${HOME_MANAGER_BACKUP_EXT:-backup}.$(date +%s)"
      echo "[home-manager] backed up directory conflict: $target" >&2
    else
      echo "[home-manager] cleaning conflict at: $target" >&2
      rm -f -- "$target"
    fi
  '';

  # Home Manager 모듈에 nixosConfigPath, nixosConfigDefaultPath, hostType, constants 전달
  home-manager.extraSpecialArgs = {
    inherit
      inputs
      nixosConfigPath
      nixosConfigDefaultPath
      hostType
      constants
      ;
  };

  home-manager.users.${username} =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      packages = import ../../libraries/packages.nix { inherit pkgs; };
    in
    {
      home.username = username;
      # mkForce: nix-darwin에서 users.users.${name}.home이 null이므로 강제 설정 필요
      home.homeDirectory = lib.mkForce "/Users/${username}";

      # 프로그램별 모듈 임포트
      imports = [
        # Secrets 관리 (agenix)
        inputs.agenix.homeManagerModules.default
        ../shared/programs/secrets

        # 공유 프로그램
        ../shared/programs/broot
        ../shared/programs/claude # shared로 이동됨
        ../shared/programs/codex # Codex CLI 호환 레이어
        ../shared/programs/direnv # 디렉토리별 개발 환경 자동 활성화
        ../shared/programs/git
        ../shared/programs/lazygit
        ../shared/programs/shell # 공통 shell 설정
        ../shared/programs/shell/darwin.nix # macOS 전용 shell 추가
        ../shared/programs/tmux
        ../shared/programs/neovim
        ../shared/programs/cheat # 터미널 cheatsheet 즉시 조회
        ../shared/programs/yazi # TUI 파일 매니저

        # macOS 전용
        ./programs/hammerspoon
        ./programs/vscode
        ./programs/folder-actions
        ./programs/ghostty
        ./programs/cmux
        ./programs/shottr
        ./programs/keybindings
        ./programs/ssh
      ];

      # CLI 도구 패키지 (libraries/packages.nix에서 공통 관리)
      home.packages = packages.shared ++ packages.darwinOnly;

      home.stateVersion = "25.05";
    };
}
