{ config, lib, ... }:
let
  cfg = config.luffy.containers;
in
{
  options.luffy.containers = lib.mkOption {
    default = { };
    description = "Ephemeral containers sharing the host network.";
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        keys = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.str);
          default = { };
          description = "Secrets, as a command to run locally. They are mounted in /etc.";
        };
        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Host directories mounted read-write at the same place.";
        };
        config = lib.mkOption {
          type = lib.types.deferredModule;
          default = { };
          description = "NixOS configuration of the container.";
        };
      };
    });
  };

  config = {
    containers = lib.mapAttrs
      (name: c: {
        ephemeral = true;
        autoStart = true;
        privateNetwork = false;
        extraFlags = [ "--resolv-conf=replace-host" ];
        bindMounts =
          lib.genAttrs c.paths (path: { hostPath = path; isReadOnly = false; })
          // lib.mapAttrs'
            (key: _: lib.nameValuePair "/etc/${key}" {
              hostPath = "/var/keys/${key}";
              isReadOnly = true;
            })
            c.keys;
        config = {
          imports = [ c.config ];
          networking.firewall.enable = false;
          system.stateVersion = config.system.stateVersion;
          systemd.services = {
            console-getty.enable = false;
            systemd-logind.enable = false;
            systemd-oomd.enable = false;
          };
        };
      })
      cfg;

    deployment.keys = lib.concatMapAttrs
      (_: c: lib.mapAttrs
        (_: keyCommand: {
          inherit keyCommand;
          group = "keys";
          permissions = "0640";
          destDir = "/var/keys";
        })
        c.keys)
      cfg;

    systemd.services = lib.mapAttrs'
      (name: c:
        let
          units = map (key: "${key}-key.service") (lib.attrNames c.keys);
        in
        lib.nameValuePair "container@${name}" {
          requires = units;
          after = units;
        })
      cfg;
  };
}
