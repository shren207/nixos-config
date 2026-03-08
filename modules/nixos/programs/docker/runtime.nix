# modules/nixos/programs/docker/runtime.nix
# Podman 런타임 공통 설정 (서비스 모듈은 homeserver.nix에서 import)
{
  config,
  pkgs,
  lib,
  username,
  constants,
  ...
}:

let
  inherit (constants.paths) dockerData;
in
{
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

  # Critical: OCI 백엔드 반드시 지정!
  virtualisation.oci-containers.backend = "podman";

  # 기존 extraGroups와 머지되도록 mkAfter 사용
  users.users.${username}.extraGroups = lib.mkAfter [ "podman" ];

  # 공통 데이터 디렉토리 (서비스별 디렉토리는 각 모듈에서 정의)
  systemd.tmpfiles.rules = [
    "d ${dockerData} 0755 root root -"
  ];

  # ═══════════════════════════════════════════════════════════════
  # podman auto-update (5분마다 registry 태그 변경 감지 → 컨테이너 재시작)
  # ═══════════════════════════════════════════════════════════════
  systemd.services.podman-auto-update = {
    description = "Podman auto-update containers";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.podman}/bin/podman auto-update";
    };
  };

  systemd.timers.podman-auto-update = {
    description = "Podman auto-update timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5";
      Persistent = true;
    };
  };

  # 시스템 패키지
  environment.systemPackages = with pkgs; [
    podman-compose
    lazydocker
  ];
}
