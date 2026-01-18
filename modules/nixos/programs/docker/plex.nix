# modules/nixos/programs/docker/plex.nix
# 미디어 스트리밍
{
  config,
  pkgs,
  username,
  ...
}:

let
  # ⚠️ IP 변경 시 docker/*.nix 모든 파일 수정 필요
  tailscaleIP = "100.79.80.95";
  dockerDataPath = "/var/lib/docker-data";
  mediaDataPath = "/mnt/data";
in
{
  # 데이터 디렉토리
  systemd.tmpfiles.rules = [
    "d ${dockerDataPath}/plex/config 0755 ${username} users -"
    "d ${mediaDataPath}/plex/media/movies 0755 ${username} users -"
    "d ${mediaDataPath}/plex/media/tv 0755 ${username} users -"
  ];

  # Plex 컨테이너
  virtualisation.oci-containers.containers.plex = {
    image = "plexinc/pms-docker:latest";
    autoStart = true;
    ports = [ "${tailscaleIP}:32400:32400/tcp" ];
    volumes = [
      "${dockerDataPath}/plex/config:/config"
      "${mediaDataPath}/plex/media:/data"
      "${mediaDataPath}/homeserver-data/media:/legacy-media:ro"
      "/tmp/plex-transcode:/transcode"
    ];
    environment = {
      TZ = "Asia/Seoul";
      PLEX_UID = "1000";
      PLEX_GID = "100";
    };
    extraOptions = [
      "--memory=4g"
      "--cpus=2"
    ];
  };

  # 방화벽
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 32400 ];
}
