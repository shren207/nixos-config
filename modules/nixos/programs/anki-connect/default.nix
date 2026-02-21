# modules/nixos/programs/anki-connect/default.nix
# Headless Anki + AnkiConnect API 서버
# QT_QPA_PLATFORM=offscreen으로 GUI 없이 실행
{
  config,
  pkgs,
  lib,
  constants,
  ...
}:

let
  cfg = config.homeserver.ankiConnect;
  inherit (constants.network) minipcTailscaleIP;

  ankiWithConnect = pkgs.anki.withAddons [
    (pkgs.ankiAddons.anki-connect.withConfig {
      config = {
        apiKey = null; # 런타임에 configScript로 주입
        webBindAddress = minipcTailscaleIP;
        webBindPort = cfg.port;
        webCorsOriginList = [
          "http://localhost"
          "http://localhost:3000"
          "http://localhost:5173"
          "http://${minipcTailscaleIP}"
        ];
      };
    })
  ];

  # AnkiConnect config.json을 agenix 시크릿으로 동적 생성
  configScript = pkgs.writeShellScript "anki-connect-config" ''
    CONFIG_DIR="/var/lib/anki/.local/share/Anki2/addons21/2055492159"
    mkdir -p "$CONFIG_DIR"

    API_KEY=$(cat ${config.age.secrets.anki-connect-api-key.path})

    cat > "$CONFIG_DIR/config.json" <<CONF
    {
      "apiKey": "$API_KEY",
      "webBindAddress": "${minipcTailscaleIP}",
      "webBindPort": ${toString cfg.port},
      "webCorsOriginList": [
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:5173",
        "http://${minipcTailscaleIP}"
      ]
    }
    CONF
    chown -R anki:anki "$CONFIG_DIR"
  '';
in
{
  config = lib.mkIf cfg.enable {
    # 시스템 사용자
    users.users.anki = {
      isSystemUser = true;
      group = "anki";
      home = "/var/lib/anki";
      createHome = true;
    };
    users.groups.anki = { };

    # agenix 시크릿
    age.secrets.anki-connect-api-key = {
      file = ../../../../secrets/anki-connect-api-key.age;
      mode = "0400";
      owner = "anki";
    };

    # systemd 서비스
    systemd.services.anki-connect = {
      description = "Headless Anki with AnkiConnect API";
      after = [
        "tailscaled.service"
        "network.target"
      ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        QT_QPA_PLATFORM = "offscreen";
        HOME = "/var/lib/anki";
        XDG_DATA_HOME = "/var/lib/anki/.local/share";
        XDG_CONFIG_HOME = "/var/lib/anki/.config";
      };

      serviceConfig = {
        Type = "simple";
        User = "anki";
        Group = "anki";
        StateDirectory = "anki";

        # Tailscale 대기 → config.json 생성 → Anki 실행
        ExecStartPre = [
          ("+" + (import ../../lib/tailscale-wait.nix { inherit pkgs; }))
          ("+" + configScript)
        ];
        ExecStart = "${ankiWithConnect}/bin/anki -p ${cfg.profile}";

        Restart = "on-failure";
        RestartSec = 10;
        MemoryMax = "512M";

        # 보안 강화
        NoNewPrivileges = true;
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
  };
}
