{ lib, ... }:
{
  options.luffy.host = {
    ipv4Address = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "IPv4 address of the host, from cdktf.json.";
    };
    ipv6Address = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "IPv6 address of the host, from cdktf.json.";
    };
    gateway4 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      description = "IPv4 gateway of the host, from the gateway4 tag in cdktf.json.";
    };
    gateway6 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      description = "IPv6 gateway of the host, from the gateway6 tag in cdktf.json.";
    };
    storage = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          device = lib.mkOption {
            type = lib.types.str;
            description = "Block device of the additional storage.";
          };
          size = lib.mkOption {
            type = lib.types.number;
            description = "Size of the additional storage in GB.";
          };
        };
      });
      readOnly = true;
      description = "Additional storage of the host, from cdktf.json.";
    };
    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Tags of the host, from cdktf.json.";
    };
  };
}
