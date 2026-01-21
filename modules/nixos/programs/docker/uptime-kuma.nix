# modules/nixos/programs/docker/uptime-kuma.nix
# 모니터링 서비스
{ config, pkgs, ... }:

let
  # ⚠️ IP 변경 시 docker/*.nix 모든 파일(default, uptime-kuma, immich, plex) 수정 필요
  tailscaleIP = "100.79.80.95";
  dockerDataPath = "/var/lib/docker-data";
in
{
  # 데이터 디렉토리
  systemd.tmpfiles.rules = [
    "d ${dockerDataPath}/uptime-kuma/data 0755 root root -"
  ];

  # Uptime Kuma 컨테이너 (포트 3002 - 기존 3001 충돌 방지)
  virtualisation.oci-containers.containers.uptime-kuma = {
    image = "louislam/uptime-kuma:1";
    autoStart = true;
    ports = [ "${tailscaleIP}:3002:3001" ];
    volumes = [ "${dockerDataPath}/uptime-kuma/data:/app/data" ];
    environment = {
      TZ = "Asia/Seoul";
    };
    extraOptions = [
      "--memory=512m"
      "--cpus=0.5"
    ];
  };

  # Tailscale IP 바인딩을 위한 서비스 의존성
  systemd.services.podman-uptime-kuma = {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    serviceConfig.ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 60); do ${pkgs.tailscale}/bin/tailscale ip -4 2>/dev/null | grep -q \"^100\\.\" && exit 0; sleep 1; done; echo \"Tailscale IP not ready\" >&2; exit 1'";
  };

  # 방화벽
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 3002 ];
}
