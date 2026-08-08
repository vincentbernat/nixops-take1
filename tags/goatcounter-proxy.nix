{ config, pkgs, lib, ... }:
let
  goatcounterIP = "127.0.0.3";
  goatcounterPort = 8087;
  goatcounterCommand = lib.escapeShellArgs [
    (lib.getExe pkgs.luffy.goatcounter)
    "proxy"
    "-site=vincentbernat.goatcounter.com"
    "-listen=${goatcounterIP}:${toString goatcounterPort}"
    "-ratelimit=10/1"
  ];
in
{
  deployment.keys."goatcounter-proxy.env" = {
    group = "keys";
    permissions = "0640";
    destDir = "/var/keys";
    keyCommand = [
      "${pkgs.runtimeShell}"
      "-c"
      "pass show personal/nixops/secrets | grep '^GOATCOUNTER_API_KEY='"
    ];
  };
  systemd.services."container@goatcounter-proxy" = {
    requires = [ "goatcounter-proxy.env-key.service" ];
    after = [ "goatcounter-proxy.env-key.service" ];
  };
  containers.goatcounter-proxy = {
    ephemeral = true;
    autoStart = true;
    extraFlags = [ "--resolv-conf=replace-host" ];
    privateNetwork = false;
    bindMounts."/etc/goatcounter-proxy.env" = {
      hostPath = "/var/keys/goatcounter-proxy.env";
      isReadOnly = true;
    };
    config = {
      networking.firewall.enable = false;
      system.stateVersion = config.system.stateVersion;
      systemd.services.console-getty.enable = false;
      systemd.services.goatcounter = {
        description = "Proxy to GoatCounter.";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          EnvironmentFile = "/etc/goatcounter-proxy.env";
          SupplementaryGroups = [ "keys" ];
          DynamicUser = true;
          Restart = "always";
          ExecStart = goatcounterCommand;
        };
      };
    };
  };
}
