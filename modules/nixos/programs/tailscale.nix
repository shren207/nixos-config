# Tailscale VPN
{ config, pkgs, ... }:

{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both"; # Funnel/Serve 지원
  };

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];

    # 개발 서버 포트 (Tailscale 네트워크 내에서만)
    interfaces."tailscale0".allowedTCPPorts = [
      3000
      3001
      5173
      8080
    ];
  };

  environment.systemPackages = [ pkgs.tailscale ];
}
