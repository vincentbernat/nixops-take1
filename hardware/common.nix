{ config, lib, ... }:
{
  fileSystems."/data" = lib.mkIf (config.luffy.host.storage != null) {
    device = config.luffy.host.storage.device;
    fsType = "ext4";
    autoFormat = true;
    options = [ "nofail" ];
  };
}
