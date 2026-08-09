{ config, pkgs, lib, ... }:
let
  cfg = config.luffy.litestream;
  databaseDirs = lib.unique (map builtins.dirOf (builtins.attrValues cfg.databases));
  databaseMounts = lib.listToAttrs (map
    (dir: lib.nameValuePair dir { hostPath = dir; isReadOnly = false; })
    databaseDirs);
in
{
  options.luffy.litestream = {
    databases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''{ isso = "/var/db/isso/comments.db"; }'';
      description = ''
        SQLite databases to replicate to the backup box. The attribute name is
        the destination directory, below a directory named after the host.
      '';
    };
  };

  config = lib.mkIf (cfg.databases != { }) {
    deployment.keys."litestream.env" = {
      group = "keys";
      permissions = "0640";
      destDir = "/var/keys";
      keyCommand = [
        "${pkgs.runtimeShell}"
        "-c"
        "pass show personal/nixops/secrets | grep '^SQLITE_BACKUP_'"
      ];
    };
    systemd.services."container@litestream" = {
      requires = [ "litestream.env-key.service" ];
      after = [ "litestream.env-key.service" ];
    };

    # Systemd container
    containers.litestream = {
      ephemeral = true;
      autoStart = true;
      extraFlags = [ "--resolv-conf=replace-host" ];
      privateNetwork = false;
      bindMounts = databaseMounts // {
        "/etc/litestream.env" = {
          hostPath = "/var/keys/litestream.env";
          isReadOnly = true;
        };
      };
      config = {
        networking.firewall.enable = false;
        system.stateVersion = config.system.stateVersion;
        systemd.services = {
          console-getty.enable = false;
          systemd-logind.enable = false;
          systemd-oomd.enable = false;
          # The databases belong to dynamically allocated users, whose UID is
          # not known here, so Litestream runs as root.
          litestream.serviceConfig = {
            User = lib.mkForce "root";
            Group = lib.mkForce "root";
          };
        };
        services.litestream = {
          enable = true;
          # Litestream expands $VAR in its configuration file before reading
          # it, so the credentials stay out of the Nix store.
          environmentFile = "/etc/litestream.env";
          settings = {
            sync-interval = "20s";
            auto-recover = true;
            snapshot = {
              interval = "24h";
              retention = "360h";
            };
            levels = [
              { interval = "5m"; }
              { interval = "30m"; }
              { interval = "3h"; }
            ];
            dbs = lib.mapAttrsToList
              (name: path: {
                inherit path;
                replica = {
                  type = "sftp";
                  host = "\${SQLITE_BACKUP_HOST}";
                  user = "\${SQLITE_BACKUP_USER}";
                  password = "\${SQLITE_BACKUP_PASSWORD}";
                  host-key = "\${SQLITE_BACKUP_HOSTKEY}";
                  path = "${config.networking.hostName}/${name}";
                };
              })
              cfg.databases;
          };
        };
      };
    };
  };
}
