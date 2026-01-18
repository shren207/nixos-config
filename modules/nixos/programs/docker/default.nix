# modules/nixos/programs/docker/default.nix
# Podman 런타임 + 공통 설정
{
  config,
  pkgs,
  lib,
  username,
  ...
}:

let
  dockerDataPath = "/var/lib/docker-data";
  mediaDataPath = "/mnt/data";
in
{
  imports = [
    ./uptime-kuma.nix
    # ./immich.nix    # Phase 2에서 활성화
    # ./plex.nix      # Phase 3에서 활성화
  ];

  # ═══════════════════════════════════════════════════════════════
  # Podman 런타임 (Critical: backend 명시 필수!)
  # ═══════════════════════════════════════════════════════════════

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # ⚠️ Critical: OCI 백엔드 반드시 지정!
  virtualisation.oci-containers.backend = "podman";

  # ⚠️ 기존 extraGroups와 머지되도록 mkAfter 사용
  users.users.${username}.extraGroups = lib.mkAfter [ "podman" ];

  # 공통 데이터 디렉토리 (서비스별 디렉토리는 각 모듈에서 정의)
  systemd.tmpfiles.rules = [
    "d ${dockerDataPath} 0755 root root -"
    "d ${mediaDataPath}/plex/media 0755 ${username} users -"
  ];

  # 시스템 패키지
  environment.systemPackages = with pkgs; [
    podman-compose
    lazydocker
  ];
}
