{ config, pkgs, lib, ... }:
let
  cfg = config.luffy.isso;
  databaseDirectory = builtins.dirOf cfg.databaseFile;
  issoEnv = pkgs.python3.buildEnv.override {
    extraLibs = [
      cfg.package
      pkgs.python3Packages.gunicorn
      pkgs.python3Packages.gevent
    ];
  };
in
{
  options.luffy.isso = {
    enable = lib.mkEnableOption "Isso";
    package = lib.mkPackageOption pkgs [ "luffy" "isso" ] { };
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
      default = "/var/db/isso/comments.db";
      description = "Path to the database.";
    };
    configScript = lib.mkOption {
      type = lib.types.path;
      description = "Script running locally and printing the configuration file.";
    };
  };

  config = lib.mkIf cfg.enable {
    luffy.containers.isso = {
      paths = [ databaseDirectory ];
      keys."isso.cfg" = [ "${pkgs.runtimeShell}" "${cfg.configScript}" ];
      config.systemd.services.isso = {
        description = "Isso Comment Server";
        wantedBy = [ "multi-user.target" ];
        script = ''
          ${issoEnv}/bin/gunicorn \
            --name isso \
            --bind ${cfg.listenAddress}:${toString cfg.port} \
            --worker-class gevent --workers 2 --worker-tmp-dir /dev/shm \
            --preload isso.run
        '';
        environment = {
          ISSO_SETTINGS = "/etc/isso.cfg";
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        };
        serviceConfig = {
          SupplementaryGroups = [ "keys" ];
          DynamicUser = true;
          StateDirectory = "isso";
          Restart = "always";
          ExecStartPre = "+${pkgs.coreutils}/bin/chown -R isso:isso ${databaseDirectory}";
          ExecStopPost = "+${pkgs.coreutils}/bin/chown -R nobody:nogroup ${databaseDirectory}";
          ReadWritePaths = databaseDirectory;
        };
      };
    };
    systemd.services."container@isso".restartTriggers = [ cfg.configScript ];
  };
}
