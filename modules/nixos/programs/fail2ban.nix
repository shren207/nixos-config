# fail2ban 설정
{ config, ... }:

{
  services.fail2ban = {
    enable = true;

    jails = {
      sshd = {
        settings = {
          enabled = true;
          port = "ssh";
          filter = "sshd";
          maxretry = 3;
          findtime = "10m";
          bantime = "24h";
        };
      };
    };
  };
}
