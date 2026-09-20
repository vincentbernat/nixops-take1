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
      (name: container: {
        ephemeral = true;
        autoStart = true;
        privateNetwork = false;
        extraFlags = [ "--resolv-conf=replace-host" ];
        bindMounts =
          lib.genAttrs container.paths (path: { hostPath = path; isReadOnly = false; })
          // lib.mapAttrs'
            (key: _: lib.nameValuePair "/etc/${key}" {
              hostPath = "/var/keys/${key}";
              isReadOnly = true;
            })
            container.keys;
        config = {
          imports = [ container.config ];
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
      (_: container: lib.mapAttrs
        (_: keyCommand: {
          inherit keyCommand;
          group = "keys";
          permissions = "0640";
          destDir = "/var/keys";
        })
        container.keys)
      cfg;

    systemd.services = lib.mapAttrs'
      (name: container:
        let
          units = map (key: "${key}-key.service") (lib.attrNames container.keys);
        in
        lib.nameValuePair "container@${name}" {
          requires = units;
          after = units;
        })
      cfg;
  };
}
