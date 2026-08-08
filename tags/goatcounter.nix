{ config, pkgs, lib, ... }:
let
  goatcounterIP = "127.0.0.4";
  goatcounterPort = 8088;
  goatcounterCommand = lib.escapeShellArgs [
    (lib.getExe pkgs.luffy.goatcounter)
    "serve"
    "-listen=${goatcounterIP}:${toString goatcounterPort}"
    "-tls=none"
    "-db=sqlite+/var/db/goatcounter/db.sqlite"
    "-automigrate"
  ];
in
{
  deployment.keys."goatcounter.env" = {
    group = "keys";
    permissions = "0640";
    destDir = "/var/keys";
    keyCommand = [
      "${pkgs.runtimeShell}"
      "-c"
      "pass show personal/nixops/secrets | grep '^GOATCOUNTER_GEODB='"
    ];
  };
  systemd.services."container@goatcounter" = { };
  containers.goatcounter = {
    ephemeral = true;
    autoStart = true;
    extraFlags = [ "--resolv-conf=replace-host" ];
    privateNetwork = false;
    bindMounts."/var/db/goatcounter" = {
      hostPath = "/var/db/goatcounter";
      isReadOnly = false;
    };
    bindMounts."/etc/goatcounter.env" = {
      hostPath = "/var/keys/goatcounter.env";
      isReadOnly = true;
    };
    config = {
      networking.firewall.enable = false;
      system.stateVersion = config.system.stateVersion;
      systemd.services = {
        console-getty.enable = false;
        systemd-logind.enable = false;
        systemd-oomd.enable = false;
        goatcounter = {
          description = "GoatCounter.";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            EnvironmentFile = "/etc/goatcounter.env";
            SupplementaryGroups = [ "keys" ];
            DynamicUser = true;
            Restart = "always";
            StateDirectory = "goatcounter";
            ExecStart = goatcounterCommand;
            ExecStartPre = "+${pkgs.coreutils}/bin/chown -R goatcounter:goatcounter /var/db/goatcounter";
            ExecStopPost = "+${pkgs.coreutils}/bin/chown -R nobody:nogroup /var/db/goatcounter";
            ReadWritePaths = "/var/db/goatcounter";
          };
        };
      };
    };
  };

  # Nginx vhost
  services.nginx.virtualHosts."goatcounter.luffy.cx" = {
    root = "/data/webserver/goatcounter.luffy.cx";
    enableACME = true;
    forceSSL = true;
    extraConfig = ''
      access_log /var/log/nginx/goatcounter.luffy.cx.log anonymous;
    '';
    locations."/" = {
      proxyPass = "http://${goatcounterIP}:${toString goatcounterPort}";
      extraConfig = ''
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
    };
  };
  security.acme.certs."goatcounter.luffy.cx" = { };
}
