# agenix secrets 설정
# 주의: agenix 모듈은 상위(darwin/home.nix, nixos/home.nix)에서 import해야 함
{
  config,
  pkgs,
  lib,
  ...
}:

{
  age = {
    # SSH 키로 복호화
    identityPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];

    # Pushover API credentials
    # 사용처: atuin-watchdog.sh, fail2ban.nix, stop-notification.sh
    secrets.pushover-credentials = {
      file = ../../../../secrets/pushover-credentials.age;
      path = "${config.xdg.configHome}/pushover/credentials";
      mode = "0400";
    };
  };
}
