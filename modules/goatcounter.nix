{ config, pkgs, lib, ... }:
let
  cfg = config.luffy.goatcounter;
  databaseDirectory = builtins.dirOf cfg.serve.databaseFile;
  keyCommand = variable: [
    "${pkgs.runtimeShell}"
    "-c"
    "pass show personal/nixops/secrets | grep '^${variable}='"
  ];
in
{
  options.luffy.goatcounter = {
    package = lib.mkPackageOption pkgs [ "luffy" "goatcounter" ] { };
    serve = {
      enable = lib.mkEnableOption "GoatCounter";
      listenAddress = lib.mkOption {
        type = lib.types.str;
        description = "Address to listen on.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        description = "Port to listen on.";
      };
      databaseFile = lib.mkOption {
        type = lib.types.str;
        default = "/var/db/goatcounter/db.sqlite";
        description = "Path to the database.";
      };
    };
    proxy = {
      enable = lib.mkEnableOption "GoatCounter proxy";
      site = lib.mkOption {
        type = lib.types.str;
        example = "goatcounter.example.com";
        description = "GoatCounter site receiving the counts.";
      };
      listenAddress = lib.mkOption {
        type = lib.types.str;
        description = "Address to listen on.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        description = "Port to listen on.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.serve.enable {
      luffy.containers.goatcounter = {
        paths = [ databaseDirectory ];
        keys."goatcounter.env" = keyCommand "GOATCOUNTER_GEODB";
        config.systemd.services.goatcounter = {
          description = "GoatCounter.";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            EnvironmentFile = "/etc/goatcounter.env";
            SupplementaryGroups = [ "keys" ];
            DynamicUser = true;
            Restart = "always";
            StateDirectory = "goatcounter";
            ExecStart = lib.escapeShellArgs [
              (lib.getExe cfg.package)
              "serve"
              "-listen=${cfg.serve.listenAddress}:${toString cfg.serve.port}"
              "-tls=none"
              "-db=sqlite+${cfg.serve.databaseFile}"
              "-automigrate"
            ];
            ExecStartPre = "+${pkgs.coreutils}/bin/chown -R goatcounter:goatcounter ${databaseDirectory}";
            ExecStopPost = "+${pkgs.coreutils}/bin/chown -R nobody:nogroup ${databaseDirectory}";
            ReadWritePaths = databaseDirectory;
          };
        };
      };
    })

    (lib.mkIf cfg.proxy.enable {
      luffy.containers.goatcounter-proxy = {
        keys."goatcounter-proxy.env" = keyCommand "GOATCOUNTER_API_KEY";
        config.systemd.services.goatcounter = {
          description = "Proxy to GoatCounter.";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            EnvironmentFile = "/etc/goatcounter-proxy.env";
            SupplementaryGroups = [ "keys" ];
            DynamicUser = true;
            Restart = "always";
            ExecStart = lib.escapeShellArgs [
              (lib.getExe cfg.package)
              "proxy"
              "-site=${cfg.proxy.site}"
              "-listen=${cfg.proxy.listenAddress}:${toString cfg.proxy.port}"
              "-ratelimit=10/1"
            ];
          };
        };
      };
    })
  ];
}
