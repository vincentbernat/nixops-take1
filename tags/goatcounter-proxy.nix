{ pkgs, lib, ... }:
let
  goatcounterIP = "127.0.0.3";
  goatcounterPort = 8087;
  goatcounterCommand = lib.escapeShellArgs [
    (lib.getExe pkgs.luffy.goatcounter)
    "proxy"
    "-site=goatcounter.luffy.cx"
    "-listen=${goatcounterIP}:${toString goatcounterPort}"
    "-ratelimit=10/1"
  ];
in
{
  luffy.containers.goatcounter-proxy = {
    keys."goatcounter-proxy.env" = [
      "${pkgs.runtimeShell}"
      "-c"
      "pass show personal/nixops/secrets | grep '^GOATCOUNTER_API_KEY='"
    ];
    config.systemd.services.goatcounter = {
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
}
