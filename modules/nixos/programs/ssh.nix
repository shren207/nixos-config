# SSH 서버 설정
{ config, ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
      X11Forwarding = false;
      AllowTcpForwarding = true; # 개발 서버 터널링용
      ClientAliveInterval = 60;
      ClientAliveCountMax = 3;
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];
}
