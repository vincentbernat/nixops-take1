{ config, pkgs, lib, ... }:
let
  cfg = config.luffy.hickory-dns;
  dnssecKeyFile = zone: "hickory-dns.${zone}.pem";
  tsigKeyFile = zone: name: "hickory-dns.${zone}.${name}.tsig";
in
{
  options.luffy.hickory-dns = {
    enable = lib.mkEnableOption "Hickory DNS";
    databaseDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/db/hickory-dns";
      description = "Directory for the SQLite databases.";
    };
    zones = lib.mkOption {
      default = { };
      description = "Zones to serve. They are signed with DNSSEC and accept dynamic updates.";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          zoneFile = lib.mkOption {
            type = lib.types.path;
            description = "Initial content of the zone. Only used when the database does not exist.";
          };
          dnssecKey = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Command running locally and printing the ECDSA P-256 private key.";
          };
          tsigKeys = lib.mkOption {
            type = lib.types.attrsOf (lib.types.listOf lib.types.str);
            default = { };
            description = ''
              TSIG keys allowed to update the zone. The value is a command running
              locally and printing the raw HMAC-SHA256 secret.
            '';
          };
        };
      });
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };

    luffy.containers.hickory-dns = {
      mounts = [ cfg.databaseDirectory ];
      keys = lib.concatMapAttrs
        (zone: zcfg:
          { ${dnssecKeyFile zone} = zcfg.dnssecKey; }
          // lib.mapAttrs' (name: lib.nameValuePair (tsigKeyFile zone name)) zcfg.tsigKeys)
        cfg.zones;
      config = {
        services.hickory-dns = {
          enable = true;
          settings = {
            listen_addrs_ipv4 = [ config.luffy.host.ipv4Address ];
            listen_addrs_ipv6 = [ config.luffy.host.ipv6Address ];
            directory = cfg.databaseDirectory;
            zones = lib.mapAttrsToList
              (zone: zcfg: {
                inherit zone;
                file = null;
                stores = {
                  type = "sqlite";
                  zone_path = "${zcfg.zoneFile}";
                  journal_path = "${zone}.sqlite";
                  allow_update = true;
                  tsig_keys = lib.mapAttrsToList
                    (name: _: {
                      name = "${name}.";
                      key_file = "/etc/${tsigKeyFile zone name}";
                      algorithm = "hmac-sha256";
                    })
                    zcfg.tsigKeys;
                };
                keys = [{
                  key_path = "/etc/${dnssecKeyFile zone}";
                  algorithm = "ECDSAP256SHA256";
                }];
                nx_proof_kind.nsec3.iterations = 0;
              })
              cfg.zones;
          };
        };
        systemd.services.hickory-dns.serviceConfig = {
          SupplementaryGroups = [ "keys" ];
          ExecStartPre = "+${pkgs.coreutils}/bin/chown -R hickory-dns:hickory-dns ${cfg.databaseDirectory}";
          ExecStopPost = "+${pkgs.coreutils}/bin/chown -R nobody:nogroup ${cfg.databaseDirectory}";
        };
      };
    };
  };
}
